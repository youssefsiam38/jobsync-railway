# Third-party notices

This template runs the following third-party software. Each keeps its own licence; the template's own files are MIT
(see `LICENSE`).

## JobSync

- Source: https://github.com/Gsync/jobsync
- Licence: **MIT** — full text in `licenses/JOBSYNC-LICENSE`.
- Used **unmodified** from the official image `ghcr.io/gsync/jobsync` (pinned by digest in `UPSTREAM.md`). The
  template's combined image only adds a Caddy front door alongside JobSync; it does not modify JobSync's code or
  assets.

> **Trademark / brand.** "JobSync", its logo, and other brand identifiers are the marks of the JobSync project and
> are not claimed by this template. This is a community-maintained deployment template that is based on JobSync; it is
> **not affiliated with, endorsed by, or an official offering of** the JobSync project, and it does not use the
> JobSync logo (it ships its own generic icon).

## Caddy

The combined image adds the Caddy web server (Apache-2.0) from the Alpine community repository, used unmodified as the
basic-auth front door.

---

This template is community-maintained and is not affiliated with the JobSync project.
