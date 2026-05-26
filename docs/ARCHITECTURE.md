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

Current prototype behavior:

- `hestia-goaccess doctor [USER DOMAIN]` checks Hestia `1.9.4+`, GoAccess `1.10.2+`, domain existence, stats directory, readable access log, and GoAccess log-format compatibility.
- `hestia-goaccess enable USER DOMAIN --mode static` reads `/var/log/apache2/domains/DOMAIN.log` when present, falling back to `/var/log/nginx/domains/DOMAIN.log`.
- Static reports are generated directly to `/home/USER/web/DOMAIN/stats/index.html`.
- Generated report state is recorded under `/etc/hestia-goaccess/domains/USER/DOMAIN.conf`.
- Hestia core dropdown integration is installed by default and can be skipped with `./install.sh --without-hestia-dropdown`.

Without dropdown integration, Hestia can serve `/vstats/`, but the Edit Web Domain stats dropdown will not show GoAccess options. With standard dropdown integration enabled, `goaccess-static` and `goaccess-realtime` are appended to `STATS_SYSTEM`, matching Hestia stats templates are installed, and Hestia's stats update/delete commands are wrapped so GoAccess values dispatch to the add-on while AWStats and future stats engines fall through to Hestia's original commands.

Current realtime behavior:

- is available through CLI and Hestia dropdown after the standard install
- creates one systemd service per realtime-enabled domain
- binds GoAccess to `127.0.0.1`
- proxies `/vstats/ws/` from the domain's Nginx vhost to the local listener
- writes realtime HTML to `/home/USER/web/DOMAIN/stats/index.html`
- filters `/vstats/` by default before GoAccess parses logs
- preselects GoAccess' shipped `darkGray` HTML theme through `GOACCESS_HTML_PREFS='{"theme":"darkGray"}'`
- uses bounded systemd stop behavior so re-enable and uninstall do not hang on stale realtime processes
- records the selected port, service unit, and WebSocket URL in add-on state
- stops the realtime service and removes the Nginx include when Hestia switches the domain to another stats type or disables stats

## Terminal Dashboard

GoAccess' terminal dashboard is useful over SSH and is separate from the managed `/vstats/` HTML report. Enabling `goaccess-realtime` should not spawn or attach a terminal UI, but the installed GoAccess binary and validated domain log path make it straightforward for administrators to open one manually.

The CLI should provide Hestia-aware shortcuts:

```bash
hestia-goaccess terminal USER DOMAIN
hestia-goaccess USER DOMAIN
hestia-goaccess DOMAIN
```

`hestia-goaccess DOMAIN` resolves the Hestia user from the current shell login. Domain users with SSH access can use it directly only if the Hestia server grants them read access to their domain log. Treat that as layout-dependent, not guaranteed.

GoAccess does not provide a general `--ignore-path` option. Static and realtime modes therefore use `scripts/hestia-goaccess-filter-log` to pre-filter access logs. The current default is `/vstats/`, and the CLI accepts comma or whitespace separated overrides through `--ignore-paths`. A future Hestia UI textarea can map directly to that setting.

## Access Log Format

GoAccess needs the parser format to match the access log. Hestia's generated Apache and Nginx domain configs use the standard `combined` format for the per-domain `.log` file, while AWStats uses its own config value (`LogFormat=1`) against the same style of log. For v1, the add-on should not rewrite or replace Hestia's access log directives because that would create unnecessary rollback risk for AWStats.

The add-on default is:

```bash
GOACCESS_LOG_FORMAT=COMBINED
```

Static and realtime report generation pass this to GoAccess as `--log-format="${GOACCESS_LOG_FORMAT}"`. The doctor command should parse-test the selected domain log before report generation. If an administrator has custom Hestia templates with a non-combined log format, they can override `GOACCESS_LOG_FORMAT` in `/etc/hestia-goaccess/defaults.conf`.

## GoAccess Version Policy

The v1 baseline is GoAccess `1.10.2` or newer. The installer and `doctor` command should:

- check whether `goaccess` exists
- parse `goaccess --version`
- fail clearly if the version is older than the configured baseline
- install GoAccess only when it is missing and the administrator has allowed dependency installation
- avoid silently upgrading an existing GoAccess package on production servers

If GoAccess is missing, the preferred Debian/Ubuntu source is GoAccess' official deb repository. If a server already has an older distro package installed, the add-on should explain how to upgrade through the official GoAccess repo or provide an explicit `--upgrade-goaccess` path.

