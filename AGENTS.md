# AGENTS.md

## Project
`hestia-goaccess` is a standalone HestiaCP add-on that adds GoAccess web statistics, with an emphasis on realtime dashboards for selected domains.

Public repository:

```bash
git@github.com:Wutime/hestia-goaccess.git
```

Local workspace:

```text
/Users/davidwilson/dev/www/hestia-goaccess
```

Current public release:

```text
v1.0.2
```

The `v1.0.2` tag has been pushed to GitHub. The release is intended to be a normal release, not a pre-release. No binary assets are required; GitHub's source zip/tarball plus the documented `git clone` install path are sufficient for v1.

Documentation maintenance rule:
- keep `AGENTS.md`, `README.md`, `CHANGELOG.md`, and relevant `docs/*.md` files synchronized with committed behavior changes
- after any commit, tag, release, or production finding that changes expected behavior, update these notes in the same work session before considering the task closed
- do not let release-state notes lag behind the public tag; stale project memory causes bad upgrade guidance

## Product Goal
Provide a privacy-friendly alternative to Google Analytics for Hestia-hosted sites by using server access logs through GoAccess.

Primary audience:
- HestiaCP server administrators.
- Operators who want analytics without third-party tracking scripts.
- Operators who want realtime visibility into site traffic, bots, 404s, referrers, and active requests.

The project should be simple enough for other Hestia admins to install from GitHub and maintain long-term.

## Baseline Requirement
Baseline supported Hestia version:

```text
HestiaCP 1.9.4+
```

Do not support older versions unless explicitly decided later. Assume Hestia `1.9.4` as the compatibility floor for paths, CLI behavior, and UI behavior.

Supported v1 operating systems mirror HestiaCP's official `1.9.4` matrix:
- Debian 11/12
- Ubuntu 22.04/24.04 LTS

GoAccess documents package commands for many other operating systems, but Fedora, Arch, Gentoo, Homebrew/macOS, BSD, and similar package-manager paths are out of scope unless Hestia itself supports those platforms. For supported Debian/Ubuntu Hestia servers, use GoAccess' official Debian/Ubuntu repository when GoAccess is missing or when the administrator explicitly allows an upgrade, because distro packages may lag behind the `GOACCESS_MIN_VERSION` baseline.

## Independence Requirement
This project must be standalone.

Do not depend on third-party Hestia plugin frameworks or plugin managers. In particular, do not rely on external "pluginable" layers or community patch frameworks.

It is acceptable for the installer to fetch project-owned assets from:
- the official `Wutime/hestia-goaccess` GitHub repository
- packaged release tarballs from that repository
- Composer, only if the dependency is truly justified and documented
- system package managers for first-party OS packages such as `goaccess`

Prefer no runtime dependencies beyond:
- HestiaCP
- GoAccess 1.10.2+
- systemd
- Nginx / Hestia web stack
- standard POSIX shell tools

## Important Design Decision
This is not just a static report generator. Realtime dashboards are the feature where the project should shine.

However, static report generation may still exist as:
- a fallback mode
- a safer default for very small servers
- a debugging mode
- a future compatibility option

The public v1 supports both concepts, with realtime explicitly opt-in per domain.

Per-domain Hestia selector direction:
- expose `awstats`, `goaccess-static`, and `goaccess-realtime` as separate stats choices where feasible
- use raw labels `goaccess-static` and `goaccess-realtime` for v1; they are human-readable enough and avoid an unnecessary Hestia PHP UI patch
- keep realtime explicitly opt-in per domain
- migrate existing AWStats domains only by explicit admin command, initially to static mode

## Hestia Integration Model
Hestia already has a web statistics abstraction:
- `v-list-web-stats`
- `v-add-web-domain-stats`
- `v-change-web-domain-stats`
- `v-delete-web-domain-stats`
- `v-update-web-domain-stat`
- `v-add-web-domain-stats-user`
- `v-delete-web-domain-stats-user`
- per-domain `STATS` value
- per-domain `STATS_USER` / `STATS_CRYPT` values
- global `STATS_SYSTEM` list
- stats output under the Hestia domain stats path
- optional Hestia "Statistics Authorization"

Current Hestia behavior is AWStats-oriented. The add-on should integrate with Hestia's stats model where practical, but must remain upgrade-aware and reversible.

Primary compatibility target:
- fresh/default Hestia installs first
- native Hestia `default.tpl` / `default.stpl` first
- other Hestia-shipped template pairs next
- custom templates only when they preserve native Hestia include behavior

