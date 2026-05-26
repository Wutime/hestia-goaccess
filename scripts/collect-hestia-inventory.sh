#!/usr/bin/env bash
set -euo pipefail

print_section() {
	printf '\n## %s\n' "$1"
}

run_if() {
	local label="$1"
	shift

	printf '\n### %s\n' "${label}"
	if command -v "$1" >/dev/null 2>&1 || [[ "$1" == /* || "$1" == ./* ]]; then
		"$@" 2>&1 || true
	else
		printf 'command not found: %s\n' "$1"
	fi
}

print_section "Host"
run_if "date" date -u
run_if "uname" uname -a
if [[ -r /etc/os-release ]]; then
	printf '\n### /etc/os-release\n'
	sed -n '1,80p' /etc/os-release
fi

print_section "Hestia"
if [[ -r /etc/hestiacp/hestia.conf ]]; then
	printf '\n### /etc/hestiacp/hestia.conf selected values\n'
	grep -E '^(HESTIA|BIN|WEB_SYSTEM|WEB_BACKEND|PROXY_SYSTEM|STATS_SYSTEM|WEB_PORT|WEB_SSL_PORT|PROXY_PORT|PROXY_SSL_PORT|HOMEDIR)=' /etc/hestiacp/hestia.conf || true
else
	printf '\n### /etc/hestiacp/hestia.conf\nnot readable\n'
fi

if [[ -x /usr/local/hestia/bin/v-list-sys-hestia-updates ]]; then
	run_if "Hestia updates/version" /usr/local/hestia/bin/v-list-sys-hestia-updates plain
fi
if [[ -x /usr/local/hestia/bin/v-list-web-stats ]]; then
	run_if "Hestia web stats" /usr/local/hestia/bin/v-list-web-stats plain
fi

print_section "Web Stack"
run_if "nginx version" nginx -v
run_if "apache version" apache2 -v
run_if "goaccess version" goaccess --version
run_if "systemctl nginx/apache status" systemctl is-active nginx apache2

print_section "Ports"
if [[ -r /proc/sys/net/ipv4/ip_local_port_range ]]; then
	printf '\n### IPv4 ephemeral port range\n'
	cat /proc/sys/net/ipv4/ip_local_port_range
fi
run_if "listening TCP ports" ss -ltnp

print_section "Templates"
for path in \
	/usr/local/hestia/data/templates/web/nginx/default.tpl \
	/usr/local/hestia/data/templates/web/nginx/default.stpl \
	/usr/local/hestia/data/templates/web/nginx/php-fpm/default.tpl \
	/usr/local/hestia/data/templates/web/nginx/php-fpm/default.stpl \
	/usr/local/hestia/data/templates/web/apache2/default.tpl \
	/usr/local/hestia/data/templates/web/apache2/default.stpl
do
	if [[ -e "${path}" ]]; then
		printf '%s\n' "${path}"
	fi
done

print_section "Domain Sample"
if [[ -n "${1:-}" && -n "${2:-}" && -x /usr/local/hestia/bin/v-list-web-domain ]]; then
	run_if "v-list-web-domain $1 $2" /usr/local/hestia/bin/v-list-web-domain "$1" "$2" json
	domain_conf="/home/$1/conf/web/$2"
	if [[ -d "${domain_conf}" ]]; then
		printf '\n### domain conf files\n'
		find "${domain_conf}" -maxdepth 1 -type f -printf '%f\n' | sort
	fi
else
	printf '\n### domain sample\n'
	printf 'pass USER DOMAIN to include a specific domain inventory\n'
fi

