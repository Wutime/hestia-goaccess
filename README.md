# hestia-goaccess

`hestia-goaccess` is a planned standalone HestiaCP add-on that adds GoAccess as a web statistics option for Hestia-hosted domains.

The goal is to give Hestia administrators a privacy-friendly alternative to AWStats, with both static report generation and realtime dashboards where the server layout can safely support them.

## Status

This project is in early prototype development. Do not install it on a production Hestia server yet.

Current target:

- HestiaCP 1.9.4+
- Debian 11/12 and Ubuntu 22.04/24.04 LTS, matching Hestia's supported platforms
- GoAccess 1.10.2+

## Planned Features

- Register GoAccess as a selectable Hestia web statistics engine.
- Offer separate per-domain choices for static and realtime GoAccess reports.
- Generate static GoAccess reports under Hestia's per-domain stats path.
- Run optional realtime GoAccess dashboards for selected domains.
- Protect dashboards using Hestia's existing statistics authorization where possible.
- Default to privacy-preserving output, with documented per-domain overrides.
- Detect unsupported server layouts before making changes.
- Make install, repair, and uninstall operations idempotent and reversible.

## Prototype Commands

The current installer prepares static GoAccess mode without patching Hestia core files:

```bash
sudo ./install.sh
```

To also make `goaccess-static` and `goaccess-realtime` appear in Hestia's per-domain Web Statistics dropdown:

```bash
sudo ./install.sh --with-hestia-dropdown
```

For unattended Docker/dev testing:

```bash
sudo ./install.sh --yes --with-hestia-dropdown
```

Installer behavior today:

- verifies HestiaCP `1.9.4+`
- verifies Debian 11/12 or Ubuntu 22.04/24.04
- verifies GoAccess `1.10.2+`
- offers to install GoAccess from the official GoAccess Debian/Ubuntu repository when GoAccess is missing
- stops with a clear error if an older GoAccess is already installed, unless `--upgrade-goaccess` is passed
- installs `hestia-goaccess` into `/usr/local/bin`
- creates `/etc/hestia-goaccess`
- leaves Hestia UI and core command files unchanged unless `--with-hestia-dropdown` is used
- with `--with-hestia-dropdown`, adds `goaccess-static` and `goaccess-realtime` to `STATS_SYSTEM`, installs Hestia stats templates, and wraps Hestia stats update/delete commands with backed-up fallbacks to Hestia's original commands

After install, the CLI can run a static GoAccess report for an existing Hestia domain:

```bash
hestia-goaccess doctor [USER DOMAIN]
hestia-goaccess enable USER DOMAIN --mode static
hestia-goaccess enable USER DOMAIN --mode realtime [--ws-url URL]
hestia-goaccess disable USER DOMAIN
hestia-goaccess status [USER DOMAIN]
```

Static mode writes:

```text
/home/USER/web/DOMAIN/stats/index.html
```

Hestia serves that report at the existing stats URL:

```text
http://DOMAIN/vstats/
```

Planned commands:

```bash
hestia-goaccess repair
hestia-goaccess migrate-awstats --all --mode static
hestia-goaccess uninstall
```

Realtime mode is an explicit per-domain opt-in. Existing AWStats domains should only be migrated by an explicit administrator command, and the initial migration target should be static mode.

For local Docker testing, the browser sees the Hestia vhost through port `20080`, so pass an explicit WebSocket URL:

```bash
docker compose exec hestia-vps hestia-goaccess enable demo example.test --mode realtime --ws-url ws://example.test:20080/vstats/ws/
```

If testing realtime through Hestia's dropdown in Docker, set the local WebSocket URL template first:

```bash
docker compose exec hestia-vps sed -i 's|^GOACCESS_REALTIME_WS_URL_TEMPLATE=.*|GOACCESS_REALTIME_WS_URL_TEMPLATE=ws://%domain%:20080/vstats/ws/|' /etc/hestia-goaccess/defaults.conf
```

Then open:

```text
http://example.test:20080/vstats/
```

Realtime mode currently:

- runs one systemd service per enabled domain
- binds GoAccess to `127.0.0.1`
- allocates a port from `64000-64999`
- installs a per-domain Nginx include for `/vstats/ws/`
- proxies the WebSocket through the same vhost
- ignores `/vstats/` by default so GoAccess does not count its own report traffic
- preselects GoAccess' shipped `darkGray` HTML theme by default
- records state in `/etc/hestia-goaccess/domains/USER/DOMAIN.conf`
- stops the realtime service and removes the Nginx include when Hestia switches the domain away from `goaccess-realtime`

Static and realtime modes both pre-filter logs before sending them to GoAccess. The default ignored path list is:

```text
/vstats/
```

