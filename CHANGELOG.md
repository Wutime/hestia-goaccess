# Changelog

## v1.0.1 - 2026-05-30

Maintenance release for HestiaCP package upgrades.

- Adds `hestia-goaccess repair` to reapply Hestia dropdown integration safely.
- Installs an APT post-invoke hook so future Debian/Ubuntu package updates automatically repair hestia-goaccess' Hestia command wrappers if Hestia replaces them during an upgrade.
- Refreshes preserved Hestia fallback commands when Hestia has installed newer command files, so non-GoAccess stats behavior falls through to the current Hestia version.
- Reconciles domains already set to `goaccess-static` or `goaccess-realtime` after integration repair, so reports and realtime services match the Hestia selector again.
- Documents the quickest upgrade path for existing `v1.0.0` installs affected by a recent Hestia upgrade.

## v1.0.0 - 2026-05-26

Initial public release.

- Adds `goaccess-static` and `goaccess-realtime` as Hestia web statistics choices.
- Integrates with Hestia's normal `/vstats/` report path.
- Supports static reports with persisted GoAccess history.
- Supports per-domain realtime dashboards through systemd and a local Nginx WebSocket proxy.
- Preserves GoAccess history when switching between `goaccess-static` and `goaccess-realtime`.
- Cleans up managed services, includes, reports, and persisted state when domains switch away from GoAccess or the add-on is uninstalled.
- Includes Docker/dev tooling for local Hestia testing.
