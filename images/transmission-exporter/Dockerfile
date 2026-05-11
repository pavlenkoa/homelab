# Builder
FROM arm64v8/golang@sha256:cb135c43fc92e4d36d4a9d7b621d608eca1566125ce30c75d96fe7b7ff12a8dc as builder

ENV TRANSMISSION_VERSION "master"

RUN apt-get update && apt-get install -y git dmsetup && apt-get clean

RUN git clone --branch ${TRANSMISSION_VERSION} https://github.com/metalmatze/transmission-exporter.git /go/src/github.com/metalmatze/transmission-exporter

WORKDIR /go/src/github.com/metalmatze/transmission-exporter

RUN make build

# Image for usage
FROM arm64v8/debian@sha256:f86c809edc60cc24aeea5c8b49379a5d7a6fc1392f73c45b3d03c74cd8d4d9c7

RUN apt-get update && apt-get install ca-certificates -y && apt-get clean autoclean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/src/github.com/metalmatze/transmission-exporter/transmission-exporter /app/transmission-exporter

RUN chown 1000:1000 -R /app

RUN chmod +x /app/transmission-exporter

EXPOSE 19091

ENTRYPOINT ["/app/transmission-exporter"]
