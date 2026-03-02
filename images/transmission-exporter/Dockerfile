# Builder
FROM arm64v8/golang@sha256:a813bd4fbb5bb233ef2a1de0162c89fc79d65022a52aa638e4e0deabf3278a7b as builder

ENV TRANSMISSION_VERSION "master"

RUN apt-get update && apt-get install -y git dmsetup && apt-get clean

RUN git clone --branch ${TRANSMISSION_VERSION} https://github.com/metalmatze/transmission-exporter.git /go/src/github.com/metalmatze/transmission-exporter

WORKDIR /go/src/github.com/metalmatze/transmission-exporter

RUN make build

# Image for usage
FROM arm64v8/debian@sha256:aeefdaef458daa6788d5d2c9b935230270a35f7dde5d9f5edeb22eee4578f8f9

RUN apt-get update && apt-get install ca-certificates -y && apt-get clean autoclean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/src/github.com/metalmatze/transmission-exporter/transmission-exporter /app/transmission-exporter

RUN chown 1000:1000 -R /app

RUN chmod +x /app/transmission-exporter

EXPOSE 19091

ENTRYPOINT ["/app/transmission-exporter"]
