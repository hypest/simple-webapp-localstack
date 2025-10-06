#!/bin/bash
set -euo pipefail

# Stop and remove application containers only.
# Criteria:
# - image name contains 'rails-counter-app'
# - OR container name starts with 'rails'

echo "Scanning for app containers to stop (image contains 'rails-counter-app' or name starts with 'rails')..."

mapfile -t CONTAINERS < <(docker ps --format '{{.ID}} {{.Image}} {{.Names}}' | while read -r id image name; do
  # skip known infra images if they somehow match
  case "$image" in
    *localstack*|registry:*|redis*|redis:*)
      continue
      ;;
  esac

  if echo "$image" | grep -q 'rails-counter-app'; then
    echo "$id"
    continue
  fi

  if [[ "$name" =~ ^rails ]]; then
    echo "$id"
    continue
  fi
done)

if [ ${#CONTAINERS[@]} -eq 0 ]; then
  echo "No application containers found. Nothing to do."
  exit 0
fi

echo "Found application containers to stop:"
for id in "${CONTAINERS[@]}"; do
  docker ps --filter id=$id --format '  - {{.ID}}	{{.Names}}	{{.Image}}'
done

read -r -p "Stop and remove these containers? [y/N] " reply || true
case "$reply" in
  [yY]|[yY][eE][sS])
    ;;
  *)
    echo "Aborted by user. No containers stopped."
    exit 0
    ;;
esac

echo "Stopping containers..."
docker stop "${CONTAINERS[@]}"
echo "Removing containers..."
docker rm "${CONTAINERS[@]}" || true

echo "Done."
