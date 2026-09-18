# Railway template configuration

The template's exact configuration. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | JobSync |
| Code | `jobsync` |
| Template id | `ec6fccfc-2134-4840-b5ea-0521178772bc` |
| Deploy URL | https://railway.com/deploy/jobsync |
| Category | Other |
| Card description | Self-hosted job-search tracker + AI assistant, behind a private front door |
| Icon | `assets/icon.png` |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |

Generated values use Railway's `secret()` function: `hexN` is `${{secret(N, "abcdef0123456789")}}` and `alnumN` is
`${{secret(N, "a-zA-Z0-9")}}` spelled out. Alphanumeric passwords are used wherever a value is embedded in a
connection URL, so nothing needs percent-encoding. Images are referenced by tag, because the template generator
rejects digests; `UPSTREAM.md` records the digests.

## Services

### `app`

| Field | Value |
|---|---|
| Source | `ghcr.io/youssefsiam38/jobsync-railway:1.0.0@sha256:d36be552ac5f183ac05ade2d04c3fd9cdc5f8dde798c1b8bba9e5c26668e6a42` |
| Public domain | target port 8080 |
| Volume | `/data` |
| Healthcheck | `/healthz`, timeout from `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `PORT` | `8080` |
| `OWNER_USERNAME` | `owner` |
| `OWNER_PASSWORD` | generated, alnum24 |
| `AUTH_SECRET` | generated, alnum48 |
| `ENCRYPTION_KEY` | generated, alnum48 |
| `AUTH_TRUST_HOST` | `true` |
| `NEXTAUTH_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |
| `FORWARD_PROTO` | `https` |
| `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `300` |

## Notes

- **Combined wrapper image, one service.** Built `FROM` the official `ghcr.io/gsync/jobsync` (pinned by digest,
  unmodified) plus a Caddy basic-auth front door in the same container, published to
  `ghcr.io/youssefsiam38/jobsync-railway:1.0.0` (digest
  `sha256:d36be552ac5f183ac05ade2d04c3fd9cdc5f8dde798c1b8bba9e5c26668e6a42`). Caddy is the only public listener on
  `$PORT` (8080); JobSync runs on loopback `127.0.0.1:3737`.
- **Front door closes open registration.** JobSync's `/signup` is open by default; the Caddy gate (`OWNER_USERNAME` /
  generated `OWNER_PASSWORD`) returns 401 on the app and the sign-up page without the password. `/healthz` is the only
  open path (GET only). JobSync's own next-auth login applies inside.
- **No required deploy inputs** — the front-door password, `AUTH_SECRET` and `ENCRYPTION_KEY` are all generated;
  `NEXTAUTH_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}`, `AUTH_TRUST_HOST=true`, `FORWARD_PROTO=https`. AI-provider keys
  are optional, added in-app (encrypted with `ENCRYPTION_KEY`).
- **Health `/healthz`; `PORT`=8080; `/data` volume** holds SQLite (`file:/data/dev.db`) and resume uploads. The image
  sets `DATABASE_URL` and runs prisma migrations at start-up as root, then drops to the non-root `nextjs` user.
- **Licence:** JobSync is MIT (used unmodified); the template files and the Caddy wrapper are MIT/Apache-2.0.
