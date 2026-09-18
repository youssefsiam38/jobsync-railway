# Security

## The front door closes open registration

JobSync's sign-up page is open by default: on a public URL, anyone who reached it could create an account on your
instance (and spend any AI-provider quota you configured). This template puts the **entire app behind an HTTP
basic-auth front door** (Caddy) with a generated `OWNER_PASSWORD`, so only holders of that password reach JobSync at
all — including its `/signup` page. JobSync's own next-auth login still applies inside. The only unauthenticated path
is `/healthz` (GET only), which Caddy answers itself and which never exposes an app route.

Verified in the smoke, persistence and live tests: `/` and `/signup` return `401` without the front-door password, a
wrong password is rejected, `/healthz` is `200` (and `405` for non-GET), and behind the door an account can be
created and signed in.

## What the template does

- **Generated front-door password** (`OWNER_PASSWORD`, 24 alphanumerics; user `OWNER_USERNAME`, default `owner`).
  Hashed with `caddy hash-password` at start-up — the plaintext never reaches the Caddyfile or the process list.
- **Generated `AUTH_SECRET`** (next-auth session signing) and **`ENCRYPTION_KEY`** (encrypts AI-provider keys you save
  in-app), both stable across restarts.
- **HTTPS-aware.** Caddy sets `X-Forwarded-Proto: https` and next-auth runs with `AUTH_TRUST_HOST=true` and
  `NEXTAUTH_URL` set to the public domain, so session cookies are `Secure` and callbacks resolve correctly.
- **Runs unmodified & non-root.** The official JobSync image is used unmodified (pinned by digest); the server runs as
  the non-root `nextjs` user, migrations run once at start-up.
- **Secret hygiene.** No secret is committed; tests read the front-door password from a mode-restricted file over
  HTTPS and never print it; the static test greps the tree for credential shapes.

## What you should do

- **Copy and guard `OWNER_PASSWORD`.** It is the key to the whole instance. Rotate it by changing the variable.
- **Create your JobSync account promptly** (first visit, behind the front door) and use a strong password.
- **Set `ENCRYPTION_KEY` once and never change it** after saving any AI-provider key, or stored keys become
  unrecoverable. Your AI-provider keys are yours, entered in JobSync's Settings.
- **Back up the `/data` volume** (SQLite + resumes) with Railway's volume backups.

## Reporting

For issues in JobSync itself, report upstream. For issues specific to this template's packaging (the front door),
open an issue on the template repository.
