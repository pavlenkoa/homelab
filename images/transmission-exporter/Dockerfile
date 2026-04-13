# Builder
FROM arm64v8/golang@sha256:0139f94f04d16b8e31a004814b0ad30002bf4b4ccb506a88d414d5ed28750934 as builder

ENV TRANSMISSION_VERSION "master"

RUN apt-get update && apt-get install -y git dmsetup && apt-get clean

RUN git clone --branch ${TRANSMISSION_VERSION} https://github.com/metalmatze/transmission-exporter.git /go/src/github.com/metalmatze/transmission-exporter

WORKDIR /go/src/github.com/metalmatze/transmission-exporter

RUN make build

# Image for usage
FROM arm64v8/debian@sha256:27837f97fe1e95489fc12de39e96f40d12426eb12acbc1bf3bc4de71b37195ab

RUN apt-get update && apt-get install ca-certificates -y && apt-get clean autoclean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/src/github.com/metalmatze/transmission-exporter/transmission-exporter /app/transmission-exporter

RUN chown 1000:1000 -R /app

RUN chmod +x /app/transmission-exporter

EXPOSE 19091

ENTRYPOINT ["/app/transmission-exporter"]
