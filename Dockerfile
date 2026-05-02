# syntax=docker/dockerfile:1
###############################################################################
# Ubuntu Dev Container — Browser automation + dev essentials
###############################################################################
# Access:
#   noVNC  : http://localhost:6080/vnc.html
#   CDP    : ws://localhost:9222
#   VNC    : vnc://localhost:5900
###############################################################################

ARG BASE_IMAGE=ubuntu:26.04
FROM $BASE_IMAGE

LABEL org.opencontainers.image.title="Ubuntu Dev Container" \
      org.opencontainers.image.description="Dev container with browser automation, GH, Terraform, noVNC/CDP browser access" \
      org.opencontainers.image.source="https://github.com/phantomic12/dev-container" \
      org.opencontainers.image.licenses="MIT"

###############################################################################
# All system deps in one layer — avoids partial-layer cache issues
###############################################################################
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        curl wget git jq zip unzip tar gzip ca-certificates gnupg lsb-release \
        build-essential gcc g++ make cmake pkg-config \
        libssl-dev libffi-dev zlib1g-dev \
        python3 python3-pip python3-venv python3-dev python3-setuptools \
        openssh-client openssh-server \
        tmux htop tree ncdu lsof netcat-openbsd iputils-ping strace procps \
        parallel direnv sudo locales tzdata man-db less vim nano \
        xvfb x11vnc websockify \
        fonts-firacode fonts-jetbrains-mono fontconfig && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# Node.js from NodeSource
