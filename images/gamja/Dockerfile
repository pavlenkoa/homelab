# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32

# Builder
FROM node:24-alpine@sha256:ebfe2f90462722a7a4de65e91990e97fe0d401c70e0e762c5b53302f905ec1c1 AS builder

# renovate: datasource=git-refs depName=gamja packageName=https://codeberg.org/emersion/gamja
ARG GAMJA_VERSION=master

RUN apk add --no-cache git
RUN git clone --depth 1 --branch ${GAMJA_VERSION} https://codeberg.org/emersion/gamja.git /src

WORKDIR /src
RUN npm install && npm run build

# Runtime
FROM nginxinc/nginx-unprivileged:alpine@sha256:e75f89810bf5bfbcf58a1cfb32a1a11de55b7623d732e67735d513b720d7436a

COPY --from=builder /src/dist /usr/share/nginx/html
