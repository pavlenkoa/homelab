# syntax=docker/dockerfile:1@sha256:2780b5c3bab67f1f76c781860de469442999ed1a0d7992a5efdf2cffc0e3d769

# Builder
FROM node:24-alpine@sha256:d1b3b4da11eefd5941e7f0b9cf17783fc99d9c6fc34884a665f40a06dbdfc94f AS builder

# renovate: datasource=git-refs depName=gamja packageName=https://codeberg.org/emersion/gamja
ARG GAMJA_VERSION=master

RUN apk add --no-cache git
RUN git clone --depth 1 --branch ${GAMJA_VERSION} https://codeberg.org/emersion/gamja.git /src

WORKDIR /src
RUN npm install && npm run build

# Runtime
FROM nginxinc/nginx-unprivileged:alpine@sha256:4c18337659c90a01627f2e152b7c89524521c82dcedb255dc83d3689642b0803

COPY --from=builder /src/dist /usr/share/nginx/html
