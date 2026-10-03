# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32

# Builder
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w" -o /qbit-throttle .

# Runtime
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /qbit-throttle /qbit-throttle

USER nonroot:nonroot
ENTRYPOINT ["/qbit-throttle"]
