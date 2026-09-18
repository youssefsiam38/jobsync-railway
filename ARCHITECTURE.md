# Architecture

## Service graph

```
        Railway HTTPS edge
              │
              ▼
   ┌───────────────────────────────────────────────────────────┐
   │  app  (public domain :8080)                                 │  volume: /data
   │                                                             │   - SQLite  (file:/data/dev.db)
   │   Caddy front door  :8080  (the only public listener)       │   - resume uploads (/data/files/resumes)
   │     - /healthz            -> 200 (no auth, GET only)         │
   │     - everything else     -> HTTP basic auth                │
   │                              │                              │
   │                              ▼                              │
   │   JobSync (Next.js)  127.0.0.1:3737  (loopback only)        │
   │     - web app + next-auth login + REST + built-in MCP       │
   └───────────────────────────────────────────────────────────┘
```

One container, one service. A Caddy front door listens on the public port; JobSync's Next.js server listens only on
loopback. Nothing reaches JobSync without passing the front door, which is what closes JobSync's open self-registration
on a public URL. Running both in one container means Caddy proxies over loopback, so there is no dependence on
Railway's private network.

## The app service

- Image: a thin combined image built `FROM` the official `ghcr.io/gsync/jobsync` (pinned by digest, unmodified) plus
  Caddy from Alpine. Built and pushed to GHCR by CI; see `UPSTREAM.md`.
- **Port:** Caddy binds the public `PORT` (8080); JobSync runs on `127.0.0.1:3737`. The public domain targets 8080
  and Railway's health check hits `/healthz` (answered by Caddy, GET only).
- **Front door.** `OWNER_USERNAME` (default `owner`) + a generated `OWNER_PASSWORD`. The entrypoint hashes the
  password with `caddy hash-password` at start-up (the plaintext never touches the Caddyfile or the process list).
- **App auth.** JobSync uses next-auth v5 (credentials). `AUTH_SECRET` signs sessions; `AUTH_TRUST_HOST=true` and
  `NEXTAUTH_URL=https://<domain>` let it build correct callback URLs behind the proxy (Caddy sets
  `X-Forwarded-Proto: https`). The first visitor (behind the front door) creates the account on the sign-up screen.
- **Data.** `DATABASE_URL=file:/data/dev.db` (baked into the image); Prisma migrations run at start-up. Uploaded
  resumes go to `/data/files/resumes`. The entrypoint runs migrations as root, `chown`s `/data`, then drops to the
  non-root `nextjs` user to run the server.
- **AI provider keys** you save in-app are encrypted at rest with `ENCRYPTION_KEY` (a stable generated value; changing
  it makes stored keys unrecoverable).

## Why a combined image (not two services)

JobSync's entrypoint hard-codes `HOSTNAME=0.0.0.0` (IPv4). Railway's private network is IPv6, so a separate
front-door service could not reach a private JobSync over `*.railway.internal`. Running Caddy and JobSync in the same
container sidesteps that entirely — Caddy dials `127.0.0.1:3737`.