Do not let the maintainer's production server custom templates become the public compatibility baseline. Treat production-custom behavior as supplemental validation only.

Confirmed source behavior from Hestia `main` / 1.9.x:
- `v-list-web-stats` derives the selector from `none` plus `STATS_SYSTEM`.
- `v-add-web-domain-stats` and `v-change-web-domain-stats` validate the requested type against `STATS_SYSTEM` and render `$WEBTPL/$type/$type.tpl`.
- `v-update-web-domain-stat` currently dispatches only `awstats`, so adding `goaccess` to `STATS_SYSTEM` alone is not enough.
- Hestia's existing stats URL is `/vstats/`, backed by `/home/USER/web/DOMAIN/stats/`.
- Hestia stats auth is managed by `v-add-web-domain-stats-user` and `v-delete-web-domain-stats-user`, not the general web-domain HTTP auth commands.

Because Hestia does not provide a stable full plugin API for replacing the stats engine, direct integration may require patching or wrapping Hestia CLI behavior. If patching is needed:
- make timestamped backups first
- keep patch scope minimal
- provide a repair/reapply command
- provide an uninstall command
- document the exact files touched
- detect unsupported Hestia versions before applying changes

## Proposed CLI
The project-owned admin command is:

```bash
hestia-goaccess doctor [USER DOMAIN]
hestia-goaccess enable USER DOMAIN --mode static
hestia-goaccess enable USER DOMAIN --mode realtime [--ws-url URL]
hestia-goaccess disable USER DOMAIN
hestia-goaccess repair
hestia-goaccess status [USER DOMAIN]
hestia-goaccess terminal [USER] DOMAIN
```

Optional future commands:

```bash
hestia-goaccess logs USER DOMAIN
hestia-goaccess upgrade
hestia-goaccess list
hestia-goaccess migrate-awstats --all --mode static
```

The CLI should be the source of truth even if a Hestia UI integration is added later.

Public terminology should prefer "add-on" over "plugin" unless Hestia provides a stable plugin API for this exact integration point.

## Realtime Architecture
Realtime mode should run a per-domain GoAccess process managed by systemd.

Recommended shape:
- one service unit per enabled domain
- service runs as the Hestia domain user with `adm` as a supplementary group so Debian/Ubuntu Hestia log directories can be traversed while per-domain log file permissions still apply
- verify that exact realtime log access model before enabling a domain; do not mutate Hestia log permissions or add customer users to groups
- one domain-specific GoAccess config file
- one domain-specific output HTML file under the Hestia stats directory
- WebSocket endpoint proxied safely through Nginx/Hestia

Current command shape:

```bash
goaccess /path/to/access.log \
  --real-time-html \
  --output=/home/USER/web/DOMAIN/stats/index.html \
  --persist \
  --restore \
  --db-path=/var/lib/hestia-goaccess/USER/DOMAIN \
  --keep-last=90
```

Realtime support does not require Apache. It requires GoAccess realtime HTML output and a protected WebSocket route. Prefer Nginx-backed Hestia layouts first because WebSocket proxying is required and Hestia's Nginx templates already support per-domain include snippets. Apache-only realtime support should be detected and documented before it is promised.

Realtime domain isolation direction:
- do not share one GoAccess realtime listener between unrelated domains
- run one GoAccess process/listener per realtime-enabled domain
- bind each listener to `127.0.0.1` on a deterministic unique port for v1
- proxy each domain's WebSocket path through that domain's Nginx include only
- protect both `/vstats/` and the WebSocket path with Hestia stats auth
- track assigned ports in add-on state and check collisions in install/repair
- allocate ports only when `goaccess-realtime` is enabled for a domain
- default to a configurable `64000-64999` range, after checking the server's ephemeral port range and currently listening sockets
- do not preassign ports per user or static domain

## Resource Safety
Realtime GoAccess is usually efficient after initial parsing, but the project must assume shared production servers and busy sites.

Use systemd limits by default:
- `Nice=10` or similar
- idle IO scheduling where supported
- conservative restart policy
- per-domain `MemoryMax`
- optional `CPUQuota`
- private temp where practical
- minimal privileges where practical

Avoid creating a design where enabling many sites accidentally creates unbounded memory or CPU pressure.

