# hestia-goaccess

`hestia-goaccess` is a standalone HestiaCP add-on that adds GoAccess as a web statistics option for Hestia-hosted domains.

The goal is to give Hestia administrators a privacy-friendly alternative to AWStats, with both static report generation and realtime dashboards where the server layout can safely support them.

## Status

This project has passed local Docker testing against a fresh Hestia `1.9.4` install and is ready for live-server validation.

For the first live install, use one domain first and keep the rollback commands below nearby.

Current target:

- HestiaCP 1.9.4+
- Debian 11/12 and Ubuntu 22.04/24.04 LTS, matching Hestia's supported platforms
- GoAccess 1.10.2+

## Live Install Quick Start

Run these commands as `root` on a Hestia server.

Clone the project:

```bash
cd /root
git clone https://github.com/Wutime/hestia-goaccess.git
cd hestia-goaccess
```

Install with Hestia dropdown integration:

```bash
./install.sh --with-hestia-dropdown
```

For a non-interactive install:

```bash
./install.sh --yes --with-hestia-dropdown
```

The installer will:

- verify HestiaCP `1.9.4+`
- verify Debian 11/12 or Ubuntu 22.04/24.04
- verify GoAccess `1.10.2+`
- offer to install GoAccess from the official GoAccess Debian/Ubuntu repository if it is missing
- stop with a clear error if an older GoAccess is already installed unless `--upgrade-goaccess` is passed
- back up wrapped Hestia files before changing them

Check one domain before enabling reports:

```bash
hestia-goaccess doctor USER DOMAIN
```

To test static mode:

```bash
/usr/local/hestia/bin/v-change-web-domain-stats USER DOMAIN goaccess-static
hestia-goaccess doctor USER DOMAIN
```

Open:

```text
http://DOMAIN/vstats/
```

To test realtime mode:

```bash
/usr/local/hestia/bin/v-change-web-domain-stats USER DOMAIN goaccess-realtime
hestia-goaccess status USER DOMAIN
```

Open:

```text
http://DOMAIN/vstats/
```

To return the domain to AWStats:

```bash
/usr/local/hestia/bin/v-change-web-domain-stats USER DOMAIN awstats
```

To disable stats for the domain:

```bash
/usr/local/hestia/bin/v-delete-web-domain-stats USER DOMAIN
```

To uninstall the add-on and remove dropdown integration:

```bash
/usr/local/share/hestia-goaccess/uninstall.sh --remove-hestia-dropdown --remove-state
```

The uninstall command leaves the system `goaccess` package and generated report files in place. Remove those manually only if you are sure nothing else uses them.

## Supported OS And GoAccess Install Policy

HestiaCP `1.9.4` supports 64-bit Debian 11/12 and Ubuntu 22.04/24.04. `hestia-goaccess` mirrors that OS matrix for v1 and exits on other operating systems instead of guessing.

GoAccess documents install methods for many platforms, including Fedora, Arch, Gentoo, Homebrew/macOS, and BSD package managers. Those are out of scope for this add-on unless Hestia supports those platforms.

For Debian/Ubuntu Hestia servers, the installer uses GoAccess' official Debian/Ubuntu repository when GoAccess is missing or when an administrator explicitly permits an upgrade. This is intentional because distro packages may lag behind the `GOACCESS_MIN_VERSION` baseline.

## Features

- Register GoAccess as a selectable Hestia web statistics engine.
- Offer separate per-domain choices for static and realtime GoAccess reports.
- Generate static GoAccess reports under Hestia's per-domain stats path.
- Run optional realtime GoAccess dashboards for selected domains.
- Works with Hestia's existing statistics URL and authorization model.
- Default to privacy-preserving output, with documented per-domain overrides.
- Detect unsupported server layouts before making changes.
- Make install, repair, and uninstall operations idempotent and reversible.

## Command Reference

The installer prepares GoAccess CLI/static report support without changing Hestia's stats dropdown:

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

