#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-/opt/bratonien-manifold/compose.yml}"
OWNER="${OWNER:-terranom674}"
VERSION_PREFIX="${VERSION_PREFIX:-bratonien-v-0-}"
PROJECT_NAME="${PROJECT_NAME:-bratonien-manifold}"

get_latest_tag() {
  local package="$1"
  local scope="repository:${OWNER}/${package}:pull"
  local token_json
  local token
  local tags_json
  local tag

  token_json="$(curl -fsSL "https://ghcr.io/token?scope=${scope}")"
  token="$(printf '%s' "$token_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')"

  if [[ -z "$token" ]]; then
    echo "Anonymer GHCR-Lesetoken fuer ${package} konnte nicht ermittelt werden." >&2
    exit 1
  fi

  tags_json="$(curl -fsSL \
    -H "Authorization: Bearer ${token}" \
    "https://ghcr.io/v2/${OWNER}/${package}/tags/list")"

  tag="$(printf '%s' "$tags_json" | python3 -c '
import json
import re
import sys

prefix = sys.argv[1]
data = json.load(sys.stdin)
pattern = re.compile(r"^" + re.escape(prefix) + r"(\d+)$")
found = []

for tag in data.get("tags") or []:
    match = pattern.match(tag)
    if match:
        found.append((int(match.group(1)), tag))

if not found:
    raise SystemExit(1)

print(max(found)[1])
' "$VERSION_PREFIX")" || {
    echo "Keine verwaltete Version fuer ${package} gefunden." >&2
    exit 1
  }

  printf '%s\n' "$tag"
}

get_compose_image() {
  local service="$1"
  python3 - "$COMPOSE_FILE" "$service" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
service = sys.argv[2]
text = path.read_text()
pattern = rf"(?ms)^  {re.escape(service)}:\n.*?^    image: ([^\n]+)"
match = re.search(pattern, text)
if not match:
    raise SystemExit(1)
print(match.group(1).strip())
PY
}

get_running_image() {
  local service="$1"
  local container="${PROJECT_NAME}-${service}-1"

  if ! docker container inspect "$container" >/dev/null 2>&1; then
    printf '%s\n' ""
    return 0
  fi

  docker container inspect "$container" --format '{{.Config.Image}}'
}

resolve_digest() {
  local image="$1"
  local digest

  docker pull "$image" >/dev/null
  digest="$(docker image inspect "$image" --format '{{index .RepoDigests 0}}')"

  if [[ -z "$digest" || "$digest" == "<no value>" ]]; then
    echo "Digest konnte nicht ermittelt werden: $image" >&2
    exit 1
  fi

  printf '%s\n' "$digest"
}

CLIENT_TAG="${1:-}"
API_TAG="${2:-}"

if [[ -z "$CLIENT_TAG" ]]; then
  CLIENT_TAG="$(get_latest_tag bratonien-manifold-client)"
fi

if [[ -z "$API_TAG" ]]; then
  API_TAG="$(get_latest_tag bratonien-manifold-api)"
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Compose-Datei nicht gefunden: $COMPOSE_FILE" >&2
  exit 1
fi

CLIENT_IMAGE="ghcr.io/${OWNER}/bratonien-manifold-client:${CLIENT_TAG}"
API_IMAGE="ghcr.io/${OWNER}/bratonien-manifold-api:${API_TAG}"

CLIENT_PIN="$(resolve_digest "$CLIENT_IMAGE")"
API_PIN="$(resolve_digest "$API_IMAGE")"

CLIENT_COMPOSE="$(get_compose_image client)"
INIT_COMPOSE="$(get_compose_image init)"
WEB_COMPOSE="$(get_compose_image web)"
WORKER_COMPOSE="$(get_compose_image worker)"

CLIENT_RUNNING="$(get_running_image client)"
WEB_RUNNING="$(get_running_image web)"
WORKER_RUNNING="$(get_running_image worker)"

CLIENT_CHANGED=0
API_CHANGED=0
COMPOSE_CHANGED=0

if [[ "$CLIENT_COMPOSE" != "$CLIENT_PIN" || "$CLIENT_RUNNING" != "$CLIENT_PIN" ]]; then
  CLIENT_CHANGED=1
fi

if [[ "$INIT_COMPOSE" != "$API_PIN" || "$WEB_COMPOSE" != "$API_PIN" || "$WORKER_COMPOSE" != "$API_PIN" || "$WEB_RUNNING" != "$API_PIN" || "$WORKER_RUNNING" != "$API_PIN" ]]; then
  API_CHANGED=1
fi

if [[ "$CLIENT_COMPOSE" != "$CLIENT_PIN" || "$INIT_COMPOSE" != "$API_PIN" || "$WEB_COMPOSE" != "$API_PIN" || "$WORKER_COMPOSE" != "$API_PIN" ]]; then
  COMPOSE_CHANGED=1
fi

echo "Ermittelte Versionen:"
echo "Client: $CLIENT_TAG"
echo "API:    $API_TAG"

if [[ "$CLIENT_CHANGED" -eq 0 ]]; then
  echo "Client: aktuell"
else
  echo "Client: Update erforderlich"
fi

if [[ "$API_CHANGED" -eq 0 ]]; then
  echo "API:    aktuell"
else
  echo "API:    Update erforderlich"
fi

if [[ "$CLIENT_CHANGED" -eq 0 && "$API_CHANGED" -eq 0 ]]; then
  echo "Keine Aktualisierung notwendig."
  exit 0
fi

if [[ "$COMPOSE_CHANGED" -eq 1 ]]; then
  BACKUP="${COMPOSE_FILE}.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$COMPOSE_FILE" "$BACKUP"
  echo "Backup: $BACKUP"

  python3 - "$COMPOSE_FILE" "$CLIENT_PIN" "$API_PIN" "$CLIENT_CHANGED" "$API_CHANGED" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
client = sys.argv[2]
api = sys.argv[3]
client_changed = sys.argv[4] == "1"
api_changed = sys.argv[5] == "1"
text = path.read_text()

services = {}
if client_changed:
    services["client"] = client
if api_changed:
    services.update({"init": api, "web": api, "worker": api})

for service, image in services.items():
    pattern = rf"(?ms)(^  {re.escape(service)}:\n.*?^    image: )[^\n]+"
    text, count = re.subn(pattern, rf"\g<1>{image}", text, count=1)
    if count != 1:
        raise SystemExit(f"Image-Zeile fuer Service '{service}' konnte nicht eindeutig ersetzt werden.")

path.write_text(text)
PY

  docker compose -f "$COMPOSE_FILE" config >/dev/null
  echo "Compose-Konfiguration gueltig."
fi

if [[ "$API_CHANGED" -eq 1 ]]; then
  echo "Starte Datenbank-Upgrade..."
  docker compose -f "$COMPOSE_FILE" run --rm -T init </dev/null

  echo "Erstelle Web und Worker neu..."
  docker compose -f "$COMPOSE_FILE" up -d --force-recreate web worker
fi

if [[ "$CLIENT_CHANGED" -eq 1 ]]; then
  echo "Erstelle Client neu..."
  docker compose -f "$COMPOSE_FILE" up -d --force-recreate client
fi

echo
echo "Aktiver Stand:"
docker compose -f "$COMPOSE_FILE" ps
