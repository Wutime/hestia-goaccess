#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${repo_root}/conf/defaults.conf"

PREFIX="/usr/local"
INSTALL_GOACCESS="yes"
UPGRADE_GOACCESS="no"
ASSUME_YES="no"

usage() {
	cat <<'USAGE'
hestia-goaccess installer

Usage:
  ./install.sh [--yes] [--without-goaccess] [--upgrade-goaccess] [--prefix /usr/local]

Options:
  --yes                Run without confirmation prompts.
  --without-goaccess   Do not install GoAccess if it is missing.
  --upgrade-goaccess   Allow the installer to upgrade an old GoAccess package.
  --prefix PATH        Install the hestia-goaccess command under PATH/bin.
  -h, --help           Show this help.

This installer does not patch Hestia UI files yet. It installs the CLI and
prepares static GoAccess mode.
USAGE
}

die() {
	printf 'install.sh: %s\n' "$*" >&2
	exit 1
}

info() {
	printf '%s\n' "$*"
}

warn() {
	printf 'warn: %s\n' "$*" >&2
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
	install -m 0755 "${repo_root}/scripts/install-goaccess-debian.sh" "${share_dir}/scripts/install-goaccess-debian.sh"

	info "installed: ${PREFIX}/bin/hestia-goaccess"
	info "configured: /etc/hestia-goaccess/defaults.conf"
}

post_install() {
	"${PREFIX}/bin/hestia-goaccess" doctor

	cat <<POST

hestia-goaccess is installed.

Next steps:
  hestia-goaccess doctor USER DOMAIN
  hestia-goaccess enable USER DOMAIN --mode static
  hestia-goaccess status

Static reports are written to:
  /home/USER/web/DOMAIN/stats/index.html

Hestia serves the report at:
  http://DOMAIN/vstats/

Realtime mode and Hestia dropdown patching are not installed yet.
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
  - leave Hestia core files unchanged
PLAN

	confirm "Continue with installation?"
	require_hestia
	require_hestia_version
	require_supported_os
	ensure_goaccess
	install_files
	post_install
}

main "$@"
