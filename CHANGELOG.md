# Changelog

## v1.0.0 - 2026-05-26

Initial public release.

- Adds `goaccess-static` and `goaccess-realtime` as Hestia web statistics choices.
- Integrates with Hestia's normal `/vstats/` report path.
- Supports static reports with persisted GoAccess history.
- Supports per-domain realtime dashboards through systemd and a local Nginx WebSocket proxy.
- Preserves GoAccess history when switching between `goaccess-static` and `goaccess-realtime`.
- Cleans up managed services, includes, reports, and persisted state when domains switch away from GoAccess or the add-on is uninstalled.
- Includes Docker/dev tooling for local Hestia testing.
