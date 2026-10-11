# Mac Mini native services (outside GitOps)

Everything under `host/macmini/` runs natively on macOS, not in k3s. Nothing here is
managed by ArgoCD; install and restore by hand with the steps below. Secrets are never
committed.

| Service | Purpose | Managed by | Repo files |
|---|---|---|---|
| node_exporter | Host metrics on `:9100`, scraped by vmagent via `host.internal` | `brew services` | `Brewfile`, `node_exporter/node_exporter.args` |
| fluent-bit | Tails Emby's log and pushes it to Loki (`job=emby`) | LaunchAgent `io.homelab.fluent-bit` | `fluent-bit/*` |
| mdns-reflector | Bonjour bridge VM <-> LAN for HomeKit, see `homekit-mdns.md` | LaunchAgent `io.homelab.mdns-reflector` | `mdns-reflector/*` |
| whisperkit-server | Speech-to-text for pan-agent voice messages (OpenAI-compatible API on `127.0.0.1:50060`, Whisper large-v3-turbo on the Neural Engine) | LaunchAgent `io.homelab.whisperkit-server` | `whisperkit-server/*` |
| NFS mount | Mounts the Pi's `192.168.88.3:/` at `/Users/Shared/kyiv_storage` | LaunchDaemon `com.kyiv.nfsmount` | `launchd/com.kyiv.nfsmount.plist` |

## Packages

```bash
brew bundle --file host/macmini/Brewfile
```

## node_exporter

```bash
cp host/macmini/node_exporter/node_exporter.args /opt/homebrew/etc/node_exporter.args
brew services restart node_exporter
```

The args file holds `--no-collector.thermal`: that collector fails on every scrape on
Apple Silicon and floods `node_exporter.err.log`.

## fluent-bit

The Homebrew service is **not** used: its default config is a `dummy` input that spams
the log. Our own LaunchAgent runs `run.sh`, which loads credentials and starts fluent-bit.

```bash
brew services stop fluent-bit                      # if the stock service is running
mkdir -p ~/.config/fluent-bit
cp host/macmini/fluent-bit/{fluent-bit.conf,emby-parsers.conf,run.sh} ~/.config/fluent-bit/
cp host/macmini/fluent-bit/loki.env.example ~/.config/fluent-bit/loki.env
chmod 600 ~/.config/fluent-bit/loki.env            # then fill in LOKI_USER / LOKI_PASS
cp host/macmini/fluent-bit/io.homelab.fluent-bit.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.homelab.fluent-bit.plist
```

- Target is `https://loki.pavlenko.io` (basic auth, htpasswd in Vault `kv/monitoring/loki`;
  the plain password is not stored anywhere in the repo). Local DNS resolves it to the Mac
  itself (`192.168.88.2`), so traffic stays on the LAN.
- Only `embyserver.txt` is tailed (multi-line stack traces are joined). Rotated files and
  `ffmpeg-transcode-*` logs are ignored.
- Query in Grafana: `{job="emby"}`.
- Log: `/opt/homebrew/var/log/fluent-bit.log`.

## whisperkit-server (speech-to-text)

[Argmax's WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) ships an OpenAI-compatible
local server (`POST /v1/audio/transcriptions`). Core ML puts the model on the Neural Engine, so
it stays fast and small in memory (a 10 s voice note takes about a second). pan-agent's person
pods call it to turn Telegram voice messages into text.

Build once (pin the commit; building needs Xcode command-line tools, ~4 min), then install:

```bash
git clone https://github.com/argmaxinc/argmax-oss-swift.git && cd argmax-oss-swift
git checkout 9f99b5c
BUILD_ALL=1 swift build -c release --product argmax-cli
mkdir -p ~/.local/opt/whisperkit-server
cp .build/release/argmax-cli ~/.local/opt/whisperkit-server/
cp -R .build/release/*.bundle ~/.local/opt/whisperkit-server/   # resource bundles must sit next to the binary
cd - && cp host/macmini/whisperkit-server/io.homelab.whisperkit-server.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.homelab.whisperkit-server.plist
```

- The first start downloads the model (about 1.5 GB, to `~/Documents/huggingface`) and compiles it
  for the Neural Engine, which takes a minute or two; later starts reuse the cache. Until it is
  up, clients get connection refused and pan-agent tells the person the voice note couldn't be
  transcribed.
- The model is chosen by `--model` in the plist (the server ignores the `model` field of requests).
  Other WhisperKit builds, e.g. the smaller `large-v3-v20240930_626MB`, work the same way.
- **Bound to loopback only.** OrbStack forwards `host.internal` (`0.250.250.254` inside pods) to the
  Mac's loopback, so pods reach it while LAN devices are refused; there is no authentication on the
  server itself, so do not change `--host` to `0.0.0.0`. pan-agent's egress policy allows only that
  address and port (`network.transcribeCidrs` / `transcribePort` in
  `kubernetes/apps/pan-agent/values/homelab.yaml`).
- Smoke test: `curl -F file=@voice.ogg -F model=x http://127.0.0.1:50060/v1/audio/transcriptions`
  (the field must be non-empty). Log: `/opt/homebrew/var/log/whisperkit-server.log`.

## NFS mount (root daemon)

```bash
sudo cp host/macmini/launchd/com.kyiv.nfsmount.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system /Library/LaunchDaemons/com.kyiv.nfsmount.plist
sudo launchctl bootout system/com.kyiv.nfsmount      # to stop / unmount handling
```
