#!/bin/bash
# Launcher for the io.homelab.fluent-bit LaunchAgent: loads credentials, then execs fluent-bit.
set -a
. "$HOME/.config/fluent-bit/loki.env"
set +a
exec /opt/homebrew/opt/fluent-bit/bin/fluent-bit -c "$HOME/.config/fluent-bit/fluent-bit.conf"
