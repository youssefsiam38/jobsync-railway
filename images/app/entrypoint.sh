#!/bin/sh
# Combined entrypoint for the JobSync Railway template.
# Starts the Next.js server on loopback and a Caddy basic-auth front door on the public $PORT.
# The front-door password is hashed at start-up (the plaintext never reaches the Caddyfile or the
# process list). Secrets are never printed. Mirrors upstream's docker-entrypoint (migrate + drop to
# the nextjs user) but keeps JobSync private behind Caddy.
set -eu

log() { printf '[jobsync-railway] %s\n' "$*"; }
die() { printf '[jobsync-railway] ERROR: %s\n' "$*" >&2; exit 1; }

INTERNAL_PORT=3737

[ -n "${OWNER_PASSWORD:-}" ] || die "OWNER_PASSWORD is not set. It is the front-door password (user: ${OWNER_USERNAME:-owner})."
[ "${#OWNER_PASSWORD}" -ge 8 ] || die "OWNER_PASSWORD is too short; use at least 8 characters."
[ -n "${AUTH_SECRET:-}" ] || die "AUTH_SECRET is not set (next-auth session signing key)."
[ -n "${ENCRYPTION_KEY:-}" ] || die "ENCRYPTION_KEY is not set (used to encrypt stored provider API keys)."

cd /app

# Apply database migrations as root, then hand the data dir to the nextjs user.
log "applying database migrations"
npx -y prisma@6.19.0 migrate deploy
mkdir -p /data/files/resumes
chown -R nextjs:nodejs /data

# Front-door credentials: hash the password for Caddy; the plaintext stays out of the config.
CADDY_PASSWORD_HASH="$(caddy hash-password --plaintext "$OWNER_PASSWORD")"
export CADDY_PASSWORD_HASH
export OWNER_USERNAME="${OWNER_USERNAME:-owner}"
export INTERNAL_PORT

# Start JobSync on loopback as the nextjs user.
log "starting JobSync on 127.0.0.1:${INTERNAL_PORT}"
export HOME=/home/nextjs
su -s /bin/sh nextjs -c "cd /app && HOSTNAME=127.0.0.1 PORT=${INTERNAL_PORT} node server.js" &
APP_PID=$!

# If JobSync dies, take the container down so Railway restarts it.
trap 'kill "$APP_PID" 2>/dev/null || true' TERM INT

log "front door starting on :${PORT:-8080} (basic auth, user: ${OWNER_USERNAME})"
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
