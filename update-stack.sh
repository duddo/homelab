#!/usr/bin/env bash
# Aggiorna le immagini di uno stack podman-compose e ricrea i container.
# Uso: ./update-stack.sh [cartella-stack]   (default: cartella corrente)
# Es.: ./update-stack.sh ricotta/streaming
set -euo pipefail

dir="${1:-.}"
cd "$dir"
[ -f podman-compose.yml ] || { echo "podman-compose.yml non trovato in $PWD" >&2; exit 1; }

name="$(basename "$PWD")"
unit="podman-compose@${name}"

podman-compose pull

if systemctl --user is-enabled --quiet "$unit" 2>/dev/null || systemctl --user is-active --quiet "$unit" 2>/dev/null; then
  systemctl --user stop "$unit"
  podman-compose down
  systemctl --user start "$unit"
else
  podman-compose up -d
fi

podman image prune -f
