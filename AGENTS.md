# AGENTS.md

## Project
`hestia-goaccess` is a standalone HestiaCP add-on that adds GoAccess web statistics, with an emphasis on realtime dashboards for selected domains.

Planned public repository:

```bash
git remote add origin git@github.com:Wutime/hestia-goaccess.git
git branch -M main
git push -u origin main
```

Planned local workspace:

```text
/opt/homebrew/var/www/hestia-goaccess
```

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

Initial product direction should support both concepts, but prioritize a robust realtime implementation.

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
Provide a project-owned admin command, likely:

```bash
hestia-goaccess install
hestia-goaccess enable USER DOMAIN --mode realtime
hestia-goaccess enable USER DOMAIN --mode static
hestia-goaccess disable USER DOMAIN
hestia-goaccess status
hestia-goaccess repair
hestia-goaccess uninstall
```

Optional future commands:

```bash
hestia-goaccess logs USER DOMAIN
hestia-goaccess doctor
hestia-goaccess upgrade
hestia-goaccess list
```

The CLI should be the source of truth even if a Hestia UI integration is added later.

Public terminology should prefer "add-on" over "plugin" unless Hestia provides a stable plugin API for this exact integration point.

## Realtime Architecture
Realtime mode should run a per-domain GoAccess process managed by systemd.

Recommended shape:
- one service unit per enabled domain
- one domain-specific GoAccess config file
- one domain-specific persisted GoAccess database path
- one domain-specific output HTML file under the Hestia stats directory
- WebSocket endpoint proxied safely through Nginx/Hestia

Example conceptual command:

```bash
goaccess /path/to/access.log \
  --config-file=/etc/hestia-goaccess/domains/USER/DOMAIN.conf \
  --real-time-html \
  --output=/home/USER/web/DOMAIN/stats/index.html \
  --persist \
  --restore \
  --db-path=/var/lib/hestia-goaccess/USER/DOMAIN
```

Do not hardcode this as final syntax until tested against Hestia `1.9.4` logs and GoAccess package versions.

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

Startup catch-up parsing can be the expensive part. Use persisted GoAccess state to avoid reparsing huge logs on every restart.

## Privacy Defaults
Default configuration should be privacy-friendly:
- no third-party tracking script
- no external analytics service
- use `--anonymize-ip` by default
- use `--no-query-string` by default unless the admin opts in
- avoid exposing raw query strings, tokens, or sensitive referrer data in public dashboards
- encourage or enforce authentication for stats pages

Privacy defaults should be easy to override per domain. Prefer CLI flags and `/etc/hestia-goaccess/domains/USER/DOMAIN.conf` first; optional Hestia UI checkboxes can come later if the UI patch surface remains small and reversible.

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
Do not test initial development on the live production Hestia server.

Recommended path:
1. Build a local/dev project skeleton in `/opt/homebrew/var/www/hestia-goaccess`.
2. Use Docker or VM-based test environments for repeatable Hestia `1.9.4` installs.
3. Also create a tiny disposable VPS for realistic Hestia testing, because Hestia is a full server control panel and local containers may not perfectly model systemd, Nginx, logs, permissions, and package behavior.
4. Once confidence is high, install on the live server as the final production test and use that process to validate public installation instructions.

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

Then open `https://panel.hestia-goaccess.localhost:8083/` with dev credentials `admin` / `admin`. This profile is heavier and may expose Docker Desktop/systemd limitations; keep it separate from the fast fixture service. The browser hostnames `hestia-goaccess.localhost` and `panel.hestia-goaccess.localhost` should point to `127.0.0.1` in local `/etc/hosts`; the container's internal Hestia hostname is `panel.hestia-goaccess.localhost` because Hestia requires a hostname with at least two dots. Use the `panel...` hostname and port `8083` for the Hestia panel so CSRF checks, cookies, and local certificate hostname all line up. Hestia is installed at runtime inside the container filesystem, so container restart preserves the panel but container recreation gives a fresh pretend VPS and requires rerunning the installer.

Current static prototype:
- `./install.sh [--yes] [--without-goaccess] [--upgrade-goaccess]`
- `./install.sh --with-hestia-dropdown`
- `hestia-goaccess doctor [USER DOMAIN]`
- `hestia-goaccess enable USER DOMAIN --mode static`
- `hestia-goaccess enable USER DOMAIN --mode realtime [--ws-url URL]`
- `hestia-goaccess status [USER DOMAIN]`
- `hestia-goaccess disable USER DOMAIN`

Static prototype behavior writes `/home/USER/web/DOMAIN/stats/index.html` and records state in `/etc/hestia-goaccess/domains/USER/DOMAIN.conf`.

Installer prototype behavior:
- requires root
- verifies HestiaCP `1.9.4+`
- verifies Debian 11/12 or Ubuntu 22.04/24.04
- verifies GoAccess `1.10.2+`
- offers to install missing GoAccess from the official GoAccess Debian/Ubuntu repository
- refuses an existing older GoAccess unless `--upgrade-goaccess` is explicit
- installs the CLI to `/usr/local/bin/hestia-goaccess`
- writes defaults to `/etc/hestia-goaccess/defaults.conf`
- leaves Hestia core/UI files unchanged unless `--with-hestia-dropdown` is used

