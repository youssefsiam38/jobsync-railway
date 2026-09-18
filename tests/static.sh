#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
# Static validation: syntax, shellcheck, compose, upstream image pin and configuration. No Docker build.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
cd "$REPO_ROOT"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

section "syntax"
for f in tests/*.sh images/app/entrypoint.sh; do
  if bash -n "$f" 2>/dev/null; then pass "parses: $f"; else fail "syntax error: $f"; fi
done

section "shellcheck"
if command -v shellcheck >/dev/null; then
  if shellcheck -x -s bash tests/*.sh && shellcheck -s sh images/app/entrypoint.sh; then pass "shellcheck"; else fail "shellcheck"; fi
else
  echo "  SKIP  shellcheck not installed"
fi

section "compose"
if docker compose -f compose.yaml config -q; then pass "compose config"; else fail "compose config"; fi
cfg=$(docker compose -f compose.yaml config --format json)
assert_eq "one service" "app" "$(jq -r '[.services | keys[]] | sort | join(" ")' <<<"$cfg")"
assert_eq "the front door binds to loopback" "127.0.0.1" "$(jq -r '[.services.app.ports[]? | .host_ip] | join(" ")' <<<"$cfg")"
assert_eq "the front door listens on 8080" "8080" "$(jq -r '[.services.app.ports[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "the /data volume is mounted" "/data" "$(jq -r '[.services.app.volumes[]? | .target] | join(" ")' <<<"$cfg")"

section "image pin"
assert_contains "the wrapper builds FROM the official JobSync image, pinned by digest" \
  '^ARG JOBSYNC_IMAGE=ghcr.io/gsync/jobsync:.*@sha256:[0-9a-f]\{64\}$' "$(grep '^ARG JOBSYNC_IMAGE=' images/app/Dockerfile)"
assert_contains "DATABASE_URL is set in the image" 'ENV DATABASE_URL=file:/data/dev.db' "$(cat images/app/Dockerfile)"

section "configuration"
env_json=$(jq -r '.services.app.environment' <<<"$cfg")
assert_contains "the front-door password is wired" 'OWNER_PASSWORD' "$env_json"
assert_contains "the session signing key is wired" 'AUTH_SECRET' "$env_json"
assert_contains "the API-key encryption key is wired" 'ENCRYPTION_KEY' "$env_json"
assert_eq "next-auth trusts the proxy host" "true" "$(jq -r '.services.app.environment.AUTH_TRUST_HOST' <<<"$cfg")"

section "front door posture"
assert_contains "the Caddyfile puts the app behind basic auth" 'basic_auth' "$(cat images/app/Caddyfile)"
assert_contains "healthz is answered without auth" '/healthz' "$(cat images/app/Caddyfile)"
assert_contains "the compose front-door password is a placeholder" 'local-test-only' "$(jq -r '.services.app.environment.OWNER_PASSWORD' <<<"$cfg")"

section "secrets hygiene"
mapfile -t tracked < <(git ls-files 2>/dev/null | grep . || find . -type f -not -path './.git/*' -not -path './test-output/*')
if [ "${#tracked[@]}" -gt 0 ] && grep -lE '(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "${tracked[@]}" 2>/dev/null; then
  fail "a credential-shaped string is in the repository"
else
  pass "no credential-shaped strings in ${#tracked[@]} files"
fi

summary
