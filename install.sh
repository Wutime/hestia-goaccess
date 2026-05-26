#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${repo_root}/conf/defaults.conf"

PREFIX="/usr/local"
INSTALL_GOACCESS="yes"
UPGRADE_GOACCESS="no"
ASSUME_YES="no"
WITH_DROPDOWN="no"
ADDON_STATS_TYPES=("goaccess-static" "goaccess-realtime")

usage() {
	cat <<'USAGE'
hestia-goaccess installer

Usage:
  ./install.sh [--yes] [--without-goaccess] [--upgrade-goaccess] [--with-hestia-dropdown] [--prefix /usr/local]

Options:
  --yes                Run without confirmation prompts.
  --without-goaccess   Do not install GoAccess if it is missing.
  --upgrade-goaccess   Allow the installer to upgrade an old GoAccess package.
  --with-hestia-dropdown
                       Register goaccess-static and goaccess-realtime in Hestia's Web Statistics dropdown.
  --prefix PATH        Install the hestia-goaccess command under PATH/bin.
  -h, --help           Show this help.

By default this installer does not patch Hestia's stats dropdown. Use
--with-hestia-dropdown to install the reversible Hestia integration.
USAGE
}

die() {
	printf 'install.sh: %s\n' "$*" >&2
	exit 1
}

info() {
	printf '%s\n' "$*"
}

version_ge() {
	local current="$1"
	local minimum="$2"
	local first

	first="$(printf '%s\n%s\n' "${minimum}" "${current}" | sort -V | head -n 1)"
	[[ "${first}" == "${minimum}" ]]
}

confirm() {
	local prompt="$1"
	local answer

	if [[ "${ASSUME_YES}" == "yes" ]]; then
		return 0
	fi

	[[ -t 0 ]] || die "${prompt} Re-run with --yes for non-interactive installs."
	printf '%s [y/N] ' "${prompt}"
	read -r answer
	case "${answer}" in
		y|Y|yes|YES) return 0 ;;
		*) die "installation cancelled" ;;
	esac
}

parse_args() {
	while [[ "$#" -gt 0 ]]; do
		case "$1" in
			--yes|-y)
				ASSUME_YES="yes"
				;;
			--without-goaccess)
				INSTALL_GOACCESS="no"
				;;
			--upgrade-goaccess)
				UPGRADE_GOACCESS="yes"
				;;
			--with-hestia-dropdown)
				WITH_DROPDOWN="yes"
				;;
			--prefix)
				shift
				PREFIX="${1:-}"
				[[ -n "${PREFIX}" ]] || die "--prefix requires a path"
				;;
			--prefix=*)
				PREFIX="${1#--prefix=}"
				[[ -n "${PREFIX}" ]] || die "--prefix requires a path"
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				die "unknown option: $1"
				;;
		esac
		shift
	done
}

require_root() {
	[[ "${EUID}" -eq 0 ]] || die "run this installer as root"
}

require_hestia() {
	[[ -x /usr/local/hestia/bin/v-list-sys-config ]] ||
		die "Hestia CLI not found at /usr/local/hestia/bin"
}

backup_file() {
	local file="$1"
	local backup_dir="/etc/hestia-goaccess/backups"
	local timestamp

	[[ -f "${file}" ]] || die "cannot back up missing file: ${file}"
	timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
	install -d -m 0755 "${backup_dir}"
	cp -p "${file}" "${backup_dir}/$(basename "${file}").${timestamp}"
	info "backup: ${backup_dir}/$(basename "${file}").${timestamp}"
}

hestia_version() {
	/usr/local/hestia/bin/v-list-sys-config json |
		sed -n 's/.*"VERSION": "\([^"]*\)".*/\1/p' |
		head -n 1
}

require_hestia_version() {
	local version

	version="$(hestia_version)"
	[[ -n "${version}" ]] || die "unable to determine Hestia version"
	if ! version_ge "${version}" "1.9.4"; then
		die "Hestia ${version} is too old; minimum supported version is 1.9.4"
	fi
	info "ok: Hestia ${version}"
}

