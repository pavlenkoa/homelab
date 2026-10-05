# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

# Builder
FROM golang:1.27-alpine@sha256:8a5910f31396cd4d89662f56c68b3ae31d374308270a1c3bd96672ee5ed43414 AS builder

# renovate: datasource=git-refs depName=soju packageName=https://codeberg.org/emersion/soju
ARG SOJU_VERSION=v0.10.1

RUN apk add --no-cache gcc musl-dev sqlite-dev git

RUN git clone --depth 1 --branch ${SOJU_VERSION} https://codeberg.org/emersion/soju.git /src

WORKDIR /src

ENV CGO_ENABLED=1
RUN go build -o /out/soju ./cmd/soju \
 && go build -o /out/sojuctl ./cmd/sojuctl \
 && go build -o /out/sojudb ./cmd/sojudb

# Runtime
FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

RUN apk add --no-cache ca-certificates sqlite tzdata \
 && addgroup -g 1000 soju \
 && adduser -D -u 1000 -G soju soju

COPY --from=builder /out/soju /usr/local/bin/soju
COPY --from=builder /out/sojuctl /usr/local/bin/sojuctl
COPY --from=builder /out/sojudb /usr/local/bin/sojudb

RUN mkdir -p /data /var/run/soju \
 && chown -R soju:soju /data /var/run/soju

USER soju

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/soju"]
CMD ["-config", "/etc/soju/soju.cfg"]
