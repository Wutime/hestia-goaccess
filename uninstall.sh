#!/usr/bin/env bash
set -euo pipefail

PREFIX="/usr/local"
ASSUME_YES="no"
REMOVE_STATE="no"
REMOVE_DROPDOWN="no"
ADDON_STATS_TYPES=("goaccess-static" "goaccess-realtime")

usage() {
	cat <<'USAGE'
hestia-goaccess uninstaller

Usage:
  ./uninstall.sh [--yes] [--remove-state] [--remove-hestia-dropdown] [--prefix /usr/local]

Options:
  --yes           Run without confirmation prompts.
  --remove-state  Also remove /etc/hestia-goaccess state and config files.
  --remove-hestia-dropdown
                  Restore Hestia stats commands and remove GoAccess stats types from STATS_SYSTEM.
  --prefix PATH   Remove the hestia-goaccess command from PATH/bin.
  -h, --help      Show this help.

Generated per-domain reports are left in place.
USAGE
}

die() {
	printf 'uninstall.sh: %s\n' "$*" >&2
	exit 1
}

backup_file() {
	local file="$1"
	local backup_dir="/etc/hestia-goaccess/backups"
	local timestamp

	[[ -f "${file}" ]] || return 0
	timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
	install -d -m 0755 "${backup_dir}"
	cp -p "${file}" "${backup_dir}/$(basename "${file}").${timestamp}"
	printf 'backup: %s\n' "${backup_dir}/$(basename "${file}").${timestamp}"
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
		--remove-hestia-dropdown)
			REMOVE_DROPDOWN="yes"
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

remove_dropdown_integration() {
	local conf="/usr/local/hestia/conf/hestia.conf"
	local current
	local updated=""
	local -a items
	local item
	local tmp
	local type

	restore_wrapper() {
		local command="$1"
		local target="/usr/local/hestia/bin/${command}"
		local original="/usr/local/hestia/bin/${command}.hestia-goaccess-original"

		if [[ -f "${original}" ]] && grep -q 'hestia-goaccess managed wrapper' "${target}" 2>/dev/null; then
			backup_file "${target}"
			cp -p "${original}" "${target}"
			rm -f "${original}"
			printf 'restored: %s\n' "${target}"
		fi
	}

	is_addon_type() {
		local candidate="$1"
		local addon_type

		for addon_type in "${ADDON_STATS_TYPES[@]}"; do
			[[ "${candidate}" == "${addon_type}" ]] && return 0
		done
		return 1
	}

	restore_wrapper "v-update-web-domain-stat"
	restore_wrapper "v-delete-web-domain-stats"

	if [[ -f "${conf}" ]]; then
		current="$(sed -n "s/^STATS_SYSTEM='\\(.*\\)'$/\\1/p" "${conf}" | head -n 1)"
		if [[ -n "${current}" ]]; then
			IFS=',' read -r -a items <<< "${current}"
			for item in "${items[@]}"; do
				is_addon_type "${item}" && continue
				if [[ -z "${updated}" ]]; then
					updated="${item}"
				else
					updated="${updated},${item}"
				fi
			done
			if [[ "${updated}" != "${current}" ]]; then
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
				printf 'updated: %s\n' "${conf}"
			fi
		fi
	fi

	for type in "${ADDON_STATS_TYPES[@]}"; do
		rm -rf "/usr/local/hestia/data/templates/web/${type}"
		printf 'removed: %s\n' "/usr/local/hestia/data/templates/web/${type}"
	done
}

if [[ "${REMOVE_DROPDOWN}" == "yes" ]]; then
	remove_dropdown_integration
fi

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