Optional dropdown integration behavior:
- appends `goaccess-static` and `goaccess-realtime` to `/usr/local/hestia/conf/hestia.conf` `STATS_SYSTEM`
- installs `/usr/local/hestia/data/templates/web/goaccess-static/goaccess-static.tpl`
- installs `/usr/local/hestia/data/templates/web/goaccess-realtime/goaccess-realtime.tpl`
- wraps `/usr/local/hestia/bin/v-update-web-domain-stat`
- wraps `/usr/local/hestia/bin/v-delete-web-domain-stats`
- stores the original updater at `/usr/local/hestia/bin/v-update-web-domain-stat.hestia-goaccess-original`
- stores the original delete-stats command at `/usr/local/hestia/bin/v-delete-web-domain-stats.hestia-goaccess-original`
- stores timestamped backups under `/etc/hestia-goaccess/backups`
- dispatches only `STATS='goaccess-static'` to `/usr/local/bin/hestia-goaccess enable USER DOMAIN --mode static`
- dispatches only `STATS='goaccess-realtime'` to `/usr/local/bin/hestia-goaccess enable USER DOMAIN --mode realtime`
- falls through all other stats types to Hestia's original updater
- calls `hestia-goaccess disable USER DOMAIN` before falling through or deleting stats so realtime services and Nginx includes are removed
- does not patch Hestia PHP UI labels; the dropdown values are `goaccess-static` and `goaccess-realtime`

Current realtime prototype behavior:
- is available through CLI and Hestia dropdown after `--with-hestia-dropdown`
- runs one systemd service per enabled domain
- service names use `hestia-goaccess-USER-SAFE_DOMAIN.service`
- runs GoAccess as the Hestia user/group for the domain
- binds GoAccess to `127.0.0.1`
- allocates a port from `GOACCESS_PORT_RANGE`, default `64000-64999`
- installs a per-domain Nginx include named `/home/USER/conf/web/DOMAIN/nginx.conf_hestia_goaccess_realtime`
- proxies `/vstats/ws/` to the local GoAccess listener
- filters ignored paths before GoAccess parses logs; default is `/vstats/`
- supports comma or whitespace separated ignore paths through `--ignore-paths` or `HESTIA_GOACCESS_IGNORE_PATHS`
- creates `/var/lib/hestia-goaccess/USER/DOMAIN` for future persisted storage, but the current filtered realtime pipeline intentionally does not use `--persist/--restore` because replaying filtered stdin with restored data can double-count after restarts
- records `HG_PORT`, `HG_WS_URL`, and `HG_UNIT` in add-on state
- records `HG_IGNORE_PATHS` in add-on state
- records `HG_HTML_PREFS` in add-on state
- defaults GoAccess HTML reports to `GOACCESS_HTML_PREFS='{"theme":"darkGray"}'`
- Docker test command uses `--ws-url ws://example.test:20080/vstats/ws/` because the browser reaches the vhost through the host-mapped port
- Docker dropdown testing should set `GOACCESS_REALTIME_WS_URL_TEMPLATE=ws://%domain%:20080/vstats/ws/` in `/etc/hestia-goaccess/defaults.conf`

Primary production target profile:
- Ubuntu 22.04.5 LTS
- Nginx public frontend with Apache backend active
- Hestia panel on `8083`
- Hestia stats currently lists `none` and `awstats`
- GoAccess not installed initially
- Linux ephemeral port range observed as `32768-60999`, so default GoAccess realtime range `64000-64999` is suitable after listener checks
- do not commit hostnames, public IPs, private users, or private domains from inventory output

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

## Initial Milestones
Milestone 1: Research and Skeleton
- confirm Hestia `1.9.4` stats internals
- confirm GoAccess package behavior on supported OS
- create repository skeleton
- add shellcheck/lint workflow
- define config paths and service naming

Milestone 2: Static Mode Prototype
- generate a GoAccess report for one test domain
- write output into Hestia stats path
- validate Hestia stats auth behavior
- confirm log format detection

Milestone 3: Realtime Prototype
- create per-domain systemd service
- generate realtime HTML
- proxy WebSocket safely
- test service restart, reload, disable, uninstall
- measure CPU/RAM on a test domain

Milestone 4: Hestia Integration
- add GoAccess as a selectable stats engine if feasible
- implement repair/reapply
- document Hestia files touched
- test Hestia upgrade behavior where practical

Milestone 5: Public Release
- publish GitHub repository
- write install docs
- test on disposable VPS
- install on live server only after review
- update docs based on the live production installation experience

## Open Questions
- Exact patch/wrapper strategy for `v-update-web-domain-stat` and related queue behavior.
- Whether Hestia stats auth protects the realtime WebSocket endpoint cleanly when routed through a dedicated Nginx include.
- Whether to default realtime dashboards to anonymized IPs.
- Whether per-domain GoAccess services should run as root, the Hestia user, or a dedicated `hestia-goaccess` user.
- Exact GoAccess package feature matrix on Debian 11/12 and Ubuntu 22.04/24.04.
- Whether Apache-only realtime support belongs in the first public release or should be explicitly static-only at first.

Hestia services page direction:
- do not add per-domain GoAccess realtime units to Hestia's global services page for v1
- expose add-on and per-domain status through `hestia-goaccess status`
- consider an aggregate service/target later only if it gives clear value
