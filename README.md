# Ubuntu Dev Container

A lean, browser-automated Ubuntu dev environment with:

- **noVNC** — access the browser UI from any browser (`http://localhost:6080/vnc.html`)
- **Chrome DevTools Protocol (CDP)** — programmatic Playwright/Puppeteer control (`ws://localhost:9222`)
- **VNC** — connect with any desktop VNC client (`vnc://localhost:5900`)
- **Persistent browser profile** — log in once, sessions survive container rebuilds
- **GH CLI** — authenticated via `GH_TOKEN` env var
- **Terraform** — version-pinned

## Quick Start

```bash
cp .env.example .env
# Edit .env — at minimum set TAILSCALE_AUTH_KEY (or leave empty)

docker compose up -d
docker compose exec dev-container bash
```

## Browser Access

```bash
# noVNC — open in your browser
open http://localhost:6080/vnc.html

# CDP — programmatic control (Playwright example)
ws://localhost:9222

# VNC — desktop client
vnc://localhost:5900
```

### Logging into Sites

1. Start the container and browser:
   ```bash
   docker compose up -d dev
   docker compose exec dev-container bash scripts/start-browser.sh
   ```
2. Open http://localhost:6080/vnc.html
3. Navigate to any site and log in normally
4. Sessions persist at `./browser-profile/` — no re-login needed after rebuild

## GH Token (multi-user)

```bash
# Runtime
docker compose run -e GH_TOKEN=ghp_xxx dev gh auth status

# Or in .env
GH_TOKEN=ghp_xxx
```

The `GH_TOKEN` env var is authed automatically at container start via `gh auth login`.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GH_TOKEN` | — | GH personal access token (multi-user) |
| `GITHUB_TOKEN` | — | Fallback GH token |
| `TAILSCALE_AUTH_KEY` | — | Tailscale auth key |
| `BROWSER_PROFILE_DIR` | `./browser-profile` | Persistent browser session dir |
| `BROWSER_RESOLUTION` | `1920x1080` | Virtual display resolution |
| `CDP_PORT` | `9222` | Chrome DevTools Protocol port |
| `VNC_PORT` | `5900` | VNC server port |
| `NOVNC_PORT` | `6080` | noVNC web UI port |

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/start-browser.sh` | Start Xvfb + Chrome + x11vnc + noVNC |

## Building

```bash
# Local build
docker compose build

# Image is tagged as:
#   dev-container:latest (local)
#   ghcr.io/<user>/dev-container:<sha> (GitHub Container Registry)
```

## GitHub Actions

Pushes to `main`/`master` and PRs trigger:
1. Docker image build
2. Smoke-test: verify all binaries resolve (`gh`, `terraform`, `google-chrome`, `chromium-browser`, `playwright`, `puppeteer`)
3. GH auth status check (only if `GH_TOKEN` secret is set)
