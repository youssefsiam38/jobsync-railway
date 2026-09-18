# syntax=docker/dockerfile:1
#
# Combined image for the JobSync Railway template: the official JobSync image plus a Caddy
# basic-auth front door in the same container. Caddy is the only public listener; the Next.js
# server stays on loopback (127.0.0.1:3737), so nothing reaches JobSync without the front-door
# password. This closes JobSync's open self-registration on a public URL. JobSync is unmodified.
ARG JOBSYNC_IMAGE=ghcr.io/gsync/jobsync:1.1.20@sha256:74f30048e13d126073b1793b6450147f9b81fc4494293d1ad32a8d7bedf30e5b

FROM ${JOBSYNC_IMAGE}
ARG WRAPPER_VERSION=0.0.0-dev
ARG VCS_REF=unknown
ARG BUILD_DATE=1970-01-01T00:00:00Z

USER root
# Caddy from the Alpine community repo (the base is node:20-alpine).
RUN apk add --no-cache caddy

# The base image only sets DATABASE_URL in its build stage; prisma migrate and the running
# server both need it at runtime. SQLite lives on the /data volume.
ENV DATABASE_URL=file:/data/dev.db

COPY images/app/Caddyfile /etc/caddy/Caddyfile
COPY --chmod=0755 images/app/entrypoint.sh /usr/local/bin/jobsync-entrypoint

LABEL org.opencontainers.image.title="jobsync-railway" \
      org.opencontainers.image.description="JobSync plus a Caddy basic-auth front door for the JobSync Railway template. Not affiliated with the JobSync project." \
      org.opencontainers.image.source="https://github.com/youssefsiam38/jobsync-railway" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${WRAPPER_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENTRYPOINT ["/usr/local/bin/jobsync-entrypoint"]
