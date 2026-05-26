#!/usr/bin/env bash
set -euo pipefail

admin_user="${HESTIA_ADMIN_USER:-admin}"
admin_password="${HESTIA_ADMIN_PASSWORD:-admin}"
hostname="${HESTIA_HOSTNAME:-panel.hestia-goaccess.localhost}"
email="${HESTIA_EMAIL:-admin@example.test}"

if [[ -x /usr/local/hestia/bin/v-list-web-stats ]]; then
	echo "Hestia already appears to be installed."
	/usr/local/hestia/bin/v-list-web-stats plain || true
	exit 0
fi

echo "${hostname}" > /etc/hostname
if ! grep -q " ${hostname}" /etc/hosts; then
	printf '127.0.1.1 %s\n' "${hostname}" >> /etc/hosts
fi

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl wget

curl -fsSL https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh \
	-o /root/hst-install.sh
chmod +x /root/hst-install.sh

bash /root/hst-install.sh \
	--hostname "${hostname}" \
	--email "${email}" \
	--username "${admin_user}" \
	--password "${admin_password}" \
	--apache yes \
	--phpfpm yes \
	--multiphp no \
	--vsftpd no \
	--proftpd no \
	--named no \
	--mysql yes \
	--mysql8 no \
	--postgresql no \
	--exim no \
	--dovecot no \
	--sieve no \
	--clamav no \
	--spamassassin no \
	--iptables no \
	--fail2ban no \
	--quota no \
	--api yes \
	--interactive no \
	--force

cat <<INFO

Hestia install attempted.

Panel URL:
  https://panel.hestia-goaccess.localhost:8083/

Internal Hestia hostname:
  ${hostname}

Login:
  ${admin_user}
  ${admin_password}

INFO
