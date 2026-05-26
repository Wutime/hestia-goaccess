#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${repo_root}/scripts/dev-smoke.sh"

exec nginx -c "${repo_root}/docker/dev/nginx.conf" -g "daemon off;"