Installer behavior:

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
hestia-goaccess terminal [USER] DOMAIN
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
```

Realtime mode is an explicit per-domain opt-in. Existing AWStats domains should only be migrated by an explicit administrator command, and the initial migration target should be static mode.

To uninstall the add-on while also removing Hestia dropdown integration and add-on state:

```bash
sudo /usr/local/share/hestia-goaccess/uninstall.sh --remove-hestia-dropdown --remove-state
```

That uninstall path:

- disables GoAccess stats on domains currently using `goaccess-static` or `goaccess-realtime`
- stops/disables per-domain realtime systemd services
- removes per-domain realtime Nginx includes
- restores wrapped Hestia stats commands
- removes `goaccess-static` and `goaccess-realtime` from `STATS_SYSTEM`
- removes add-on state/config and per-domain runtime directories
- leaves generated report files in place unless the administrator removes them separately
- does not remove the system `goaccess` package

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

For nicer local traffic tests, seed the Docker Hestia domain with mock pages:

```bash
docker compose cp scripts/install-hestia-mock-site.sh hestia-vps:/workspace/scripts/install-hestia-mock-site.sh
docker compose exec hestia-vps bash /workspace/scripts/install-hestia-mock-site.sh demo example.test
```

This creates pages such as `/pricing/`, `/product/tour/`, `/docs/start/`, and `/blog/post-1` through `/blog/post-20` so simulated traffic produces useful `200` responses instead of mostly `404`s.

Realtime mode:

- runs one systemd service per enabled domain
- binds GoAccess to `127.0.0.1`
- allocates a port from `64000-64999`
- installs a per-domain Nginx include for `/vstats/ws/`
- proxies the WebSocket through the same vhost
- ignores `/vstats/` by default so GoAccess does not count its own report traffic
- preselects GoAccess' shipped `darkGray` HTML theme by default
- uses a bounded systemd stop timeout so re-enable and uninstall do not hang on stale realtime processes
- records state in `/etc/hestia-goaccess/domains/USER/DOMAIN.conf`
- stops the realtime service and removes the Nginx include when Hestia switches the domain away from `goaccess-realtime`

## SSH Terminal Dashboard

GoAccess also includes an interactive terminal dashboard. The [GoAccess features page](https://goaccess.io/features) notes that terminal output updates more frequently than HTML output, and that GoAccess can run directly against an access log with a selected log format.

This terminal dashboard is separate from the `/vstats/` HTML report. Enabling `goaccess-realtime` does not attach a shell UI automatically, but `hestia-goaccess` can resolve the Hestia user, domain log path, ignored paths, and log format for you.

As `root`, an administrator can open a live terminal dashboard for any Hestia domain with:

```bash
hestia-goaccess terminal USER DOMAIN
```

The admin shortcut is equivalent:

```bash
hestia-goaccess USER DOMAIN
```

For a domain owner logged in over SSH as their Hestia user, the single-domain shortcut is:

```bash
hestia-goaccess DOMAIN
```

These commands use the same parser defaults as the managed reports: `/vstats/` filtering, `COMBINED` log format, anonymized IPs, no query strings, and crawler ignoring. If the domain has already been enabled by `hestia-goaccess`, the terminal command also reuses that domain's recorded ignored paths and log format.

If the domain user's SSH account cannot read the access log, use the `root` form above or ask the server administrator to confirm domain log permissions. Hestia layouts may use `/var/log/apache2/domains/DOMAIN.log` or `/var/log/nginx/domains/DOMAIN.log`; `hestia-goaccess doctor USER DOMAIN` checks the log path used by the add-on.

Static and realtime modes both pre-filter logs before sending them to GoAccess. The default ignored path list is:

```text
/vstats/
```

Admins can override it through config or CLI:

```bash
hestia-goaccess enable USER DOMAIN --mode static --ignore-paths '/vstats/,/admin'
hestia-goaccess enable USER DOMAIN --mode realtime --ignore-paths '/vstats/,/admin'
```

This is designed so a future Hestia UI field can expose the same setting without changing the underlying behavior.

## Configuration Defaults

Configuration is intentionally simple. The defaults are meant to be production-friendly for most customers:

- global smart defaults live in `/etc/hestia-goaccess/defaults.conf`
- per-domain choices are recorded in `/etc/hestia-goaccess/domains/USER/DOMAIN.conf`
- the Hestia domain page exposes the stats engine choice first
- advanced per-domain controls are CLI/config-file driven unless a future Hestia UI patch stays small and reversible

Realtime defaults favor low overhead on shared production servers:

- filter `/vstats/` so GoAccess does not count its own dashboard
- ignore common crawlers where GoAccess can do so safely
- avoid query strings and anonymize visitor IPs by default
- avoid expensive DNS/GeoIP behavior unless the administrator enables it
- defer GoAccess `--persist` / `--restore` for realtime until it is proven stable across supported server targets

Per-domain CLI/config overrides cover the important controls today. A future Hestia UI textarea can expose selected options, especially ignored paths for realtime domains.

Common adjustments administrators may consider:

- `GOACCESS_IGNORE_PATHS`: add private app paths that should not appear in reports, such as `/admin` or `/checkout`.
- `GOACCESS_HTML_PREFS`: change or clear the default `darkGray` HTML theme.
- `GOACCESS_PORT_RANGE`: move realtime listeners to a different local-only port range if `64000-64999` conflicts with local policy.
- `GOACCESS_LOG_FORMAT`: change only if the server intentionally customized Hestia's access log format.

The default settings are usually best. Change per-domain settings only when there is a clear reason, then run `hestia-goaccess doctor USER DOMAIN` before enabling or re-enabling that domain.

The default GoAccess HTML preferences are:

```bash
GOACCESS_HTML_PREFS='{"theme":"darkGray"}'
```

Admins can override that value in `/etc/hestia-goaccess/defaults.conf`; setting it to an empty value lets GoAccess use its upstream HTML theme behavior.

GoAccess reads Hestia's existing per-domain access log without changing Hestia's web-server logging configuration. The default parser setting is:

```bash
GOACCESS_LOG_FORMAT=COMBINED
```

That matches Hestia's default Apache and Nginx `combined` domain logs and keeps AWStats rollback safe. `hestia-goaccess doctor USER DOMAIN` validates that the selected access log parses with the configured GoAccess format before enabling reports. If an administrator intentionally customizes Hestia log formats, they can override `GOACCESS_LOG_FORMAT` in `/etc/hestia-goaccess/defaults.conf`.

## Hestia Dropdown Integration

`goaccess-static` and `goaccess-realtime` appear in Hestia's Web Statistics dropdown only after the optional dropdown integration is installed:

```bash
sudo ./install.sh --with-hestia-dropdown
```

This integration:

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

Docker support is for development and evaluation, not production deployment. Hestia is a full server control panel and its installer expects a fresh server with root privileges, service management, web server ports, cron, and system paths.

The Docker setup is a test harness that can validate:

- installer idempotency
- Hestia file detection and patch checks
- static GoAccess report generation
- Nginx include rendering
- basic realtime WebSocket proxy behavior where the container can run the required services

Final release validation will include a disposable VPS pass after the first live-server validation.

Development smoke test:

```bash
docker compose up -d --build
docker compose exec dev scripts/dev-smoke.sh
```

Local report URL after `docker compose up -d --build`:

```text
http://goaccess.localhost:18080/vstats/
```

Local Hestia profile:

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

The installer requires GoAccess `1.10.2` or newer. If GoAccess is missing, the installer can install it from GoAccess' official Debian/Ubuntu repository. If an older version is already installed, the installer stops with a clear error and upgrade instructions unless the administrator explicitly asks the add-on to upgrade GoAccess.

## Security Direction

Statistics pages can expose sensitive traffic data. The add-on should not make dashboards public by default. Realtime mode must protect both the HTML report and the WebSocket endpoint, bind GoAccess listeners locally where possible, and avoid leaking raw query strings unless an administrator opts in.

Default privacy direction:

- anonymize IP addresses
- strip query strings
- allow documented per-domain overrides through the CLI and config files first

## License

GPL-3.0 is the preferred license for this project because HestiaCP is GPL-3.0 and this add-on integrates closely with Hestia.
