# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32

# Builder
FROM golang:1.27-alpine@sha256:4cb7ac979db5fcc41cae44b2227ba5ab8a51e8807f40d9ba4dee20a0ad960b5b AS builder

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
