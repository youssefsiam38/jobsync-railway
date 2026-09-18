#!/usr/bin/env bash
# shellcheck disable=SC2015
# Persistence: accounts and data live in SQLite on the /data volume. Create an account, take the stack
# down keeping the volume, bring it back, and confirm the account still signs in. Standalone.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'compose logs --no-color --tail 100 || true; compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"' EXIT

section "bring the stack up"
compose up -d --build >/dev/null 2>&1 || die "compose up failed"
wait_for_code "$APP_URL/healthz" 200 240 || die "app never became healthy"

section "before restart"
create_account "$APP_EMAIL" "$APP_PASSWORD" "$APP_NAME" || die "account creation failed"
jar="$TEST_TMP/jar"
signin "$jar" "$APP_EMAIL" "$APP_PASSWORD" && pass "account created and signed in before restart" || die "sign-in failed"

section "full restart (volume preserved)"
compose down >/dev/null 2>&1
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_code "$APP_URL/healthz" 200 240 && pass "healthy again after restart" || die "not healthy after restart"

section "after restart"
jar2="$TEST_TMP/jar2"
signin "$jar2" "$APP_EMAIL" "$APP_PASSWORD" && pass "the account persisted (sign-in still works after restart)" || die "sign-in failed after restart"
assert_eq "the persisted session belongs to the account" "$APP_EMAIL" "$(session_email "$jar2")"

summary
