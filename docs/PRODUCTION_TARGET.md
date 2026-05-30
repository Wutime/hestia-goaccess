# Maintainer Production Target

This document intentionally avoids hostnames, public IPs, private usernames, and private domain names. It captures the maintainer's production server shape used for the first live validation pass.

Inventory date: 2026-05-26

## Platform

- Ubuntu 22.04.5 LTS
- Linux 5.15
- x86_64
- HestiaCP installed under `/usr/local/hestia`

Local Docker note: the maintainer machine currently cannot run `linux/amd64` containers under Docker Desktop (`exec format error`). The local Hestia pretend-VPS profile therefore runs on the host Docker architecture, while production parity for x86_64 still requires either enabling amd64 emulation or using a disposable VPS. Hestia's installer requires a hostname with at least two dots, so the local profile uses internal hostname and browser panel URL `https://panel.hestia-goaccess.localhost:8083/`.

## Web Stack

- Nginx public frontend is active
- Apache is active as a backend
- Hestia panel listens on `8083`
- Example domains were used to validate `goaccess-static` and `goaccess-realtime`
- Example domain uses a custom proxy template
- GoAccess was installed from the official GoAccess Debian/Ubuntu repository during validation

Observed versions:

- Nginx `1.31.0`
- Apache `2.4.67`

## Ports

Observed Linux ephemeral range:

```text
32768 60999
```

The default GoAccess realtime range `64000-64999` does not overlap this host's ephemeral range and is suitable for the first production target, subject to installer checks for existing listeners.

## Hestia Stats

Initial Hestia web stats list:

```text
none
awstats
```

The add-on install flow added:

```text
goaccess-static
goaccess-realtime
```

## Hestia Services Page

The Hestia server services page is for core server daemons such as web, mail, DNS, database, and related system services. The add-on should not try to add every per-domain GoAccess realtime unit to this page for v1.

Preferred v1 behavior:

- expose add-on status through `hestia-goaccess status`
- manage per-domain realtime units through systemd and the add-on CLI
- avoid cluttering Hestia's global services UI with one entry per domain
- consider one aggregate `hestia-goaccess` service or target later only if it provides clear operational value

## Validation Notes

- Installer completed on Ubuntu 22.04.5 / Hestia 1.9.4.
- Missing GoAccess was installed as GoAccess 1.10.2 from the official GoAccess repository.
- Hestia dropdown integration registered `goaccess-static` and `goaccess-realtime`.
- Realtime mode worked with per-domain systemd services, local Nginx WebSocket proxying, and `/vstats/`.
- Switching `goaccess-static <> goaccess-realtime` preserved the per-domain database under `/var/lib/hestia-goaccess/USER/DOMAIN`.
- `GOACCESS_DISABLE_STATS_ACCESS_LOG=yes` kept new `/vstats/` and `/vstats/ws/` requests out of the domain access log.
- Hestia 1.9.6 package upgrade validation found that Hestia can replace wrapped commands under `/usr/local/hestia/bin` while leaving `STATS_SYSTEM` and per-domain `STATS` values intact. The add-on now installs an APT post-invoke repair hook and `hestia-goaccess repair` to refresh wrappers and reconcile GoAccess domains after package upgrades.
- Static-to-realtime switching can appear stale if a browser or proxy reuses the old generated `/vstats/` HTML. The add-on now writes a managed no-cache stats include so normal refresh/revisit behavior loads the current report and WebSocket configuration.
