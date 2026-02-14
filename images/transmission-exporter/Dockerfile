# Builder
FROM arm64v8/golang@sha256:eccc42120feda583946743daf9b06307d15382ce2ddae87d0e515def5d20ffb3 as builder

ENV TRANSMISSION_VERSION "master"

RUN apt-get update && apt-get install -y git dmsetup && apt-get clean

RUN git clone --branch ${TRANSMISSION_VERSION} https://github.com/metalmatze/transmission-exporter.git /go/src/github.com/metalmatze/transmission-exporter

WORKDIR /go/src/github.com/metalmatze/transmission-exporter

RUN make build

# Image for usage
FROM arm64v8/debian@sha256:ac2d4374b72e61ebd9d0bc433dd03d7f0f4670b863b0b51bd6206f7d53119381

RUN apt-get update && apt-get install ca-certificates -y && apt-get clean autoclean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/src/github.com/metalmatze/transmission-exporter/transmission-exporter /app/transmission-exporter

RUN chown 1000:1000 -R /app

RUN chmod +x /app/transmission-exporter

EXPOSE 19091

ENTRYPOINT ["/app/transmission-exporter"]
