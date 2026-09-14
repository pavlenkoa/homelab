# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32

# Builder
FROM node:24-alpine@sha256:50c8e8ca1d27439048670df5883f32d57cf81cff6233222c893fd0d9884cbd81 AS builder

# renovate: datasource=git-refs depName=gamja packageName=https://codeberg.org/emersion/gamja
ARG GAMJA_VERSION=master

RUN apk add --no-cache git
RUN git clone --depth 1 --branch ${GAMJA_VERSION} https://codeberg.org/emersion/gamja.git /src

WORKDIR /src
RUN npm install && npm run build

# Runtime
FROM nginxinc/nginx-unprivileged:alpine@sha256:19c132c9ab02d3b783f478743dafc7a7f42e27aa7d2bdcbec1bb1128ca8f2a07

COPY --from=builder /src/dist /usr/share/nginx/html