require_supported_os() {
	local id=""
	local version_id=""

	[[ -f /etc/os-release ]] || die "/etc/os-release not found"
	# shellcheck disable=SC1091
	source /etc/os-release
	id="${ID:-}"
	version_id="${VERSION_ID:-}"

	case "${id}:${version_id}" in
		debian:11|debian:12|ubuntu:22.04|ubuntu:24.04)
			info "ok: ${PRETTY_NAME:-${id} ${version_id}}"
			;;
		*)
			die "unsupported OS ${PRETTY_NAME:-${id} ${version_id}}; supported targets are Debian 11/12 and Ubuntu 22.04/24.04"
			;;
	esac
}

goaccess_version() {
	goaccess --version 2>/dev/null |
		sed -n 's/^GoAccess - \([0-9][0-9.]*[0-9]\).*/\1/p' |
		head -n 1
}

ensure_goaccess() {
	local version

	if ! command -v goaccess >/dev/null 2>&1; then
		if [[ "${INSTALL_GOACCESS}" == "no" ]]; then
			die "goaccess is not installed; minimum required version is ${GOACCESS_MIN_VERSION}"
		fi
		info "goaccess is not installed."
		confirm "Install GoAccess ${GOACCESS_MIN_VERSION}+ from the official GoAccess Debian/Ubuntu repository?"
		"${repo_root}/scripts/install-goaccess-debian.sh"
		return
	fi

	version="$(goaccess_version)"
	[[ -n "${version}" ]] || die "unable to determine goaccess version"
	if version_ge "${version}" "${GOACCESS_MIN_VERSION}"; then
		info "ok: goaccess ${version}"
		return
	fi

	if [[ "${UPGRADE_GOACCESS}" != "yes" ]]; then
		die "goaccess ${version} is too old; minimum required version is ${GOACCESS_MIN_VERSION}. Re-run with --upgrade-goaccess to let this installer upgrade it."
	fi

	confirm "Upgrade GoAccess ${version} to ${GOACCESS_MIN_VERSION}+ from the official GoAccess Debian/Ubuntu repository?"
	"${repo_root}/scripts/install-goaccess-debian.sh"
}

install_files() {
	local share_dir="${PREFIX}/share/hestia-goaccess"

	install -d -m 0755 "${PREFIX}/bin"
	install -d -m 0755 /etc/hestia-goaccess/domains
	install -d -m 0755 "${share_dir}/conf" "${share_dir}/scripts"

	install -m 0755 "${repo_root}/bin/hestia-goaccess" "${PREFIX}/bin/hestia-goaccess"
	install -m 0755 "${repo_root}/uninstall.sh" "${share_dir}/uninstall.sh"
	install -m 0644 "${repo_root}/conf/defaults.conf" /etc/hestia-goaccess/defaults.conf
	install -m 0644 "${repo_root}/conf/defaults.conf" "${share_dir}/conf/defaults.conf"
	install -m 0755 "${repo_root}/scripts/check-goaccess-version.sh" "${share_dir}/scripts/check-goaccess-version.sh"
	install -m 0755 "${repo_root}/scripts/hestia-goaccess-filter-log" "${share_dir}/scripts/hestia-goaccess-filter-log"
	install -m 0755 "${repo_root}/scripts/hestia-goaccess-realtime-runner" "${share_dir}/scripts/hestia-goaccess-realtime-runner"
	install -m 0755 "${repo_root}/scripts/install-goaccess-debian.sh" "${share_dir}/scripts/install-goaccess-debian.sh"

	info "installed: ${PREFIX}/bin/hestia-goaccess"
	info "configured: /etc/hestia-goaccess/defaults.conf"
}

stats_system_value() {
	sed -n "s/^STATS_SYSTEM='\\(.*\\)'$/\\1/p" /usr/local/hestia/conf/hestia.conf |
		head -n 1
}

stats_system_has_type() {
	local stats="$1"
	local type="$2"
	local -a items
	local item

	IFS=',' read -r -a items <<< "${stats}"
	for item in "${items[@]}"; do
		[[ "${item}" == "${type}" ]] && return 0
	done

	return 1
}

