# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32

# Builder
FROM golang:1.27-alpine@sha256:4c9fe60190a2a3350ddc51de80d0224b8a6698d12bdfc999fee45ea9d6c46dbc AS builder

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
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

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
