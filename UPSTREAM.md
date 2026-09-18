# Upstream and pinned versions

This template runs **JobSync** (the upstream project by Gsync) from its official image, **unmodified**, packaged with
a Caddy basic-auth front door in a thin combined image built by this repository's CI.

## JobSync (upstream, unmodified)

- Project: https://github.com/Gsync/jobsync
- Licence: MIT (`licenses/JOBSYNC-LICENSE`)
- Official image: `ghcr.io/gsync/jobsync`
- Pinned: `ghcr.io/gsync/jobsync:1.1.20`
  - digest `sha256:74f30048e13d126073b1793b6450147f9b81fc4494293d1ad32a8d7bedf30e5b`
  - multi-arch (linux/amd64, linux/arm64)

The pin lives in `images/app/Dockerfile` (the `ARG JOBSYNC_IMAGE` line). JobSync's own code and assets are not
changed; the combined image only adds Caddy, a Caddyfile and an entrypoint.

## Wrapper image (front door)

- Built from `images/app/Dockerfile` and published to `ghcr.io/youssefsiam38/jobsync-railway` by
  `.github/workflows/publish-image.yml` on a `vX.Y.Z` tag (multi-arch), after the test suite passes.
- Pinned: `ghcr.io/youssefsiam38/jobsync-railway:1.0.0`
  - digest `sha256:d36be552ac5f183ac05ade2d04c3fd9cdc5f8dde798c1b8bba9e5c26668e6a42`
  - multi-arch (linux/amd64, linux/arm64); wraps upstream `1.1.20`.
- The Railway template references this wrapper image, pinned by digest (recorded in `RAILWAY_TEMPLATE.md`).

## Refreshing the upstream digest

```bash
docker buildx imagetools inspect ghcr.io/gsync/jobsync:<version> --format '{{json .Manifest}}' | jq -r .digest
```

Update the pin in `images/app/Dockerfile`, re-run the tests, cut a new `vX.Y.Z` tag to rebuild and push the wrapper
image, then re-point the template at the new wrapper digest. See `MAINTENANCE.md`.
