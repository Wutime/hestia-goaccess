#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../conf/defaults.conf
source "${repo_root}/conf/defaults.conf"

version_ge() {
	local current="$1"
	local minimum="$2"
	local first

	first="$(printf '%s\n%s\n' "${minimum}" "${current}" | sort -V | head -n 1)"
	[[ "${first}" == "${minimum}" ]]
}

if ! command -v goaccess >/dev/null 2>&1; then
	printf 'goaccess is not installed; minimum required version is %s\n' "${GOACCESS_MIN_VERSION}" >&2
	exit 1
fi

version="$(goaccess --version | sed -n 's/^GoAccess - \([0-9][0-9.]*\).*/\1/p' | head -n 1)"
if [[ -z "${version}" ]]; then
	printf 'unable to determine goaccess version from: %s\n' "$(goaccess --version | head -n 1)" >&2
	exit 1
fi

if ! version_ge "${version}" "${GOACCESS_MIN_VERSION}"; then
	printf 'goaccess %s is too old; minimum required version is %s\n' "${version}" "${GOACCESS_MIN_VERSION}" >&2
	exit 1
fi

printf 'goaccess %s satisfies minimum %s\n' "${version}" "${GOACCESS_MIN_VERSION}"

