# Maintenance

## Updating to a new JobSync version

1. **Bump the upstream pin.** Get the new digest (see `UPSTREAM.md`) and update the `ARG JOBSYNC_IMAGE` line in
   `images/app/Dockerfile`.
2. **Run the tests locally.**
   ```bash
   tests/static.sh
   docker compose build
   tests/smoke.sh
   tests/persistence.sh
   ```
3. **Cut a release tag** (`git tag v1.0.1 && git push --tags`). `publish-image.yml` re-runs the tests, then builds and
   pushes the multi-arch wrapper image to `ghcr.io/youssefsiam38/jobsync-railway`.
4. **Make the GHCR package public** (once, on first publish) so Railway can pull it.
5. **Re-point the template** at the new wrapper digest and re-run the clean-room deploy + `tests/railway-smoke.sh`
   before updating the published template.

## Rebuilding the Railway template from scratch

The exact configuration is in `RAILWAY_TEMPLATE.md`. The generator spec is `_audit/spec_jobsync.py`; the kit in
`_audit/` (`tplkit.py`) builds a skeleton, patches the template, and runs a clean-room deploy. Volumes, domains and
health checks are only set by `skeleton()`, so a change to those requires rebuilding from a skeleton; if
`verify_template` reports an empty volume right after create, delete the template and re-create it.

## Gotchas worth remembering

- **The front door closes open registration.** JobSync's `/signup` is open by default; the Caddy basic-auth gate is
  the only thing keeping a public instance private. `/healthz` is the sole open path (GET only, answered by Caddy).
- **Combined image, not two services.** JobSync's entrypoint hard-codes `HOSTNAME=0.0.0.0` (IPv4); Railway's private
  network is IPv6, so a separate front-door service couldn't reach a private JobSync. Caddy + JobSync share one
  container and talk over loopback (`127.0.0.1:3737`).
- **`DATABASE_URL` must be set at runtime.** The base image only sets it in its build stage; the wrapper sets
  `ENV DATABASE_URL=file:/data/dev.db` so `prisma migrate deploy` and the server both find it.
- **HTTPS behind the proxy.** Caddy sends `X-Forwarded-Proto` from `FORWARD_PROTO` (default `https`; local tests set
  `http`). next-auth runs with `AUTH_TRUST_HOST=true` and `NEXTAUTH_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}`.
- **`ENCRYPTION_KEY` is forever.** It encrypts stored AI-provider keys; changing it strands them.
- **Tests auto-discover the signup action id.** JobSync's sign-up is a Next.js server action; the tests find its
  build-stable id from the page bundle and call it, so they survive image bumps without hard-coding the id.