Startup catch-up parsing can be the expensive part. Static and realtime modes now use GoAccess `--persist`, `--restore`, `--db-path`, and `--keep-last` by default with a per-domain database under `/var/lib/hestia-goaccess/USER/DOMAIN` and a default rolling 90-day retention window. Switching between `goaccess-static` and `goaccess-realtime` preserves that database. Switching to non-GoAccess stats such as `awstats` or `none` intentionally removes hestia-goaccess-managed files for the domain.

## Privacy Defaults
Default configuration should be privacy-friendly:
- no third-party tracking script
- no external analytics service
- use `--anonymize-ip` by default
- use `--no-query-string` by default unless the admin opts in
- avoid exposing raw query strings, tokens, or sensitive referrer data in public dashboards
- encourage or enforce authentication for stats pages

Privacy defaults should be easy to override per domain. Prefer CLI flags and `/etc/hestia-goaccess/domains/USER/DOMAIN.conf` first; optional Hestia UI checkboxes can come later if the UI patch surface remains small and reversible.

Realtime overhead defaults should also be conservative by default:
- parse the selected Hestia log file directly when `GOACCESS_IGNORE_PATHS` is empty
- prevent `/vstats/` and `/vstats/ws/` from entering the domain access log by writing `stats/auth.conf_hestia_goaccess_accesslog_off` through Hestia's existing `stats/auth.conf*` include point
- allow admins to set `GOACCESS_DISABLE_STATS_ACCESS_LOG=no` if they intentionally want stats dashboard traffic in the domain log
- ignore common crawlers where GoAccess supports it safely
- reduce noisy static asset reporting where practical
- do not enable expensive DNS or GeoIP lookups by default
- use GoAccess persistence and restore with default `GOACCESS_KEEP_LAST=90`

Global configuration should provide smart defaults in `/etc/hestia-goaccess/defaults.conf`. Per-domain configuration should be possible through CLI flags and `/etc/hestia-goaccess/domains/USER/DOMAIN.conf`. A textarea or option block below Hestia's per-domain stats dropdown is desirable for realtime domains, especially for ignored paths, but should not block v1 if it makes installation or Hestia upgrade compatibility fragile.

The project should not claim to be a perfect Google Analytics replacement. It analyzes server logs. Behind Cloudflare, it sees origin requests, not every edge-cached hit.

## Cloudflare Context
Many Hestia users may run behind Cloudflare. For this server family in particular:
- origin traffic may be locked to Cloudflare IP ranges
- logs may show Cloudflare IPs unless real visitor IP handling is configured
- Cloudflare-cached hits may not reach origin and therefore may not appear in GoAccess

Installer or doctor command should detect or document:
- whether Nginx is using real visitor IP headers correctly
- whether access logs are in a GoAccess-compatible format
- whether WebSocket proxying works through Cloudflare

## Security
Realtime mode exposes an HTML dashboard and WebSocket endpoint. Treat both as sensitive.

Requirements:
- do not expose dashboards publicly by default
- integrate with Hestia stats auth where possible
- ensure the WebSocket endpoint is protected consistently with the HTML report
- avoid binding GoAccess WebSocket listeners broadly when a local bind will work
- document firewall and reverse proxy behavior
- avoid leaking full paths, credentials, query tokens, or private URLs

## Testing Strategy
The initial public release has already been validated through local Docker testing, a local Hestia pretend-VPS profile, and a live Hestia server pass on the supported Debian/Ubuntu layout. Future changes should repeat the narrowest useful test first, then broaden to Docker/Hestia/live validation based on risk.

Recommended path:
1. Use syntax checks and focused local script tests for narrow shell changes.
2. Use Docker or VM-based test environments for repeatable Hestia `1.9.4` installs.
3. Use a tiny disposable VPS for realistic Hestia testing when changes touch systemd, Nginx, permissions, package behavior, or installer rollback.
4. Use the live server only after local/disposable validation and only for changes that genuinely need production confirmation.

Docker is useful for:
- installer idempotency checks
- shellcheck/lint tests
- config rendering tests
- quick fresh-Hestia smoke tests if feasible
- customer evaluation of the add-on flow before touching a production server

A tiny VPS is better for:
- systemd service behavior
- Hestia package/layout behavior
- Nginx reverse proxy and WebSocket behavior
- real TLS/proxy constraints
- upgrade/repair/uninstall testing

Use both if practical. Do not rely only on Docker before production release.

Docker support should be framed as a test harness, not the primary production deployment model, because Hestia expects a fresh server with real service management.