HestiaCP `1.9.4` officially supports Debian 11/12 and Ubuntu 22.04/24.04 on 64-bit AMD64/x86_64 or ARM64/aarch64 systems. The add-on should mirror that OS matrix for v1. GoAccess documents package commands for Fedora, Arch, Gentoo, Homebrew/macOS, BSD, and other systems, but those are out of scope unless Hestia supports those platforms.

## Realtime Mode

Realtime mode should use one GoAccess process per enabled domain, managed by systemd on real servers.

Recommended defaults:

- bind the GoAccess WebSocket listener to `127.0.0.1`
- use a deterministic unique local port per realtime domain
- write the HTML report to Hestia's stats directory
- set `--ws-url` to the public `/vstats/` WebSocket route
- keep GoAccess realtime `--persist` / `--restore` disabled until the shutdown/restore path is proven stable
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

Port allocation should happen only when a domain is switched to `goaccess-realtime`. Static domains and users without realtime domains do not need reserved ports.

Recommended v1 port policy:

- default configurable port range: `64000-64999`
- allocate the first free port in the configured range
- store the chosen port in add-on state, for example `/etc/hestia-goaccess/domains/USER/DOMAIN.conf`
- maintain a small global registry such as `/etc/hestia-goaccess/ports.conf` for collision checks and repair
- check both add-on state and currently listening sockets before assigning a port
- hold an install/repair lock while assigning ports so two concurrent enables cannot choose the same port
- release the port when realtime is disabled for that domain
- fail safely with a clear error if no free port is available

The installer should not blindly assume the default range is safe. It should read the host's configured ephemeral port range, for example `/proc/sys/net/ipv4/ip_local_port_range` on Linux, and warn or require an override if the configured GoAccess range overlaps. Ranges such as `50000-50100` and parts of `60000-60500` may overlap common Linux ephemeral port settings. `64000-64999` is a better default candidate, but still must be verified on the target server.

If a future tested GoAccess package supports Unix domain sockets for realtime WebSockets, that can replace localhost TCP ports later, but v1 should not depend on it.

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

## Realtime Overhead Defaults

Realtime mode should ship with conservative defaults because Hestia servers often host many unrelated domains and customers.

Recommended v1 behavior:

- filter the stats route itself, default `/vstats/`
- ignore common crawlers through GoAccess where available
- exclude or hide static assets in reports where that reduces noise without changing the server log format
- keep DNS and GeoIP lookups disabled unless the administrator opts in
- keep realtime `--persist` / `--restore` disabled until it is proven stable across supported server targets
- avoid repeatedly reparsing giant historical logs as a future hardening goal
- keep systemd CPU, memory, IO, and privilege limits conservative

Global defaults should be stored in `/etc/hestia-goaccess/defaults.conf`. Per-domain overrides should be stored in `/etc/hestia-goaccess/domains/USER/DOMAIN.conf` and updated through the CLI first. A Hestia domain-page textarea for selected GoAccess options is desirable later, especially for ignored paths, but it should remain optional unless it can be implemented without broad PHP UI patching.

## Docker Strategy

Docker should be used as a development and customer evaluation harness, not as the primary production recommendation.

The Docker setup should validate:

- fresh Hestia install paths where feasible
- add-on install/uninstall idempotency
- static report generation
- rendered Nginx/Apache snippets
- GoAccess command generation

Docker cannot replace a VPS test for systemd behavior, real Nginx reloads, TLS, Cloudflare proxying, or Hestia upgrade interactions.

The primary development profile should follow [PRODUCTION_TARGET.md](PRODUCTION_TARGET.md), which captures the maintainer's sanitized production server shape.

## Hestia Services Integration

Hestia's server services page is a global service-management surface. It is useful for core daemons, but not a good fit for one GoAccess realtime unit per domain.

For v1:

- do not add per-domain GoAccess units to Hestia's global services page
- expose status through `hestia-goaccess status`
- manage realtime units through systemd and the add-on CLI
- keep Hestia UI integration focused on the existing per-domain Web Statistics selector

An aggregate `hestia-goaccess` service or systemd target can be considered later if it makes start/stop/status operations clearer without hiding per-domain isolation.

## Open Decisions

- Exact storage format for per-domain privacy overrides.
- Whether optional Hestia UI controls for GoAccess privacy flags belong in the first public release.
- Whether Apache-only realtime support is in scope for the first public release.
