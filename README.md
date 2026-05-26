# hestia-goaccess

`hestia-goaccess` is a planned standalone HestiaCP add-on that adds GoAccess as a web statistics option for Hestia-hosted domains.

The goal is to give Hestia administrators a privacy-friendly alternative to AWStats, with both static report generation and realtime dashboards where the server layout can safely support them.

## Status

This project is in the research and skeleton phase. Do not install it on a production Hestia server yet.

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

## Planned Commands

```bash
hestia-goaccess install
hestia-goaccess enable USER DOMAIN --mode static
hestia-goaccess enable USER DOMAIN --mode realtime
hestia-goaccess disable USER DOMAIN
hestia-goaccess status
hestia-goaccess doctor
hestia-goaccess repair
hestia-goaccess migrate-awstats --all --mode static
hestia-goaccess uninstall
```

Realtime mode is planned as an explicit per-domain opt-in. Existing AWStats domains should only be migrated by an explicit administrator command, and the initial migration target should be static mode.

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