Admins can override it through config or CLI:

```bash
hestia-goaccess enable USER DOMAIN --mode static --ignore-paths '/vstats/,/admin'
hestia-goaccess enable USER DOMAIN --mode realtime --ignore-paths '/vstats/,/admin'
```

This is intentionally designed so a future Hestia UI field can expose the same setting without changing the underlying behavior.

The default GoAccess HTML preferences are:

```bash
GOACCESS_HTML_PREFS='{"theme":"darkGray"}'
```

Admins can override that value in `/etc/hestia-goaccess/defaults.conf`; setting it to an empty value lets GoAccess use its upstream HTML theme behavior.

## Hestia Dropdown Integration

`goaccess-static` and `goaccess-realtime` appear in Hestia's Web Statistics dropdown only after the optional dropdown integration is installed:

```bash
sudo ./install.sh --with-hestia-dropdown
```

This integration currently:

- backs up Hestia files before changing them
- appends `goaccess-static` and `goaccess-realtime` to `/usr/local/hestia/conf/hestia.conf`
- installs `/usr/local/hestia/data/templates/web/goaccess-static/goaccess-static.tpl`
- installs `/usr/local/hestia/data/templates/web/goaccess-realtime/goaccess-realtime.tpl`
- wraps `/usr/local/hestia/bin/v-update-web-domain-stat`
- wraps `/usr/local/hestia/bin/v-delete-web-domain-stats`
- preserves Hestia's original updater at `/usr/local/hestia/bin/v-update-web-domain-stat.hestia-goaccess-original`
- preserves Hestia's original stats delete command at `/usr/local/hestia/bin/v-delete-web-domain-stats.hestia-goaccess-original`
- runs `hestia-goaccess enable USER DOMAIN --mode static` when a domain's `STATS` value is `goaccess-static`
- runs `hestia-goaccess enable USER DOMAIN --mode realtime` when a domain's `STATS` value is `goaccess-realtime`
- runs `hestia-goaccess disable USER DOMAIN` before falling back to Hestia's original updater/delete command for non-GoAccess stats

The visible dropdown values are `goaccess-static` and `goaccess-realtime` rather than labels with parentheses so v1 can avoid patching Hestia PHP UI label rendering.

## Docker Testing

Docker support is planned for development and evaluation, not as the first recommended production deployment. Hestia is a full server control panel and its installer expects a fresh server with root privileges, service management, web server ports, cron, and system paths.

The intended Docker setup is a test harness that can validate:

- installer idempotency
- Hestia file detection and patch checks
- static GoAccess report generation
- Nginx include rendering
- basic realtime WebSocket proxy behavior where the container can run the required services

Final production validation should still happen on a disposable VPS before installing on a live server.

Development smoke test:

```bash
docker compose up -d --build
docker compose exec dev scripts/dev-smoke.sh
```

Local report URL after `docker compose up -d --build`:

```text
http://goaccess.localhost:18080/vstats/
```

Experimental local Hestia profile:

```bash
docker compose --profile hestia up -d --build hestia-vps
docker compose exec hestia-vps scripts/hestia-vps-install.sh
```

Then open:

```text
https://panel.hestia-goaccess.localhost:8083/
```

The Hestia profile installs Hestia at runtime inside the container filesystem. Restarting the container preserves the installed panel, while recreating it gives you a fresh pretend VPS and requires rerunning the installer. Use the `panel.hestia-goaccess.localhost` hostname for the Hestia panel so Hestia's CSRF checks, cookies, and local certificate hostname all line up.

The Hestia Docker installer installs GoAccess from the official GoAccess Debian repository by default for local static report testing. Set `HESTIA_INSTALL_GOACCESS=no` when testing missing-dependency behavior.

The default development target should mirror the maintainer's production Hestia server where possible. Use `scripts/collect-hestia-inventory.sh` for read-only inventory before changing production systems.

## GoAccess Baseline

The installer should require GoAccess `1.10.2` or newer. If GoAccess is missing, install/doctor can offer to install it from GoAccess' official Debian/Ubuntu repository. If an older version is already installed, the safe default is to stop with a clear error and upgrade instructions unless the administrator explicitly asks the add-on to upgrade GoAccess.

## Security Direction

Statistics pages can expose sensitive traffic data. The add-on should not make dashboards public by default. Realtime mode must protect both the HTML report and the WebSocket endpoint, bind GoAccess listeners locally where possible, and avoid leaking raw query strings unless an administrator opts in.

Default privacy direction:

- anonymize IP addresses
- strip query strings
- allow documented per-domain overrides through the CLI and config files first

## License

GPL-3.0 is the preferred license for this project because HestiaCP is GPL-3.0 and this add-on integrates closely with Hestia.
