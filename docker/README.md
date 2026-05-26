# Docker Test Harness

Docker support is planned for development and customer evaluation before production rollout.

The initial Docker harness should validate installer behavior, Hestia path detection, GoAccess command rendering, static report generation, and Nginx include generation. It is not a replacement for VPS testing because Hestia depends on real service management, cron, web server reloads, and production-like networking.

## Quick Start

Build and start the development container:

```bash
docker compose up -d --build
```

The image copies the repository into `/workspace` at build time so it works even when Docker Desktop does not share the local checkout path. Rebuild after local source changes.

The container runs the smoke test and starts Nginx automatically. Open:

```text
http://hestia-goaccess.localhost:18080/vstats/
```

On most modern systems, `*.localhost` resolves to loopback automatically. If it does not, add this to your local `/etc/hosts`:

```text
127.0.0.1 hestia-goaccess.localhost
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
