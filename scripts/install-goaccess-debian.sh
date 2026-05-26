#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${repo_root}/conf/defaults.conf"

if [[ "${EUID}" -ne 0 ]]; then
	echo "install-goaccess-debian.sh must be run as root" >&2
	exit 1
fi

version_ge() {
	local current="$1"
	local minimum="$2"
	local first

	first="$(printf '%s\n%s\n' "${minimum}" "${current}" | sort -V | head -n 1)"
	[[ "${first}" == "${minimum}" ]]
}

installed_version() {
	goaccess --version 2>/dev/null |
		sed -n 's/^GoAccess - \([0-9][0-9.]*[0-9]\).*/\1/p' |
		head -n 1
}

if command -v goaccess >/dev/null 2>&1; then
	version="$(installed_version)"
	if [[ -n "${version}" ]] && version_ge "${version}" "${GOACCESS_MIN_VERSION}"; then
		echo "goaccess ${version} already satisfies minimum ${GOACCESS_MIN_VERSION}"
		exit 0
	fi
	echo "goaccess ${version:-unknown} is older than required ${GOACCESS_MIN_VERSION}; installing from official GoAccess repository"
fi

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release

install -d -m 0755 /usr/share/keyrings
rm -f /usr/share/keyrings/goaccess.gpg
curl -fsSL https://deb.goaccess.io/gnugpg.key |
	gpg --dearmor -o /usr/share/keyrings/goaccess.gpg
chmod 0644 /usr/share/keyrings/goaccess.gpg

codename="$(lsb_release -cs)"
arch="$(dpkg --print-architecture)"
cat > /etc/apt/sources.list.d/goaccess.list <<APT
deb [signed-by=/usr/share/keyrings/goaccess.gpg arch=${arch}] https://deb.goaccess.io/ ${codename} main
APT

apt-get update
apt-get install -y --no-install-recommends goaccess

"${repo_root}/scripts/check-goaccess-version.sh"
