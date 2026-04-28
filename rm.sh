#!/usr/bin/env bash
# =============================================================
# Script de nettoyage de la stack
# Usage : ./rm.sh [--all]
#   sans option  : supprime la stack applicative seulement
#   --all        : supprime AUSSI le reverse proxy + volumes
# =============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${YELLOW}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $1"; }

STACK_NAME="multiweb-stack"
PROXY_STACK_NAME="proxy"

log "Suppression de la stack ${STACK_NAME}..."
docker stack rm ${STACK_NAME} 2>/dev/null || true

log "Attente de la fin de suppression (10s)..."
sleep 10

if [[ "${1:-}" == "--all" ]]; then
    log "Suppression du reverse proxy ${PROXY_STACK_NAME}..."
    docker stack rm ${PROXY_STACK_NAME} 2>/dev/null || true
    sleep 5

    log "Suppression des volumes (données BDD + NPM perdues !)..."
    docker volume rm ${STACK_NAME}_postgres-data 2>/dev/null || true
    docker volume rm ${PROXY_STACK_NAME}_npm-data 2>/dev/null || true
    docker volume rm ${PROXY_STACK_NAME}_npm-letsencrypt 2>/dev/null || true
    ok "Tout est nettoyé"
else
    ok "Stack applicative supprimée. Volume postgres-data conservé (persistance)."
    echo "    Pour tout supprimer : ./rm.sh --all"
fi
