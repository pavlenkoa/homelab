FROM node:24-bookworm-slim@sha256:b506e7321f176aae77317f99d67a24b272c1f09f1d10f1761f2773447d8da26c

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
