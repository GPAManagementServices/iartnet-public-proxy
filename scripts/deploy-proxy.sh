#!/usr/bin/env bash
set -Eeuo pipefail

ENVIRONMENT="${1:-}"
SERVICE_NAME="reverse_proxy"
CONTAINER_NAME="iartnet_reverse_proxy"

if [[ "$ENVIRONMENT" != "stg" && "$ENVIRONMENT" != "prod" ]]; then
  echo "Uso: $0 stg|prod" >&2
  exit 2
fi

cd "$(dirname "$0")/.."

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERRORE: ci sono modifiche locali non committate." >&2
  git status --short >&2
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    echo >&2
    echo "Su PROD questo e' atteso se hai ancora le modifiche locali storiche." >&2
    echo "Prima fai backup/copia .htpasswd fuori repo e riconcilia la working tree." >&2
    echo "Puoi usare: ./scripts/check-prod-ready.sh" >&2
  fi
  exit 10
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "$CURRENT_BRANCH" != "HEAD" ]] || { echo "ERRORE: repository in detached HEAD." >&2; exit 11; }

git fetch origin
git pull --ff-only origin "$CURRENT_BRANCH"

if [[ "$ENVIRONMENT" == "prod" && ! -f /etc/iartnet/proxy/.htpasswd ]]; then
  echo "ERRORE: manca /etc/iartnet/proxy/.htpasswd su PROD." >&2
  echo "Crea il file fuori repository prima del deploy PROD." >&2
  echo "Se oggi esiste /opt/iartnet_proxy/.htpasswd:" >&2
  echo "  sudo mkdir -p /etc/iartnet/proxy" >&2
  echo "  sudo cp -a /opt/iartnet_proxy/.htpasswd /etc/iartnet/proxy/.htpasswd" >&2
  echo "  sudo chown root:root /etc/iartnet/proxy/.htpasswd" >&2
  echo "  sudo chmod 640 /etc/iartnet/proxy/.htpasswd" >&2
  exit 20
fi

docker compose -f docker-compose.yml -f "docker-compose.${ENVIRONMENT}.yml" config > "/tmp/iartnet_proxy_${ENVIRONMENT}.yml"
docker compose -f docker-compose.yml -f "docker-compose.${ENVIRONMENT}.yml" run --rm --no-deps --name "iartnet_reverse_proxy_configtest_${ENVIRONMENT}_$(date +%Y%m%d_%H%M%S)" "$SERVICE_NAME" nginx -t
docker compose -f docker-compose.yml -f "docker-compose.${ENVIRONMENT}.yml" up -d --force-recreate "$SERVICE_NAME"
docker exec "$CONTAINER_NAME" nginx -t
docker exec "$CONTAINER_NAME" sh -lc "test -f /etc/nginx/templates/default.conf.template"
docker exec "$CONTAINER_NAME" sh -lc "grep -q 'Environment: ${ENVIRONMENT}' /etc/nginx/conf.d/default.conf"
