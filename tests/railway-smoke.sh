#!/usr/bin/env bash
# shellcheck disable=SC2015
# Live test of a deployed template: the flows the local smoke covers, over HTTPS.
#
#   FRONT_PASSWORD_FILE=./front-password tests/railway-smoke.sh https://<domain>
#
# Optional:
#   FRONT_USERNAME  front-door user (default owner)
#   APP_EMAIL / APP_PASSWORD  the in-app account to create + sign in (defaults owner@example.com / OwnerPass123!)
# The front-door password is read from a file (never an argument, never printed).
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
[ $# -ge 1 ] || { sed -n '3,12p' "$0"; exit 2; }
APP_URL=${1%/}; export APP_URL
: "${FRONT_PASSWORD_FILE:?set FRONT_PASSWORD_FILE}"
FRONT_PASSWORD=$(tr -d '\n' < "$FRONT_PASSWORD_FILE"); export FRONT_PASSWORD
: "${FRONT_USERNAME:=owner}"; export FRONT_USERNAME
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

section "availability over HTTPS"
wait_for_code "$APP_URL/healthz" 200 300 && pass "healthz returns 200 over HTTPS" || die "not healthy"

section "the front door is closed to the public over HTTPS"
assert_eq "the app root needs the front-door password" "401" "$(http_code "$APP_URL/")"
assert_eq "self-registration is closed to the public (/signup needs the front door)" "401" "$(http_code "$APP_URL/signup")"
assert_eq "a wrong front-door password is rejected" "401" "$(http_code -u "wrong:wrong" "$APP_URL/")"

section "behind the front door over HTTPS"
assert_eq "the app is reachable with the front-door password" "200" "$(fcode "$APP_URL/signup")"
assert_contains "next-auth exposes the credentials provider" "credentials" "$(fget "$APP_URL/api/auth/providers")"

section "account lifecycle over HTTPS"
create_account "$APP_EMAIL" "$APP_PASSWORD" "$APP_NAME" && pass "an account is created via the signup action" || die "account creation failed"
jar="$TEST_TMP/jar"
signin "$jar" "$APP_EMAIL" "$APP_PASSWORD" && pass "the account signs in through next-auth" || die "sign-in failed"
assert_eq "the session belongs to the new account" "$APP_EMAIL" "$(session_email "$jar")"
assert_eq "the authenticated dashboard is reachable" "200" "$(fcode -b "$jar" "$APP_URL/dashboard")"

summary
