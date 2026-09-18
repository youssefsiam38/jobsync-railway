# Marketplace audit

A record of the diligence behind publishing this template.

## Identity

- Template: **JobSync** — a self-hosted job-search tracker (applications, companies, contacts, resumes) with an
  optional AI assistant and a built-in MCP server.
- Upstream: [Gsync/jobsync](https://github.com/Gsync/jobsync), MIT, actively maintained (Next.js 15 / Prisma / SQLite
  / next-auth v5).

## Licence and brand

- **MIT** (`licenses/JOBSYNC-LICENSE`), no non-commercial or competing-use restriction, so publishing a Marketplace
  template is permitted. The image is used unmodified; the template's own files are MIT.
- **Brand.** "JobSync" and its logo are the project's marks. This template is community-maintained, states only that
  it is based on JobSync, ships its own generic icon, and does not imply official status. See `THIRD_PARTY_NOTICES.md`.

## Security review

- **Open self-registration closed at a front door.** JobSync's `/signup` is open by default. The template wraps the
  app in a Caddy HTTP basic-auth front door (generated `OWNER_PASSWORD`); `/` and `/signup` return `401` without it, a
  wrong password is rejected, and `/healthz` (GET only) is the sole open path — all verified live. JobSync's own
  next-auth login still applies behind the door.
- **Secret handling.** The front-door password is hashed at start-up (never in the Caddyfile or process list);
  `AUTH_SECRET` and `ENCRYPTION_KEY` are generated; AI-provider keys are the deployer's own, entered in-app and
  encrypted at rest. The tests read the front-door password from a mode-restricted file and never print it.
- **Runs unmodified & non-root, pinned by digest.** The official JobSync image is pinned by digest and run as the
  non-root `nextjs` user; Prisma migrations run at start-up.

## Reproducibility & tests

- `tests/static.sh` (22 checks): syntax, shellcheck, compose shape, upstream digest pin, `DATABASE_URL`, front-door
  and auth wiring, secret scan.
- `tests/smoke.sh` (12 checks): the front door closes `/` and `/signup` (401), rejects a wrong password, keeps
  `/healthz` open (GET only, 405 otherwise); behind the door an account is created via JobSync's signup server action
  and signed in through next-auth, and the authenticated dashboard is reachable.
- `tests/persistence.sh` (4 checks): the account (SQLite on the volume) survives a full restart.
- `tests/railway-smoke.sh`: the same flows over HTTPS against the deployed template.
- CI runs static + smoke + persistence on every push; `publish-image.yml` re-runs them before pushing the wrapper
  image to GHCR on a release tag.

## Deploy-time inputs

- `OWNER_PASSWORD` — generated (the front-door password; copy it to reach the app). `OWNER_USERNAME` defaults to
  `owner`.
- `AUTH_SECRET`, `ENCRYPTION_KEY` — generated and stable. `NEXTAUTH_URL` is set to the public domain;
  `AUTH_TRUST_HOST=true`.
- Everything else is fixed by the template (port, health check, volume). AI-provider keys are optional, added in-app.

## Verdict

Shippable. A self-contained, reproducible, single-service deployment that closes JobSync's open registration behind a
generated-password front door, runs the official image unmodified, and whose front-door gate, account lifecycle and
persistence are verified on a live Railway deployment.
