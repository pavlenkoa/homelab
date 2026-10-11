# Mac Mini native services (outside GitOps)

Everything under `host/macmini/` runs natively on macOS, not in k3s. Nothing here is
managed by ArgoCD; install and restore by hand with the steps below. Secrets are never
committed.

| Service | Purpose | Managed by | Repo files |
|---|---|---|---|
| node_exporter | Host metrics on `:9100`, scraped by vmagent via `host.internal` | `brew services` | `Brewfile`, `node_exporter/node_exporter.args` |
| fluent-bit | Tails Emby's log and pushes it to Loki (`job=emby`) | LaunchAgent `io.homelab.fluent-bit` | `fluent-bit/*` |
| mdns-reflector | Bonjour bridge VM <-> LAN for HomeKit, see `homekit-mdns.md` | LaunchAgent `io.homelab.mdns-reflector` | `mdns-reflector/*` |
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

## NFS mount (root daemon)

```bash
sudo cp host/macmini/launchd/com.kyiv.nfsmount.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system /Library/LaunchDaemons/com.kyiv.nfsmount.plist
sudo launchctl bootout system/com.kyiv.nfsmount      # to stop / unmount handling
```