Local Docker development command:

```bash
docker compose up -d --build
```

Use this after code changes because the Docker image copies the repository into `/workspace` at build time instead of bind-mounting the checkout. The local fixture report should then be available at:

```text
http://goaccess.localhost:18080/vstats/
```

Experimental local Hestia VPS profile:

```bash
docker compose --profile hestia up -d --build hestia-vps
docker compose exec hestia-vps scripts/hestia-vps-install.sh
```

Then open `https://panel.hestia-goaccess.localhost:8083/` with dev credentials `admin` / `admin`. This profile is heavier and may expose Docker Desktop/systemd limitations; keep it separate from the fast fixture service. The browser hostnames `hestia-goaccess.localhost` and `panel.hestia-goaccess.localhost` should point to `127.0.0.1` in local `/etc/hosts`; the container's internal Hestia hostname is `panel.hestia-goaccess.localhost` because Hestia requires a hostname with at least two dots. Use the `panel...` hostname and port `8083` for the Hestia panel so CSRF checks, cookies, and local certificate hostname all line up. Hestia is installed at runtime inside the container filesystem, so container restart preserves the panel but container recreation gives a fresh pretend VPS and requires rerunning the installer. After creating a local Hestia user/domain, use `scripts/install-hestia-mock-site.sh USER DOMAIN` inside the container to seed mock pages for cleaner GoAccess traffic tests.

Current CLI behavior:
- `./install.sh [--yes] [--without-goaccess] [--upgrade-goaccess]`
- `./install.sh`
- `hestia-goaccess doctor [USER DOMAIN]`
- `hestia-goaccess enable USER DOMAIN --mode static`
- `hestia-goaccess enable USER DOMAIN --mode realtime [--ws-url URL]`
- `hestia-goaccess status [USER DOMAIN]`
- `hestia-goaccess disable USER DOMAIN`
- `hestia-goaccess repair`

Static behavior writes `/home/USER/web/DOMAIN/stats/index.html` and records state in `/etc/hestia-goaccess/domains/USER/DOMAIN.conf`. Static reports are regenerated by Hestia's `webstats` queue or manual `v-update-web-domain-stat USER DOMAIN`. Static mode uses GoAccess persistence by default with a per-domain database under `/var/lib/hestia-goaccess/USER/DOMAIN` and `GOACCESS_KEEP_LAST=90`; it does not provide AWStats-style monthly/yearly archive pages.

Installer behavior:
- requires root
- verifies HestiaCP `1.9.4+`
- verifies Debian 11/12 or Ubuntu 22.04/24.04
- verifies GoAccess `1.10.2+`
- offers to install missing GoAccess from the official GoAccess Debian/Ubuntu repository
- refuses an existing older GoAccess unless `--upgrade-goaccess` is explicit
- installs the CLI to `/usr/local/bin/hestia-goaccess`
- creates `/etc/hestia-goaccess/defaults.conf` on first install
- preserves existing `/etc/hestia-goaccess/defaults.conf` values on reinstall and appends newly introduced defaults when needed
- installs Hestia dropdown integration by default; use `--without-hestia-dropdown` only for CLI-only installs
- installs an APT post-invoke hook at `/etc/apt/apt.conf.d/99hestia-goaccess-repair` so Debian/Ubuntu package updates automatically repair hestia-goaccess integration after Hestia package upgrades replace wrapped commands
- installs repair assets under `/usr/local/share/hestia-goaccess` so `hestia-goaccess repair` can reapply dropdown integration without a local git checkout

Dropdown integration behavior:
- appends `goaccess-static` and `goaccess-realtime` to `/usr/local/hestia/conf/hestia.conf` `STATS_SYSTEM`
- installs `/usr/local/hestia/data/templates/web/goaccess-static/goaccess-static.tpl`
- installs `/usr/local/hestia/data/templates/web/goaccess-realtime/goaccess-realtime.tpl`
- wraps `/usr/local/hestia/bin/v-update-web-domain-stat`
- wraps `/usr/local/hestia/bin/v-delete-web-domain-stats`
- stores the original updater at `/usr/local/hestia/bin/v-update-web-domain-stat.hestia-goaccess-original`
- stores the original delete-stats command at `/usr/local/hestia/bin/v-delete-web-domain-stats.hestia-goaccess-original`
- stores timestamped backups under `/etc/hestia-goaccess/backups`
- refreshes preserved original Hestia commands when a Hestia package upgrade has replaced the live command, so fallback behavior tracks the current Hestia version
- dispatches only `STATS='goaccess-static'` to `/usr/local/bin/hestia-goaccess enable USER DOMAIN --mode static`
- dispatches only `STATS='goaccess-realtime'` to `/usr/local/bin/hestia-goaccess enable USER DOMAIN --mode realtime`
- falls through all other stats types to Hestia's original updater
- calls `hestia-goaccess disable USER DOMAIN` before falling through or deleting stats so realtime services and Nginx includes are removed
- `hestia-goaccess repair` reapplies stats templates and wrappers; if repair detects drift, it reconciles all domains whose Hestia `STATS` is `goaccess-static` or `goaccess-realtime`
- does not patch Hestia PHP UI labels; the dropdown values are `goaccess-static` and `goaccess-realtime`