register_stats_system_type() {
	local type="$1"
	local conf="/usr/local/hestia/conf/hestia.conf"
	local current
	local updated
	local tmp

	current="$(stats_system_value)"
	[[ -n "${current}" ]] || die "unable to read STATS_SYSTEM from ${conf}"
	if stats_system_has_type "${current}" "${type}"; then
		info "ok: ${type} already registered in STATS_SYSTEM"
		return
	fi

	updated="${current},${type}"
	tmp="$(mktemp)"
	backup_file "${conf}"
	awk -v updated="${updated}" '
		/^STATS_SYSTEM='\''/ {
			print "STATS_SYSTEM='\''" updated "'\''"
			next
		}
		{ print }
	' "${conf}" > "${tmp}"
	cat "${tmp}" > "${conf}"
	rm -f "${tmp}"
	info "registered: ${type} in STATS_SYSTEM"
}

install_stats_template() {
	local type="$1"
	local template_dir="/usr/local/hestia/data/templates/web/${type}"

	install -d -m 0755 "${template_dir}"
	install -m 0644 \
		"${repo_root}/templates/web/${type}/${type}.tpl" \
		"${template_dir}/${type}.tpl"
	info "installed: ${template_dir}/${type}.tpl"
}

install_hestia_wrapper() {
	local command="$1"
	local target="/usr/local/hestia/bin/${command}"
	local original="/usr/local/hestia/bin/${command}.hestia-goaccess-original"
	local wrapper="${repo_root}/patches/hestia/${command}.wrapper"

	if grep -q 'hestia-goaccess managed wrapper' "${target}" 2>/dev/null; then
		install -m 0755 "${wrapper}" "${target}"
		info "updated: ${command} wrapper"
		return
	fi

	[[ -x "${target}" ]] || die "Hestia command not found: ${target}"
	if [[ ! -f "${original}" ]]; then
		backup_file "${target}"
		cp -p "${target}" "${original}"
		info "preserved: ${original}"
	fi

	install -m 0755 "${wrapper}" "${target}"
	info "installed: ${target} wrapper"
}

install_hestia_dropdown_integration() {
	local type

	info "installing Hestia dropdown integration"
	for type in "${ADDON_STATS_TYPES[@]}"; do
		register_stats_system_type "${type}"
		install_stats_template "${type}"
	done
	install_hestia_wrapper "v-update-web-domain-stat"
	install_hestia_wrapper "v-delete-web-domain-stats"
	info "ok: Hestia dropdown integration installed"
}

post_install() {
	"${PREFIX}/bin/hestia-goaccess" doctor

	cat <<POST

hestia-goaccess is installed.

Next steps:
  hestia-goaccess doctor USER DOMAIN
  hestia-goaccess enable USER DOMAIN --mode static
  hestia-goaccess enable USER DOMAIN --mode realtime
  hestia-goaccess status

Static reports are written to:
  /home/USER/web/DOMAIN/stats/index.html

Hestia serves the report at:
  http://DOMAIN/vstats/

Realtime mode is available through the CLI and, when dropdown integration is enabled, through Hestia as goaccess-realtime.
Hestia dropdown integration: ${WITH_DROPDOWN}
POST
}

main() {
	parse_args "$@"
	require_root

	cat <<PLAN
hestia-goaccess installer plan:
  - verify HestiaCP 1.9.4+
  - verify supported Debian/Ubuntu target
  - verify GoAccess ${GOACCESS_MIN_VERSION}+$(if [[ "${INSTALL_GOACCESS}" == "yes" ]]; then printf ' or offer to install it'; fi)
  - install the hestia-goaccess CLI to ${PREFIX}/bin
  - create /etc/hestia-goaccess state/config directories
  - Hestia dropdown integration: ${WITH_DROPDOWN}
PLAN

	confirm "Continue with installation?"
	require_hestia
	require_hestia_version
	require_supported_os
	ensure_goaccess
	install_files
	if [[ "${WITH_DROPDOWN}" == "yes" ]]; then
		install_hestia_dropdown_integration
	fi
	post_install
}

main "$@"
