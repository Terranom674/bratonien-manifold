#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-/opt/bratonien-manifold/compose.yml}"
OWNER="${OWNER:-terranom674}"
VERSION_PREFIX="${VERSION_PREFIX:-bratonien-v-0-}"

get_latest_tag() {
  local package="$1"
  local url="https://api.github.com/users/${OWNER}/packages/container/${package}/versions?per_page=100"
  local json
  local tag

  json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$url")"

  tag="$(python3 - "$VERSION_PREFIX" <<'PY' <<<"$json"
import json
import re
import sys

prefix = sys.argv[1]
versions = json.load(sys.stdin)
pattern = re.compile(r"^" + re.escape(prefix) + r"(\d+)$")
found = []

for version in versions:
    tags = (((version.get("metadata") or {}).get("container") or {}).get("tags") or [])
    for tag in tags:
        match = pattern.match(tag)
        if match:
            found.append((int(match.group(1)), tag))

if not found:
    raise SystemExit(1)

print(max(found)[1])
PY
)" || {
    echo "Keine verwaltete Version fuer ${package} gefunden." >&2
    exit 1
  }

  printf '%s\n' "$tag"
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

echo "Ermittelte Versionen:"
echo "Client: $CLIENT_TAG"
echo "API:    $API_TAG"

CLIENT_PIN="$(resolve_digest "$CLIENT_IMAGE")"
API_PIN="$(resolve_digest "$API_IMAGE")"

BACKUP="${COMPOSE_FILE}.bak-$(date +%Y%m%d-%H%M%S)"
cp "$COMPOSE_FILE" "$BACKUP"

echo "Backup: $BACKUP"
echo "Client: $CLIENT_PIN"
echo "API:    $API_PIN"

python3 - "$COMPOSE_FILE" "$CLIENT_PIN" "$API_PIN" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
client = sys.argv[2]
api = sys.argv[3]
text = path.read_text()

services = {
    "init": api,
    "web": api,
    "worker": api,
    "client": client,
}

for service, image in services.items():
    pattern = rf"(?ms)(^  {re.escape(service)}:\n.*?^    image: )[^\n]+"
    text, count = re.subn(pattern, rf"\g<1>{image}", text, count=1)
    if count != 1:
        raise SystemExit(f"Image-Zeile fuer Service '{service}' konnte nicht eindeutig ersetzt werden.")

path.write_text(text)
PY

docker compose -f "$COMPOSE_FILE" config >/dev/null

echo "Compose-Konfiguration gueltig."

echo "Starte Datenbank-Upgrade..."
docker compose -f "$COMPOSE_FILE" run --rm init

echo "Erstelle Client, Web und Worker neu..."
docker compose -f "$COMPOSE_FILE" up -d --force-recreate client web worker

echo
echo "Aktiver Stand:"
docker compose -f "$COMPOSE_FILE" ps
