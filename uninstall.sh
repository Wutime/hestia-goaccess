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
  --remove-state  Also remove /etc/hestia-goaccess state/config files.
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

state_value() {
	local file="$1"
	local key="$2"

	[[ -f "${file}" ]] || return 1
	sed -n "s/^${key}='\\([^']*\\)'$/\\1/p" "${file}" | head -n 1
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

cleanup_realtime_artifacts() {
	local file
	local user
	local domain
	local unit
	local unit_path
	local db_path
	local report_path
	local include
	local changed_units="no"
	local changed_nginx="no"

	while IFS= read -r file; do
		user="$(state_value "${file}" "HG_USER" || true)"
		domain="$(state_value "${file}" "HG_DOMAIN" || true)"
		unit="$(state_value "${file}" "HG_UNIT" || true)"
		db_path="$(state_value "${file}" "HG_DB_PATH" || true)"
		report_path="$(state_value "${file}" "HG_REPORT_PATH" || true)"

		if [[ -n "${unit}" ]]; then
			systemctl stop "${unit}" >/dev/null 2>&1 || true
			systemctl disable "${unit}" >/dev/null 2>&1 || true
			unit_path="/etc/systemd/system/${unit}"
			if [[ -f "${unit_path}" ]]; then
				rm -f "${unit_path}"
				printf 'removed: %s\n' "${unit_path}"
				changed_units="yes"
			fi
		fi

		if [[ -n "${user}" && -n "${domain}" ]]; then
			include="/home/${user}/web/${domain}/stats/auth.conf_hestia_goaccess_accesslog_off"
			if [[ -f "${include}" ]]; then
				rm -f "${include}"
				printf 'removed: %s\n' "${include}"
			fi
			include="/home/${user}/web/${domain}/stats/auth.conf_hestia_goaccess_cache"
			if [[ -f "${include}" ]]; then
				rm -f "${include}"
				printf 'removed: %s\n' "${include}"
			fi
			include="/home/${user}/conf/web/${domain}/nginx.conf_hestia_goaccess_realtime"
			if [[ -f "${include}" ]]; then
				rm -f "${include}"
				printf 'removed: %s\n' "${include}"
				changed_nginx="yes"
			fi
			include="/home/${user}/conf/web/${domain}/nginx.ssl.conf_hestia_goaccess_realtime"
			if [[ -f "${include}" ]]; then
				rm -f "${include}"
				printf 'removed: %s\n' "${include}"
				changed_nginx="yes"
			fi
			rm -rf "${db_path:-/var/lib/hestia-goaccess/${user:?}/${domain:?}}" "/run/hestia-goaccess/${user:?}/${domain:?}"
			if [[ -n "${report_path}" ]]; then
				rm -f "${report_path}"
			fi
		fi
	done < <(find /etc/hestia-goaccess/domains -mindepth 2 -maxdepth 2 -type f -name '*.conf' 2>/dev/null | sort)

	while IFS= read -r unit_path; do
		unit="$(basename "${unit_path}")"
		systemctl stop "${unit}" >/dev/null 2>&1 || true
		systemctl disable "${unit}" >/dev/null 2>&1 || true
		rm -f "${unit_path}"
		printf 'removed: %s\n' "${unit_path}"
		changed_units="yes"
	done < <(find /etc/systemd/system -maxdepth 1 -type f -name 'hestia-goaccess-*.service' 2>/dev/null | sort)

	while IFS= read -r include; do
		rm -f "${include}"
		printf 'removed: %s\n' "${include}"
		changed_nginx="yes"
	done < <(find /home \( -path '*/conf/web/*/nginx.conf_hestia_goaccess_realtime' -o -path '*/conf/web/*/nginx.ssl.conf_hestia_goaccess_realtime' \) -type f 2>/dev/null | sort)

	while IFS= read -r include; do
		rm -f "${include}"
		printf 'removed: %s\n' "${include}"
	done < <(find /home \( -path '*/web/*/stats/auth.conf_hestia_goaccess_accesslog_off' -o -path '*/web/*/stats/auth.conf_hestia_goaccess_cache' \) -type f 2>/dev/null | sort)

	if [[ "${changed_units}" == "yes" ]]; then
		systemctl daemon-reload >/dev/null 2>&1 || true
	fi

	if [[ "${changed_nginx}" == "yes" ]] && command -v nginx >/dev/null 2>&1; then
		if nginx -t; then
			systemctl reload nginx >/dev/null 2>&1 || true
		else
			printf 'warning: nginx config test failed after removing hestia-goaccess includes; nginx was not reloaded\n' >&2
		fi
	fi

	rm -rf /var/lib/hestia-goaccess
	rm -rf /run/hestia-goaccess
}

cleanup_realtime_artifacts

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

	reset_addon_domains() {
		local web_conf
		local user
		local line
		local domain
		local stats

		while IFS= read -r web_conf; do
			user="$(basename "$(dirname "${web_conf}")")"
			while IFS= read -r line; do
				domain="$(printf '%s\n' "${line}" | sed -n "s/.*DOMAIN='\\([^']*\\)'.*/\\1/p")"
				stats="$(printf '%s\n' "${line}" | sed -n "s/.* STATS='\\([^']*\\)'.*/\\1/p")"
				[[ -n "${domain}" ]] || continue
				is_addon_type "${stats}" || continue
				/usr/local/hestia/bin/v-delete-web-domain-stats "${user}" "${domain}" >/dev/null 2>&1 || true
				printf 'disabled GoAccess stats: %s/%s\n' "${user}" "${domain}"
			done < "${web_conf}"
		done < <(find /usr/local/hestia/data/users -mindepth 2 -maxdepth 2 -type f -name web.conf 2>/dev/null | sort)
	}

	reset_addon_domains
	restore_wrapper "v-update-web-domain-stat"
	restore_wrapper "v-delete-web-domain-stats"
	restore_wrapper "v-delete-web-domain"
	restore_wrapper "v-delete-user"

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
rm -f /etc/apt/apt.conf.d/99hestia-goaccess-repair
rm -rf "${PREFIX}/share/hestia-goaccess"

if [[ "${REMOVE_STATE}" == "yes" ]]; then
	rm -rf /etc/hestia-goaccess
	printf 'removed state/config: /etc/hestia-goaccess\n'
else
	printf 'kept state/config: /etc/hestia-goaccess\n'
fi

printf 'removed: %s/bin/hestia-goaccess\n' "${PREFIX}"
printf 'removed: /etc/apt/apt.conf.d/99hestia-goaccess-repair\n'
printf 'removed GoAccess databases and generated reports known to hestia-goaccess state\n'