###############################################################################
ARG NODE_VERSION=20
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/*

###############################################################################
# Binary tools — version-pinned
###############################################################################

# GH
ARG GH_VERSION=2.63.0
RUN curl -fsSL https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.deb -o /tmp/gh.deb && \
    dpkg -i /tmp/gh.deb && rm /tmp/gh.deb

# Terraform
ARG TERRAFORM_VERSION=1.9.0
RUN curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o /tmp/terraform.zip && \
    unzip -q /tmp/terraform.zip -d /usr/local/bin/ && rm /tmp/terraform.zip

# ripgrep
ARG RIPGREP_VERSION=14.1.0
RUN curl -fsSL https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl.tar.gz -o /tmp/ripgrep.tar.gz && \
    tar -xzf /tmp/ripgrep.tar.gz -C /tmp && \
    mv /tmp/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl/rg /usr/local/bin/rg && \
    rm -rf /tmp/ripgrep.tar.gz /tmp/ripgrep-*

# fd
ARG FD_VERSION=9.0.0
RUN curl -fsSL https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-x86_64-unknown-linux-gnu.tar.gz -o /tmp/fd.tar.gz && \
    tar -xzf /tmp/fd.tar.gz -C /tmp && \
    mv /tmp/fd-v${FD_VERSION}-x86_64-unknown-linux-gnu/fd /usr/local/bin/fd && \
    rm -rf /tmp/fd.tar.gz /tmp/fd-*

# yq
ARG YQ_VERSION=4.44.2
RUN curl -fsSL https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# shellcheck
ARG SHELLCHECK_VERSION=0.10.0
RUN curl -fsSL https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz -o /tmp/shellcheck.tar.xz && \
    tar -xJf /tmp/shellcheck.tar.xz -C /tmp && \
    mv /tmp/shellcheck-v${SHELLCHECK_VERSION}/shellcheck /usr/local/bin/ && \
    rm -rf /tmp/shellcheck.tar.xz /tmp/shellcheck-*

# hadolint
ARG HADOLINT_VERSION=2.12.0
RUN curl -fsSL https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64 -o /usr/local/bin/hadolint && \
    chmod +x /usr/local/bin/hadolint

# tflint
ARG TFLINT_VERSION=0.52.0
RUN curl -fsSL https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip -o /tmp/tflint.zip && \
    unzip -q /tmp/tflint.zip -d /usr/local/bin/ && chmod +x /usr/local/bin/tflint && rm /tmp/tflint.zip

# yamllint
RUN pip3 install --break-system-packages yamllint

###############################################################################
# Language runtimes — Go
###############################################################################
ARG GO_VERSION=1.22.5
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz
ENV PATH=/usr/local/go/bin:$PATH

###############################################################################
# Language runtimes — Rust (via rustup)
###############################################################################
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
        --default-toolchain stable \
        --profile minimal \
        --no-modify-path \
        -y && \
    ln -sf /usr/local/cargo/bin/rustc /usr/local/bin/rustc && \
    ln -sf /usr/local/cargo/bin/cargo /usr/local/bin/cargo && \
    ln -sf /usr/local/cargo/bin/rustup /usr/local/bin/rustup

###############################################################################
# Language runtimes — Java (OpenJDK 21)
###############################################################################
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends openjdk-21-jdk maven gradle && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# Language runtimes — Ruby (via rbenv)
###############################################################################
ENV RBENV_ROOT=/usr/local/rbenv
ENV PATH=/usr/local/rbenv/bin:/usr/local/rbenv/shims:$PATH
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        build-essential libssl-dev libreadline-dev zlib1g-dev \
        libyaml-dev libffi-dev libgdbm-dev uuid-dev && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    git clone --depth 1 https://github.com/rbenv/rbenv.git $RBENV_ROOT && \
    git clone --depth 1 https://github.com/rbenv/ruby-build.git $RBENV_ROOT/plugins/ruby-build && \
    rbenv install 3.3.4 && rbenv global 3.3.4 && \
    gem update --system --no-document && \
    gem install bundler --no-document

###############################################################################
# Language runtimes — .NET 8
###############################################################################
ARG DOTNET_VERSION=8.0
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends wget && \
    wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O /tmp/msprod.deb && \
    dpkg -i /tmp/msprod.deb && rm /tmp/msprod.deb && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends dotnet-sdk-8.0 aspnetcore-runtime-8.0 && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# Language runtimes — PHP 8.3
###############################################################################
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        php8.3 php8.3-cli php8.3-dev php8.3-mbstring php8.3-xml php8.3-curl \
        php8.3-zip php8.3-sqlite3 php8.3-redis php8.3-bcmath php8.3-gd && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# Language runtimes — Elixir / Erlang
###############################################################################
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        erlang-base erlang-asn1 erlang-crypto erlang-public-key \
        erlang-ssl erlang-runtime-tools erlang-inets erlang-mnesia \
        elixir && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# Browser automation
###############################################################################
RUN npm install -g playwright@latest puppeteer@latest && \
    npx playwright install chromium --with-deps

RUN pip3 install --break-system-packages --ignore-installed typing_extensions && \
    pip3 install --break-system-packages \
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
                    eslint prettier dotenv-cli wrangler

###############################################################################
# noVNC
###############################################################################
RUN npm install -g @novnc/novnc && \
    mkdir -p /usr/share/novnc

###############################################################################
# Locale
###############################################################################
RUN locale-gen en_US.UTF-8

###############################################################################
# User setup
###############################################################################
ARG WANTED_UID=1000
ARG WANTED_GID=1000
ARG USERNAME=dev

RUN if getent passwd ${USERNAME} >/dev/null 2>&1; then \
        echo "User ${USERNAME} already exists"; \
    elif getent group ${WANTED_GID} >/dev/null 2>&1; then \
        echo "GID ${WANTED_GID} taken by '$(getent group ${WANTED_GID} | cut -d: -f1)' — creating ${USERNAME} with next available UID"; \
        useradd --gid ${WANTED_GID} --create-home --shell /bin/bash ${USERNAME}; \
    else \
        groupadd --gid ${WANTED_GID} ${USERNAME}; \
        useradd --uid ${WANTED_UID} --gid ${WANTED_GID} --create-home --shell /bin/bash ${USERNAME}; \
    fi && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME}; \
    mkdir -p /home/${USERNAME}/.config/gh; \
    chown -R $(id -u ${USERNAME}):$(getent group ${WANTED_GID} | cut -d: -f3) /home/${USERNAME}; \
    mkdir -p /workspace /browser-profile; \
    chown $(id -u ${USERNAME}):$(getent group ${WANTED_GID} | cut -d: -f3) /workspace /browser-profile

USER ${USERNAME}
WORKDIR /workspace

###############################################################################
# Entrypoint
###############################################################################
COPY --chmod=755 <<"ENTRYPOINT_SCRIPT" /entrypoint.sh
#!/bin/bash
set -euo pipefail

# ── GH auth ────────────────────────────────────────────────────────────────
if [[ -n "${GH_TOKEN:-}" ]]; then
    echo "[entrypoint] GH_TOKEN detected — authenticating gh CLI..."
    gh auth login --hostname github.com --token "$GH_TOKEN" 2>/dev/null || \
    gh auth status || true
elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "[entrypoint] GITHUB_TOKEN detected — authenticating gh CLI..."
    gh auth login --hostname github.com --token "$GITHUB_TOKEN" 2>/dev/null || \
    gh auth status || true
else
    echo "[entrypoint] No GH_TOKEN / GITHUB_TOKEN set — gh CLI not authenticated."
fi

# ── Cloudflare auth (Wrangler) ─────────────────────────────────────────────
if [[ -n "${CLOUDFLARE_API_KEY:-}" ]]; then
    echo "[entrypoint] CLOUDFLARE_API_KEY detected — configuring wrangler..."
    export CW_API_TOKEN="$CLOUDFLARE_API_KEY"
    npx wrangler login --api-token "$CLOUDFLARE_API_KEY" 2>/dev/null || \
    npx wrangler whoami 2>/dev/null || true
elif [[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
    echo "[entrypoint] CLOUDFLARE_ACCOUNT_ID set — wrangler configured (token required for deploys)"
else
    echo "[entrypoint] No CLOUDFLARE_API_KEY set — wrangler not authenticated."
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
