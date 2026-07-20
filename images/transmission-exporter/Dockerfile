# Builder
FROM arm64v8/golang@sha256:fab61ab761e623523019f2c625589b95bf46a82cbaf6246b0cf7e272c2700062 as builder

ENV TRANSMISSION_VERSION "master"

RUN apt-get update && apt-get install -y git dmsetup && apt-get clean

RUN git clone --branch ${TRANSMISSION_VERSION} https://github.com/metalmatze/transmission-exporter.git /go/src/github.com/metalmatze/transmission-exporter

WORKDIR /go/src/github.com/metalmatze/transmission-exporter

RUN make build

# Image for usage
FROM arm64v8/debian@sha256:86ae726ebdb11cd3e64f4f6ede3fb1b238e3b185844e64118419bf3eb8b3f210

RUN apt-get update && apt-get install ca-certificates -y && apt-get clean autoclean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/src/github.com/metalmatze/transmission-exporter/transmission-exporter /app/transmission-exporter

RUN chown 1000:1000 -R /app

RUN chmod +x /app/transmission-exporter

EXPOSE 19091

ENTRYPOINT ["/app/transmission-exporter"]
