#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

echo "== PROD readiness check =="

if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
  echo "WARNING: il repo PROD non e' su main." >&2
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERRORE: worktree PROD non pulita. Prima del deploy template devi riconciliare le modifiche locali:" >&2
  git status --short >&2
  echo >&2
  echo "Sequenza prudente consigliata:" >&2
  echo "  mkdir -p /tmp/iartnet_proxy_prod_before_template_$(date +%Y%m%d_%H%M%S)" >&2
  echo "  cp -a docker-compose.yml conf.d/default.conf .htpasswd conf.d/default.conf.* /tmp/iartnet_proxy_prod_before_template_.../ 2>/dev/null || true" >&2
  echo "  sudo mkdir -p /etc/iartnet/proxy" >&2
  echo "  sudo cp -a /opt/iartnet_proxy/.htpasswd /etc/iartnet/proxy/.htpasswd" >&2
  echo "  sudo chown root:root /etc/iartnet/proxy/.htpasswd" >&2
  echo "  sudo chmod 640 /etc/iartnet/proxy/.htpasswd" >&2
  echo "  git restore docker-compose.yml conf.d/default.conf" >&2
  echo "  git clean -f conf.d/default.conf.NO_AUTH conf.d/default.conf.bak_* conf.d/default.conf.bak* 2>/dev/null || true" >&2
  exit 10
fi

if [[ ! -f /etc/iartnet/proxy/.htpasswd ]]; then
  echo "ERRORE: manca /etc/iartnet/proxy/.htpasswd." >&2
  echo "Se oggi hai /opt/iartnet_proxy/.htpasswd, copialo fuori repo:" >&2
  echo "  sudo mkdir -p /etc/iartnet/proxy" >&2
  echo "  sudo cp -a /opt/iartnet_proxy/.htpasswd /etc/iartnet/proxy/.htpasswd" >&2
  echo "  sudo chown root:root /etc/iartnet/proxy/.htpasswd" >&2
  echo "  sudo chmod 640 /etc/iartnet/proxy/.htpasswd" >&2
  exit 20
fi

docker compose -f docker-compose.yml -f docker-compose.prod.yml config >/tmp/iartnet_proxy_prod_ready.yml
echo "OK: PROD pronto per ./scripts/deploy-proxy.sh prod"
