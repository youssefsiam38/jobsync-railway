# Deploy and Host JobSync on Railway

JobSync is an open-source, self-hosted job-search tracker with an AI assistant: track applications, companies and
contacts, store resumes, and optionally use your own AI provider to help draft and analyse. This template deploys
JobSync behind a private basic-auth front door with a generated password, so your instance is not open to the public.
It is a community-maintained template based on JobSync; it is not affiliated with, endorsed by, or an official
offering of the JobSync project, and it does not use the JobSync logo.

## About Hosting JobSync

JobSync is a Next.js app that stores everything in SQLite and keeps uploaded resumes on disk, with its own next-auth
login. Its sign-up page, however, is open by default — on a public URL anyone who found it could create an account on
your instance. This template runs the official JobSync image unmodified but puts the whole app behind a Caddy HTTP
basic-auth front door: only holders of the generated front-door password can reach JobSync at all, including its
sign-up page, which closes that exposure. JobSync's own account login still applies inside.

This template runs JobSync on Railway with a generated front-door password, a generated session-signing key and
API-key encryption key, its data persisted on a volume, and the port and health check wired. The database migrates
automatically on first boot.

## Common Use Cases

- A private, self-hosted tracker for your job search — applications, statuses, companies, contacts and resumes.
- A personal AI-assisted job-hunt workspace driven by your own OpenAI, Gemini, DeepSeek, OpenRouter or Ollama key.
- A self-hosted backend you can drive from AI clients through JobSync's built-in MCP server.

## Dependencies for JobSync Hosting

- Nothing external is required: the database is embedded (SQLite on the volume) and resumes live alongside it.
- To use the AI features you provide your own AI-provider key, entered in JobSync's Settings and encrypted at rest.

### Deployment Dependencies

- JobSync: https://github.com/Gsync/jobsync (MIT)
- Template repository and tests: https://github.com/youssefsiam38/jobsync-railway

### Implementation Details

The template runs the official `ghcr.io/gsync/jobsync` image, pinned by digest and unmodified, packaged in one
container with a Caddy basic-auth front door (Caddy is the only public listener; JobSync stays on loopback). The
front door uses `OWNER_USERNAME` (default `owner`) and a generated `OWNER_PASSWORD`, hashed at start-up. JobSync runs
with a generated `AUTH_SECRET`, a generated `ENCRYPTION_KEY` (encrypts saved AI-provider keys), `AUTH_TRUST_HOST=true`
and `NEXTAUTH_URL` set to the public domain; `DATABASE_URL` points at SQLite on the `/data` volume and migrations run
at start-up. Railway's health check hits `/healthz` (answered by Caddy without auth, GET only).

Tested in CI and on a live deployment of this template: the front door returns `401` on the app and the sign-up page
without the password, rejects a wrong password, and keeps `/healthz` open; behind the door an account is created and
signed in, the dashboard loads, and the account survives a redeploy.

After deploying, copy `OWNER_PASSWORD` from the service's variables, open the public domain, enter the front-door
credentials (`owner` / `OWNER_PASSWORD`), then create your JobSync account on the sign-up screen. Add an AI-provider
key in Settings if you want the AI features.

## Why Deploy JobSync on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you
don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying JobSync on Railway, you are one step closer to supporting a complete full-stack application with minimal
burden. Host your servers, databases, AI agents, and more on Railway.
