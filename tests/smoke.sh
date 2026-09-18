#!/usr/bin/env bash
# shellcheck disable=SC2015
# Smoke test: build + bring the stack up and exercise the product flow — the front door closes the app
# (including JobSync's open self-registration), the health check is open, and behind the door an account
# can be created and signed in through next-auth. Standalone.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'compose logs --no-color --tail 120 || true; compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"' EXIT

section "bring the stack up"
compose up -d --build >/dev/null 2>&1 || die "compose up failed"
wait_for_code "$APP_URL/healthz" 200 240 && pass "healthz is served (healthy)" || die "app never became healthy"

section "the front door is closed to the public"
assert_eq "the app root needs the front-door password" "401" "$(http_code "$APP_URL/")"
assert_eq "self-registration is closed to the public (/signup needs the front door)" "401" "$(http_code "$APP_URL/signup")"
assert_eq "a wrong front-door password is rejected" "401" "$(http_code -u "wrong:wrong" "$APP_URL/")"
assert_eq "healthz stays open (no auth), GET only" "200" "$(http_code "$APP_URL/healthz")"
assert_eq "healthz rejects non-GET" "405" "$(http_code -X POST "$APP_URL/healthz")"

section "behind the front door"
assert_eq "the app is reachable with the front-door password" "200" "$(fcode "$APP_URL/signup")"
assert_contains "next-auth exposes the credentials provider" "credentials" "$(fget "$APP_URL/api/auth/providers")"

section "account lifecycle (next-auth + prisma on the volume)"
create_account "$APP_EMAIL" "$APP_PASSWORD" "$APP_NAME" && pass "an account is created via the signup action" || die "account creation failed"
jar="$TEST_TMP/jar"
signin "$jar" "$APP_EMAIL" "$APP_PASSWORD" && pass "the account signs in through next-auth" || die "sign-in failed"
assert_eq "the session belongs to the new account" "$APP_EMAIL" "$(session_email "$jar")"
assert_eq "the authenticated dashboard is reachable" "200" "$(fcode -b "$jar" "$APP_URL/dashboard")"

summary