Current realtime behavior:
- is available through CLI and Hestia dropdown after the standard install
- runs one systemd service per enabled domain
- service names use `hestia-goaccess-USER-SAFE_DOMAIN.service`
- runs GoAccess as the Hestia user/group for the domain
- binds GoAccess to `127.0.0.1`
- allocates a port from `GOACCESS_PORT_RANGE`, default `64000-64999`
- installs a per-domain Nginx include named `/home/USER/conf/web/DOMAIN/nginx.conf_hestia_goaccess_realtime`
- sets `--ws-url` with an explicit public port such as `wss://DOMAIN:443/vstats/ws/`; GoAccess' browser client may ignore custom WebSocket URLs without a port and fall back to the internal listener port
- if Hestia/Nginx config has a concrete redirect from the base domain to another host such as `www.DOMAIN`, use that host in the generated WebSocket URL
- proxies `/vstats/ws/` to the local GoAccess listener
- writes `/home/USER/web/DOMAIN/stats/auth.conf_hestia_goaccess_accesslog_off` with `access_log off;` by default so `/vstats/` traffic does not enter the domain log; admins can set `GOACCESS_DISABLE_STATS_ACCESS_LOG=no` to opt out
- writes `/home/USER/web/DOMAIN/stats/auth.conf_hestia_goaccess_cache` for managed GoAccess domains so `/vstats/` is served with no-cache headers; this prevents stale static HTML from persisting after switching between `goaccess-static` and `goaccess-realtime`
- parses the selected Hestia log directly by default; filters ignored paths before GoAccess parses logs only when admins configure `--ignore-paths` or `HESTIA_GOACCESS_IGNORE_PATHS`
- supports comma or whitespace separated ignore paths through `--ignore-paths` or `HESTIA_GOACCESS_IGNORE_PATHS`
- uses bounded systemd stop behavior so re-enable and uninstall do not hang on stale realtime processes
- records `HG_PORT`, `HG_WS_URL`, and `HG_UNIT` in add-on state
- records `HG_IGNORE_PATHS` in add-on state
- records `HG_HTML_PREFS` in add-on state
- records `HG_LOG_FORMAT` in add-on state
- records `HG_DB_PATH` and `HG_KEEP_LAST` in add-on state
- uses GoAccess `--persist`, `--restore`, `--db-path`, and `--keep-last` by default
- defaults GoAccess HTML reports to `GOACCESS_HTML_PREFS='{"theme":"darkGray"}'`
- defaults GoAccess parsing to `GOACCESS_LOG_FORMAT=COMBINED`, matching Hestia's default Apache/Nginx domain access logs
- Docker test command uses `--ws-url ws://example.test:20080/vstats/ws/` because the browser reaches the vhost through the host-mapped port
- Docker dropdown testing should set `GOACCESS_REALTIME_WS_URL_TEMPLATE=ws://%domain%:20080/vstats/ws/` in `/etc/hestia-goaccess/defaults.conf`

GoAccess also provides an SSH terminal dashboard. This is separate from the managed `/vstats/` HTML report; enabling `goaccess-realtime` should not attach a terminal UI automatically. The CLI supports `hestia-goaccess terminal USER DOMAIN`, admin shortcut `hestia-goaccess USER DOMAIN`, and current-user shortcut `hestia-goaccess DOMAIN`. The single-domain shortcut resolves the Hestia user from the current shell login and works only if that SSH account can read the domain log.

