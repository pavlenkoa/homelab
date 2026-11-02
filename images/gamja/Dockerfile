# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

# Builder
FROM node:24-alpine@sha256:8a32c8cf649a49915a66e81e7a609223c708d0adabf288ee3f4077d765542f85 AS builder

# renovate: datasource=git-refs depName=gamja packageName=https://codeberg.org/emersion/gamja
ARG GAMJA_VERSION=master

RUN apk add --no-cache git
RUN git clone --depth 1 --branch ${GAMJA_VERSION} https://codeberg.org/emersion/gamja.git /src

WORKDIR /src
RUN npm install && npm run build

# Runtime
FROM nginxinc/nginx-unprivileged:alpine@sha256:b5047b9b76845eac124358373c6852377c52e4b05834a47647e955dd91cb8f1e

COPY --from=builder /src/dist /usr/share/nginx/html
