# Architecture Notes

These notes capture the initial HestiaCP and GoAccess integration decisions before implementation.

## Terminology

Use **add-on** for the public project terminology. Hestia does not expose a stable general plugin API for replacing the web statistics engine, so calling this a plugin can imply stronger first-party extension support than exists.

Acceptable wording:

- HestiaCP add-on
- GoAccess statistics engine for HestiaCP
- optional Hestia web UI integration

Avoid promising a native Hestia plugin unless Hestia adds or documents a stable plugin mechanism that covers this use case.

## Hestia Stats Model

Hestia already has a web statistics model:

- `STATS_SYSTEM` lists selectable stats engines.
- `v-list-web-stats` returns `none` plus the configured `STATS_SYSTEM` values.
- `v-add-web-domain-stats USER DOMAIN TYPE` validates `TYPE` against `STATS_SYSTEM`, renders `$WEBTPL/$type/$type.tpl`, stores `$HOME/USER/conf/web/DOMAIN/TYPE.conf`, updates the domain `STATS` value, and calls `v-update-web-domain-stat`.
- `v-change-web-domain-stats` follows the same template-rendering pattern.
- `v-delete-web-domain-stats` removes the stats output directory and engine config, then clears the domain `STATS` value.
- `v-update-web-domain-stat` currently dispatches only `awstats`.
- `v-add-web-domain-stats-user` and `v-delete-web-domain-stats-user` manage Hestia's statistics authorization.

Implication: registering `goaccess` in `STATS_SYSTEM` is necessary but not sufficient. The add-on must also provide GoAccess-specific update behavior and a reversible way to hook or wrap Hestia's update flow.

## Hestia Selector Values

The intended per-domain Hestia web statistics selector should expose separate GoAccess modes:

```text
awstats
goaccess-static
goaccess-realtime
```

These values are readable enough for v1 and avoid patching Hestia's PHP UI only to prettify labels. This gives administrators domain-by-domain flexibility from Hestia's existing Edit Web Domain page while keeping realtime an explicit opt-in choice.

## URL And Output Path

Hestia's existing web statistics URL is:

```text
/vstats/
```

Hestia writes stats output under:

```text
/home/USER/web/DOMAIN/stats/
```

The add-on should preserve this URL and output path so users do not need to learn a second access pattern.

## Static Mode

Static mode should be the safest initial mode:

- no long-running per-domain process
- no WebSocket listener
- compatible with Hestia's queued `webstats` update model
- output written to `/home/USER/web/DOMAIN/stats/index.html`

Static mode should support Nginx-only and Nginx-plus-Apache Hestia layouts first. Apache-only behavior should be detected and documented if not supported in the first implementation.

Static mode is also the initial migration target for existing AWStats domains. Any bulk migration command should require an explicit admin action, such as `hestia-goaccess migrate-awstats --all --mode static`, and should not silently convert domains during install.

## Realtime Mode

Realtime mode should use one GoAccess process per enabled domain, managed by systemd on real servers.

Recommended defaults:

- bind the GoAccess WebSocket listener to `127.0.0.1`
- use a deterministic unique local port per realtime domain
- write the HTML report to Hestia's stats directory
- set `--ws-url` to the public `/vstats/` WebSocket route
- use `--persist`, `--restore`, and a per-domain `--db-path`
- apply systemd resource controls such as `Nice=10`, `MemoryMax`, restart limits, and private temp

Realtime mode must protect the HTML report and the WebSocket endpoint consistently.

Realtime mode does not require Apache. It requires GoAccess realtime HTML output plus a reachable WebSocket endpoint. On Hestia servers, Nginx-backed layouts are the preferred first target because Nginx is well suited to proxying the GoAccess WebSocket listener and Hestia already provides per-domain Nginx include points.

Each realtime-enabled domain should have its own GoAccess process and its own localhost listener. Domains should not share a single GoAccess listener unless the design intentionally creates one combined report, which would break per-domain and per-user isolation.

Recommended v1 shape:

- `USER/example.com` gets a service such as `hestia-goaccess@USER--example.com.service`.
- The service reads only that domain's access log.
- The service writes only `/home/USER/web/example.com/stats/index.html`.
- The service listens on a unique localhost port such as `127.0.0.1:PORT`.
- The domain's Nginx include proxies only that domain's realtime WebSocket path to that port.
- Hestia stats auth protects both `/vstats/` and the realtime WebSocket location.

Port allocation should be deterministic and tracked in add-on state, for example under `/etc/hestia-goaccess/domains/USER/DOMAIN.conf`, with collision detection during install/repair. If a future tested GoAccess package supports Unix domain sockets for realtime WebSockets, that can replace localhost TCP ports later, but v1 should not depend on it.

## Hestia Web Server Layouts

Hestia supports multiple web layouts:

- Nginx as proxy in front of Apache/PHP-FPM
- Nginx with PHP-FPM directly
- Apache variants

The first implementation should prefer the Nginx paths because Hestia's templates already include per-domain Nginx include files and GoAccess realtime requires WebSocket proxying.

For Nginx-only domains, Hestia's Nginx PHP-FPM templates already define `/vstats/` as an alias to the stats directory and include `stats/auth.conf*`.

For Nginx proxy plus Apache domains, Apache provides the `/vstats/` alias while Nginx proxies normal traffic. Realtime mode will likely need a more specific Nginx include location for the GoAccess WebSocket path.

Apache-only realtime support should be treated as a later compatibility target unless testing proves that it can be done safely without enabling extra Apache modules or touching broad server config.

## Template Strategy

Avoid editing Hestia's default `.tpl` and `.stpl` files in place.

Preferred order:

1. Use Hestia-supported per-domain include files under `/home/USER/conf/web/DOMAIN/`.
2. Add a dedicated GoAccess stats template under Hestia's stats template directory if required by `v-add-web-domain-stats`.
3. Patch or wrap Hestia command scripts only when unavoidable, with timestamped backups, checksum checks, repair, and uninstall support.

Adding dedicated stats values such as `goaccess-static` and `goaccess-realtime` likely requires matching stats templates and update dispatch behavior. Any Hestia PHP UI patch for prettier labels or extra per-domain option controls should be treated as optional and higher-risk than CLI/config-file support.

## Privacy Options

Privacy-preserving defaults should be enabled:

- anonymize visitor IPs by default
- remove query strings by default
- avoid exposing raw referrer/query-token data unless explicitly enabled

Administrators should be able to override these defaults per domain. Preferred order:

1. Add-on CLI flags such as `hestia-goaccess enable USER DOMAIN --mode static --no-anonymize-ip --include-query-string`.
2. Per-domain config files under `/etc/hestia-goaccess/domains/USER/DOMAIN.conf`.
3. Optional Hestia UI controls after the core behavior is stable.

The UI checkbox route is useful, but it means patching Hestia's web interface and command handlers. That should come after the lower-risk CLI/config implementation unless the first public release explicitly prioritizes UI completeness.

## Docker Strategy

Docker should be used as a development and customer evaluation harness, not as the primary production recommendation.

The Docker setup should validate:

- fresh Hestia install paths where feasible
- add-on install/uninstall idempotency
- static report generation
- rendered Nginx/Apache snippets
- GoAccess command generation

Docker cannot replace a VPS test for systemd behavior, real Nginx reloads, TLS, Cloudflare proxying, or Hestia upgrade interactions.

## Open Decisions

- Exact storage format for per-domain privacy overrides.
- Whether optional Hestia UI controls for GoAccess privacy flags belong in the first public release.
- Whether Apache-only realtime support is in scope for the first public release.