Supplemental production validation profile:
- Ubuntu 22.04.5 LTS
- Nginx public frontend with Apache backend active
- Hestia panel on `8083`
- Hestia initially listed `none` and `awstats`; the add-on installed `goaccess-static` and `goaccess-realtime`
- GoAccess was installed from the official GoAccess Debian/Ubuntu repository during validation
- Linux ephemeral port range observed as `32768-60999`, so default GoAccess realtime range `64000-64999` is suitable after listener checks
- custom templates may be present; do not assume those customizations exist on customer servers
- do not commit hostnames, public IPs, private users, or private domains from inventory output
- validated switching `goaccess-static <> goaccess-realtime` preserves `/var/lib/hestia-goaccess/USER/DOMAIN` and restarts/stops the realtime service as expected
- Hestia `1.9.6` package upgrades replace wrapped Hestia commands under `/usr/local/hestia/bin`; `v1.0.1+` repairs this through the APT post-invoke hook and `hestia-goaccess repair`
- browsers and proxies may keep stale `/vstats/` HTML after mode switches unless explicit no-cache headers are present; `v1.0.2+` writes the managed cache include to fix normal refresh behavior

## Public Project Expectations
The GitHub project should be structured for long-term public use and contribution.

Expected files:

```text
README.md
AGENTS.md
LICENSE
install.sh
uninstall.sh
bin/hestia-goaccess
conf/
templates/
systemd/
nginx/
patches/
docs/
tests/
```

README should include:
- what the project does
- supported Hestia versions
- supported operating systems, once tested
- install instructions
- enable/disable instructions
- realtime vs static mode explanation
- security notes
- Cloudflare notes
- troubleshooting
- uninstall and rollback

## License
Prefer GPL-3.0 unless there is a clear reason to choose differently.

Rationale:
- HestiaCP is GPL-3.0.
- This project integrates closely with Hestia.
- A copyleft license encourages community improvements to remain available.

GoAccess itself is MIT licensed, which is compatible with this direction.

## Production Safety Rules
For live Hestia servers:
- treat all changes as production-impacting
- do not edit Hestia files without timestamped backups
- do not reload Nginx until `nginx -t` passes
- do not restart shared services when a narrower reload or per-domain service restart is enough
- avoid destructive commands
- keep install and uninstall reversible
- log every file changed and command run
- provide rollback steps

The installer must be idempotent where possible.

GoAccess dependency policy:
- require GoAccess `1.10.2` or newer for v1
- check `goaccess --version` during install and doctor
- if GoAccess is missing, install only when dependency installation is explicitly allowed
- if GoAccess is present but older than baseline, fail with a clear error unless the admin explicitly requested an upgrade path
- prefer GoAccess' official Debian/Ubuntu repository over stale distro packages when installation or upgrade is requested

Log format policy:
- do not change Hestia's Nginx or Apache access log formats for v1
- consume the existing per-domain access log with GoAccess `--log-format="${GOACCESS_LOG_FORMAT}"`
- when both Apache and Nginx Hestia domain logs exist, select the active non-empty log and prefer the newest non-empty log when both have data
- default `GOACCESS_LOG_FORMAT=COMBINED`, which matches Hestia's generated `combined` access logs and AWStats `LogFormat=1`
- validate parsing in `hestia-goaccess doctor USER DOMAIN` before enabling reports
- allow admins with custom Hestia log templates to override `GOACCESS_LOG_FORMAT` in `/etc/hestia-goaccess/defaults.conf`

## Release State
`v1.0.2` is the current public release. The original research, static prototype, realtime prototype, Hestia dropdown integration, persistence, live validation, changelog, tag, and GitHub release preparation are complete.

Release history:
- `v1.0.0`: initial public release
- `v1.0.1`: Hestia package-upgrade repair hook, refreshed fallback wrappers, and domain reconciliation after repair
- `v1.0.2`: no-cache headers for managed `/vstats/` pages to avoid stale dashboard HTML after static/realtime mode changes

Known future work:
- add an explicit AWStats migration command, likely static-first
- broaden validation on a disposable VPS and additional stock Hestia template combinations
- investigate Apache-only realtime support before promising it
- consider optional Hestia UI controls for advanced per-domain settings only if the patch surface stays small and reversible
- add formal automated tests beyond syntax checks and Docker smoke coverage

Hestia services page direction:
- do not add per-domain GoAccess realtime units to Hestia's global services page for v1
- expose add-on and per-domain status through `hestia-goaccess status`
- consider an aggregate service/target later only if it gives clear value
