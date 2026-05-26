#!/usr/bin/env bash
set -euo pipefail

PREFIX="/usr/local"
ASSUME_YES="no"
REMOVE_STATE="no"

usage() {
	cat <<'USAGE'
hestia-goaccess uninstaller

Usage:
  ./uninstall.sh [--yes] [--remove-state] [--prefix /usr/local]

Options:
  --yes           Run without confirmation prompts.
  --remove-state  Also remove /etc/hestia-goaccess state and config files.
  --prefix PATH   Remove the hestia-goaccess command from PATH/bin.
  -h, --help      Show this help.

Generated per-domain reports are left in place.
USAGE
}

die() {
	printf 'uninstall.sh: %s\n' "$*" >&2
	exit 1
}

confirm() {
	local prompt="$1"
	local answer

	if [[ "${ASSUME_YES}" == "yes" ]]; then
		return 0
	fi

	[[ -t 0 ]] || die "${prompt} Re-run with --yes for non-interactive uninstalls."
	printf '%s [y/N] ' "${prompt}"
	read -r answer
	case "${answer}" in
		y|Y|yes|YES) return 0 ;;
		*) die "uninstall cancelled" ;;
	esac
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--yes|-y)
			ASSUME_YES="yes"
			;;
		--remove-state)
			REMOVE_STATE="yes"
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

[[ "${EUID}" -eq 0 ]] || die "run this uninstaller as root"

confirm "Remove hestia-goaccess CLI files?"

rm -f "${PREFIX}/bin/hestia-goaccess"
rm -rf "${PREFIX}/share/hestia-goaccess"

if [[ "${REMOVE_STATE}" == "yes" ]]; then
	rm -rf /etc/hestia-goaccess
	printf 'removed state/config: /etc/hestia-goaccess\n'
else
	printf 'kept state/config: /etc/hestia-goaccess\n'
fi

printf 'removed: %s/bin/hestia-goaccess\n' "${PREFIX}"
printf 'generated stats reports were left in place\n'
