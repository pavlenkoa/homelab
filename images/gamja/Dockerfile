# syntax=docker/dockerfile:1@sha256:87999aa3d42bdc6bea60565083ee17e86d1f3339802f543c0d03998580f9cb89

# Builder
FROM node:24-alpine@sha256:2bdb65ed1dab192432bc31c95f94155ca5ad7fc1392fb7eb7526ab682fa5bf14 AS builder

# renovate: datasource=git-refs depName=gamja packageName=https://codeberg.org/emersion/gamja
ARG GAMJA_VERSION=master

RUN apk add --no-cache git
RUN git clone --depth 1 --branch ${GAMJA_VERSION} https://codeberg.org/emersion/gamja.git /src

WORKDIR /src
RUN npm install && npm run build

# Runtime
FROM nginxinc/nginx-unprivileged:alpine@sha256:02c985e54bee40c14c6de677226f394d96c661944185d407e77ca73602f15e1b

COPY --from=builder /src/dist /usr/share/nginx/html
