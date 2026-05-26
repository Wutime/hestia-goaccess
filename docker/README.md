# Docker Test Harness

Docker support is for development and customer evaluation before production rollout. It is not the recommended production deployment path for Hestia servers; production users should install the add-on on their actual Hestia VPS/server after reviewing the README and running `hestia-goaccess doctor`.

The initial Docker harness should validate installer behavior, Hestia path detection, GoAccess command rendering, static report generation, and Nginx include generation. It is not a replacement for VPS testing because Hestia depends on real service management, cron, web server reloads, and production-like networking.

## Quick Start

Build and start the development container:

```bash
docker compose up -d --build
```

The image copies the repository into `/workspace` at build time so it works even when Docker Desktop does not share the local checkout path. Rebuild after local source changes.

The container runs the smoke test and starts Nginx automatically. Open:

```text
http://goaccess.localhost:18080/vstats/
```

On most modern systems, `*.localhost` resolves to loopback automatically. If it does not, add this to your local `/etc/hosts`:

```text
127.0.0.1 goaccess.localhost
```

Run the smoke test manually:

```bash
docker compose exec dev scripts/dev-smoke.sh
```

The smoke test checks shell syntax, runs ShellCheck when available, and generates a static GoAccess report from a fixture Hestia-style Nginx access log.

The development image installs GoAccess from the official GoAccess Debian repository so the harness tracks the project baseline instead of the older package versions that may ship with Debian/Ubuntu.

Stop the container:

```bash
docker compose down
```

## Fixture Layout

The harness includes a minimal Hestia-like filesystem under `docker/fixtures/hestia/`:

- `etc/hestiacp/hestia.conf`
- `usr/local/hestia/data/templates/web/goaccess-static/goaccess-static.tpl`
- `usr/local/hestia/data/templates/web/goaccess-realtime/goaccess-realtime.tpl`
- `home/admin/web/example.test/stats/`
- `var/log/nginx/domains/example.test.log`

This is intentionally not a full Hestia install. It gives us fast tests for the add-on logic before we spend time on a heavier container that boots Hestia services.

## Production-Matched Profile

For this project, the primary development target should mirror the maintainer's production Hestia server as closely as practical. Start by collecting a read-only inventory from the server:

```bash
scripts/collect-hestia-inventory.sh USER DOMAIN
```

Or over SSH:

```bash
ssh root@SERVER 'bash -s' < scripts/collect-hestia-inventory.sh USER DOMAIN
```

The inventory should be saved outside public commits if it contains domain names, IPs, usernames, or process details that should remain private. Use it to tune:

- base distribution and version
- Hestia version
- Nginx / Apache / PHP-FPM layout
- GoAccess package version
- Hestia template paths
- ephemeral port range
- current listening ports
- representative domain stats/auth settings

## Hestia VPS Profile

The `hestia-vps` Compose profile is an experimental pretend-VPS container. It uses Ubuntu 22.04 with systemd and attempts to install real Hestia with Nginx + Apache, matching the maintainer production shape more closely than the fast fixture.

This is the customer-facing Docker evaluation path: it creates a disposable local Hestia-like server so administrators can inspect the installer, dropdown integration, static reports, realtime reports, and uninstall behavior without spending money on a VPS. It includes Docker-specific concessions such as privileged mode, host cgroup mounting, localhost port mappings, and a local WebSocket URL override; those are not production requirements.

Start the container:

```bash
docker compose --profile hestia up -d --build hestia-vps
```

Install Hestia inside it:

```bash
docker compose exec hestia-vps scripts/hestia-vps-install.sh
```

The installer also installs GoAccess from the official GoAccess Debian repository by default, so the pretend VPS is ready for static report tests. Set `HESTIA_INSTALL_GOACCESS=no` to keep the container in a missing-GoAccess state for dependency checks.

Panel URL:

```text
https://panel.hestia-goaccess.localhost:8083/
```

Development login:

```text
admin
admin
```

This profile is intentionally separate from the fast `dev` service. It may expose Docker Desktop/systemd limitations; if it does, use the failure to decide whether local Docker is sufficient or a disposable VPS is needed for the next level of testing.

Hestia is installed at runtime inside the container filesystem. Restarting the container preserves the installed panel:

```bash
docker compose --profile hestia restart hestia-vps
```

Recreating the container gives you a fresh pretend VPS and requires rerunning `scripts/hestia-vps-install.sh`.

On Apple Silicon, this profile uses the native Docker architecture unless Docker Desktop is configured for amd64 emulation. The maintainer production server is x86_64, so a disposable VPS remains the final parity target.

Add the Hestia hostname to local `/etc/hosts`:

```text
127.0.0.1 hestia-goaccess.localhost
127.0.0.1 panel.hestia-goaccess.localhost
```

The container's internal Hestia hostname is `panel.hestia-goaccess.localhost` because the Hestia installer requires a hostname with at least two dots. Use `panel.hestia-goaccess.localhost` for the Hestia panel so Hestia's CSRF checks, cookies, and local certificate hostname all line up.
