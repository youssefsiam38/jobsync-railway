# JobSync on Railway

A one-click [Railway](https://railway.com) template that runs [JobSync](https://github.com/Gsync/jobsync) —
an open-source, self-hosted job-search tracker with an AI assistant. Track applications, companies and contacts,
store resumes, and (optionally) use your own AI provider to help draft and analyse — all on your own infrastructure,
behind a **private front door**.

> **Community-maintained and not affiliated.** This template is based on JobSync but is **not affiliated with,
> endorsed by, or an official offering of** the JobSync project, and it does not use the JobSync logo. See
> [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

- **Image:** the official `ghcr.io/gsync/jobsync`, pinned by digest and used **unmodified**, packaged with a Caddy
  basic-auth front door in the same container — see [UPSTREAM.md](UPSTREAM.md) and [ARCHITECTURE.md](ARCHITECTURE.md).
- JobSync is **MIT** licensed; the template's own files are MIT too. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Why the front door

JobSync's sign-up page is open by default — on a public URL, anyone who finds it could create an account on your
instance. This template puts the whole app behind an HTTP **basic-auth front door** (Caddy) with a generated
password, so only you can reach it. JobSync keeps its own account login inside; the front door is the outer gate that
closes public registration.

## What you get

- One service: the JobSync Next.js app on a private loopback port, with a Caddy front door as the only public
  listener. SQLite and uploaded resumes live on a `/data` volume.
- A **generated front-door password** (`OWNER_PASSWORD`, user `OWNER_USERNAME`, default `owner`).
- Generated `AUTH_SECRET` (session signing) and `ENCRYPTION_KEY` (encrypts any AI provider keys you save in-app).

## Deploy

1. Click **Deploy on Railway** and wait for the service to go healthy.
2. Open the service → **Variables** and copy `OWNER_PASSWORD` (the front-door password; user `owner`).
3. Open the public domain. Your browser asks for the front-door credentials — enter `owner` / `OWNER_PASSWORD`.
4. JobSync opens on its **sign-up** screen (the instance has no account yet). Create your JobSync account — this is
   your login inside the app. From then on you sign in with it (still behind the front door).

To use the AI features, add your own provider key (OpenAI, Gemini, DeepSeek, OpenRouter or Ollama) in JobSync's
Settings. Keys are encrypted with `ENCRYPTION_KEY` — don't change that variable after saving keys, or they become
unrecoverable.

## Security

See [SECURITY.md](SECURITY.md). In short: guard `OWNER_PASSWORD`; the front door is what keeps the instance private
and closes open registration. Back up the `/data` volume.

## Repository layout

| Path | What |
|---|---|
| `images/app/` | The combined wrapper: official JobSync image + Caddy front door (`Dockerfile`, `Caddyfile`, `entrypoint.sh`) |
| `compose.yaml` | Local test topology (builds the wrapper, one service, a volume) |
| `tests/` | Static, smoke, persistence, and live (HTTPS) tests |
| `marketplace/OVERVIEW.md` | The marketplace overview shown on the template page |
| `RAILWAY_TEMPLATE.md` | The exact published template configuration |
| `UPSTREAM.md` · `SECURITY.md` · `ARCHITECTURE.md` · `MAINTENANCE.md` | Reference docs |

## Local development

```bash
JOBSYNC_TEST_OWNER_PASSWORD=change-me docker compose up --build   # official image behind the Caddy front door
tests/smoke.sh          # front-door gates, then create an account + sign in through next-auth
tests/persistence.sh    # the account survives a restart (SQLite on the volume)
```

## Licence

The template's own files are MIT (`LICENSE`). JobSync is MIT; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
