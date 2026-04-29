# syntax=docker/dockerfile:1
###############################################################################
# Ubuntu Dev Container — Browser automation + dev essentials
###############################################################################
# Access:
#   noVNC  : http://localhost:6080/vnc.html       (browser VNC)
#   CDP    : ws://localhost:9222                  (Playwright/Puppeteer)
#   VNC    : vnc://localhost:5900                 (desktop VNC client)
###############################################################################

ARG BASE_IMAGE=ubuntu:26.04
FROM $BASE_IMAGE

LABEL org.opencontainers.image.title="Ubuntu Dev Container" \
      org.opencontainers.image.description="Dev container with browser automation, GH, Terraform, noVNC/CDP browser access" \
      org.opencontainers.image.source="https://github.com/phantomic12/dev-container" \
      org.opencontainers.image.licenses="MIT"

###############################################################################
# Install system dependencies
###############################################################################
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Base utilities
        curl wget git jq ripgrep fd-find fzf zip unzip tar gzip \
        ca-certificates gnupg lsb-release \
        # Build tools
        build-essential gcc g++ make cmake pkg-config \
        libssl-dev libffi-dev zlib1g-dev \
        # Python + Node
        python3 python3-pip python3-venv python3-dev python3-setuptools \
        nodejs npm \
        # SSH + Tailscale
        openssh-client openssh-server \
        # Process / system monitoring
        tmux htop tree ncdu lsof netcat ping strace procps \
        # Dev utilities
        shellcheck shfmt yamllint hadolint tflint parallel yq direnv \
        sudo locales tzdata man-db less vim nano \
        # ── Browser stack ────────────────────────────────────────────────
        xvfb x11vnc websockify \
        fonts-firacode fonts-jetbrains-mono fontconfig \
        # Cleanup
        && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# GH (GitHub CLI) — version-pinned for reproducibility
###############################################################################
ARG GH_VERSION=2.63.0
RUN curl -fsSL https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_linux_amd64.deb -o /tmp/gh.deb && \
    dpkg -i /tmp/gh.deb && rm /tmp/gh.deb

###############################################################################
# Terraform — version-pinned
###############################################################################
ARG TERRAFORM_VERSION=1.9.0
RUN curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o /tmp/terraform.zip && \
    unzip -q /tmp/terraform.zip -d /usr/local/bin/ && rm /tmp/terraform.zip

###############################################################################
# Browser automation — Playwright + Puppeteer
###############################################################################
RUN npm install -g playwright@latest puppeteer@latest && \
    npx playwright install chromium --with-deps

# Python browser packages
RUN pip3 install --break-system-packages \
        playwright pyppeteer selenium webdriver-manager

###############################################################################
# Python global packages
###############################################################################
RUN pip3 install --break-system-packages \
        pipx virtualenv poetry pipenv pdm

###############################################################################
# Node global packages
###############################################################################
RUN npm install -g pnpm yarn n typescript ts-node ts-node-dev \
                    eslint prettier dotenv-cli

###############################################################################
# noVNC (web-based VNC — serves the browser UI over HTTP/WebSocket)
###############################################################################
RUN npm install -g @novnc/novnc && \
    mkdir -p /usr/share/novnc

###############################################################################
# Locale
###############################################################################
RUN locale-gen en_US.UTF-8

###############################################################################
# User setup — UID/GID overridden at build via docker-compose args
###############################################################################
ARG WANTED_UID=1000
ARG WANTED_GID=1000
ARG USERNAME=dev

RUN groupadd --gid ${WANTED_GID} ${USERNAME} && \
    useradd --uid ${WANTED_UID} --gid ${WANTED_GID} \
            --create-home --shell /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \
    usermod -aG sudo ${USERNAME} && \
    mkdir -p /workspace /browser-profile && \
    chown ${USERNAME}:${USERNAME} /workspace /browser-profile

USER ${USERNAME}
WORKDIR /workspace

###############################################################################
# Entrypoint — Tailscale + SSH + GH auth + startup message
###############################################################################
COPY --chmod=755 <<"ENTRYPOINT_SCRIPT" /entrypoint.sh
#!/bin/bash
set -euo pipefail

# ── GH auth (multi-user token) ─────────────────────────────────────────────
# Set GH_TOKEN at runtime to auth the CLI without interactive login:
#   docker compose run -e GH_TOKEN=ghp_xxx dev gh auth status
if [[ -n "${GH_TOKEN:-}" ]]; then
    echo "[entrypoint] GH_TOKEN detected — authenticating gh CLI..."
    gh auth login --hostname github.com --token "$GH_TOKEN" 2>/dev/null || \
    gh auth status || true
elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "[entrypoint] GITHUB_TOKEN detected — authenticating gh cli..."
    gh auth login --hostname github.com --token "$GITHUB_TOKEN" 2>/dev/null || \
    gh auth status || true
else
    echo "[entrypoint] No GH_TOKEN / GITHUB_TOKEN set — gh CLI not authenticated."
fi

# ── Tailscale ────────────────────────────────────────────────────────────────
if [[ -n "${TAILSCALE_AUTH_KEY:-}" ]]; then
    echo "[entrypoint] Configuring Tailscale..."
    if ! command -v tailscale &> /dev/null; then
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    tailscale up \
        --authkey="${TAILSCALE_AUTH_KEY}" \
        --hostname="${TAILSCALE_HOSTNAME:-dev-container}" \
        --accept-routes \
        --accept-dns=false
    echo "[entrypoint] Tailscale connected. IP: $(tailscale ip -4 2>/dev/null || echo 'N/A')"
else
    echo "[entrypoint] TAILSCALE_AUTH_KEY not set — skipping Tailscale."
fi

# ── SSH ──────────────────────────────────────────────────────────────────────
if [[ -f ~/.ssh/authorized_keys ]] || [[ -n "${SSH_AUTHORIZED_KEYS:-}" ]]; then
    echo "[entrypoint] SSH keys detected — starting sshd..."
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    if [[ -n "${SSH_AUTHORIZED_KEYS:-}" ]]; then
        echo "${SSH_AUTHORIZED_KEYS}" > ~/.ssh/authorized_keys
    fi
    chmod 600 ~/.ssh/authorized_keys
    /usr/sbin/sshd
else
    echo "[entrypoint] No SSH keys found — sshd not started."
fi

# ── Browser profile dir ───────────────────────────────────────────────────────
mkdir -p /browser-profile

# ── Greeting ─────────────────────────────────────────────────────────────────
cat << 'EOF'
═══════════════════════════════════════════════════════════
  Ubuntu Dev Container
  ─────────────────────────────────────────────────────────
  noVNC  : http://localhost:6080/vnc.html
  CDP    : ws://localhost:9222
  VNC    : vnc://localhost:5900
  Browser: /browser-profile (persistent)
  GH auth: $(gh auth status 2>&1 | head -1 || echo "not authenticated")
  Tailscale: $(tailscale status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('BackendState','offline'))" 2>/dev/null || echo "offline")
═══════════════════════════════════════════════════════════
EOF

exec "$@"
ENTRYPOINT_SCRIPT

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash", "-l"]
