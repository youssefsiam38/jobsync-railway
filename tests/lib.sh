#!/usr/bin/env bash
# shellcheck disable=SC2015
# Shared helpers for jobsync-railway tests. Source this file; do not execute it.
#
# Everything but /healthz sits behind the Caddy basic-auth front door (user/password below), so every
# app request carries it. Inside, JobSync uses next-auth: an account is created via its signup server
# action (id auto-discovered from the page bundle) and sign-in via next-auth's REST endpoints.
# Secrets are never echoed.

: "${APP_URL:=http://127.0.0.1:${JOBSYNC_TEST_PORT:-13737}}"
: "${TEST_TIMEOUT:=300}"
: "${FRONT_USERNAME:=${JOBSYNC_TEST_OWNER_USERNAME:-owner}}"
: "${FRONT_PASSWORD:=${JOBSYNC_TEST_OWNER_PASSWORD:-local-test-only-front-door-pw}}"
: "${APP_EMAIL:=owner@example.com}"
: "${APP_PASSWORD:=OwnerPass123!}"
: "${APP_NAME:=Owner}"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
export TEST_TMP
_PASS=0; _FAIL=0

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -q -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }

# Front-door basic auth is applied to every request except where noted.
FAUTH=(-u "$FRONT_USERNAME:$FRONT_PASSWORD")

# http code WITHOUT the front-door credential (for the closed-door assertions).
http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$@" || true; }
# http code WITH the front-door credential.
fcode() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "${FAUTH[@]}" "$@" || true; }
fget()  { curl -s --max-time 30 "${FAUTH[@]}" "$@"; }

wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url")
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 3
  done
}

compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }

# Discover JobSync's `signup` server-action id from the signup page's JS bundle. next-auth/Next.js
# assign the action a build-stable hex id; we find the candidates referenced by the signup page and
# return the one that actually creates an account, so the test survives image bumps.
_signup_action_id() {
  [ -n "${_SIGNUP_AID:-}" ] && { echo "$_SIGNUP_AID"; return 0; }
  local html chunks ch ids id probe email
  html=$(fget "$APP_URL/signup")
  chunks=$(printf '%s' "$html" | grep -oE '/_next/static/chunks/[^"]+\.js' | sort -u)
  ids=$(for ch in $chunks; do fget "$APP_URL$ch" | grep -oE 'createServerReference.{0,4}"[0-9a-f]{40,}' | grep -oE '[0-9a-f]{40,}'; done | sort -u)
  for id in $ids; do
    email="probe-$(date +%s%N)@example.invalid"
    probe=$(curl -s --max-time 30 "${FAUTH[@]}" -X POST "$APP_URL/signup" -H "Next-Action: $id" \
      -H "Content-Type: text/plain;charset=UTF-8" \
      --data "$(jq -nc --arg e "$email" '[{name:"Probe",email:$e,password:"ProbePass123!"}]')")
    if printf '%s' "$probe" | grep -q '"success":true'; then _SIGNUP_AID="$id"; echo "$id"; return 0; fi
  done
  return 1
}

# create_account EMAIL PASSWORD NAME -> 0 if the account is created or already exists.
create_account() {
  local email=$1 password=$2 name=$3 aid resp
  aid=$(_signup_action_id) || return 1
  resp=$(curl -s --max-time 30 "${FAUTH[@]}" -X POST "$APP_URL/signup" -H "Next-Action: $aid" \
    -H "Content-Type: text/plain;charset=UTF-8" \
    --data "$(jq -nc --arg n "$name" --arg e "$email" --arg p "$password" '[{name:$n,email:$e,password:$p}]')")
  printf '%s' "$resp" | grep -qE '"success":true|already exists'
}

# signin JAR EMAIL PASSWORD -> 0 if a next-auth session is established (cookie written to JAR).
signin() {
  local jar=$1 email=$2 password=$3 csrf
  csrf=$(fget -c "$jar" "$APP_URL/api/auth/csrf" | jq -r '.csrfToken')
  [ -n "$csrf" ] || return 1
  curl -s -c "$jar" -b "$jar" "${FAUTH[@]}" -o /dev/null -X POST "$APP_URL/api/auth/callback/credentials" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "csrfToken=$csrf" --data-urlencode "email=$email" --data-urlencode "password=$password" \
    --data-urlencode "redirect=false" --data-urlencode "callbackUrl=$APP_URL/dashboard"
  # Confirm via the session endpoint that the user is logged in.
  fget -b "$jar" "$APP_URL/api/auth/session" | grep -q "\"email\":\"$email\""
}

# session_email JAR -> prints the email on the current session (empty if none).
session_email() { fget -b "$1" "$APP_URL/api/auth/session" | jq -r '.user.email // empty' 2>/dev/null; }
