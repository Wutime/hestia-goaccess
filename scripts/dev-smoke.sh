#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="${repo_root}/docker/fixtures/hestia"
stats_dir="${fixture_root}/home/admin/web/example.test/stats"
log_file="${fixture_root}/var/log/nginx/domains/example.test.log"
report="${stats_dir}/index.html"

mkdir -p "${stats_dir}"
rm -f "${report}"

bash -n "${repo_root}/install.sh"
bash -n "${repo_root}/uninstall.sh"
bash -n "${repo_root}/bin/hestia-goaccess"
bash -n "${repo_root}/scripts/check-goaccess-version.sh"
bash -n "${repo_root}/scripts/hestia-goaccess-filter-log"
bash -n "${repo_root}/scripts/install-goaccess-debian.sh"
bash -n "${repo_root}/patches/hestia/v-update-web-domain-stat.wrapper"

if command -v shellcheck >/dev/null 2>&1; then
	shellcheck -x \
		"${repo_root}/install.sh" \
		"${repo_root}/uninstall.sh" \
		"${repo_root}/bin/hestia-goaccess" \
		"${repo_root}/scripts/check-goaccess-version.sh" \
		"${repo_root}/scripts/hestia-goaccess-filter-log" \
		"${repo_root}/scripts/install-goaccess-debian.sh" \
		"${repo_root}/patches/hestia/v-update-web-domain-stat.wrapper" \
		"${BASH_SOURCE[0]}"
fi

"${repo_root}/scripts/check-goaccess-version.sh"

goaccess "${log_file}" \
	--log-format=COMBINED \
	--anonymize-ip \
	--no-query-string \
	--output="${report}" \
	--ignore-crawlers \
	--html-report-title="example.test GoAccess Smoke"

test -s "${report}"
grep -q "example.test GoAccess Smoke" "${report}"

echo "dev smoke passed: ${report}"
echo "report URL: http://goaccess.localhost:18080/vstats/"
