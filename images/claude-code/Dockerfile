FROM node:24-bookworm-slim@sha256:06e5c9f86bfa0aaa7163cf37a5eaa8805f16b9acb48e3f85645b09d459fc2a9f

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl wget unzip ca-certificates git jq \
      ffmpeg mediainfo python3 ripgrep tree screen && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code@latest

# node:22 already has user "node" with UID 1000; rename to "claude"
RUN usermod -l claude -d /home/claude -m node && groupmod -n claude node
USER 1000

# Install bun as claude user
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/home/claude/.bun/bin:$PATH"
WORKDIR /home/claude

ENTRYPOINT ["claude"]
