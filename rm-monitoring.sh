#!/usr/bin/env bash
# =============================================================
# Suppression de la stack monitoring
# Par défaut conserve les volumes (prometheus-data, grafana-data).
# Passer --purge pour les supprimer aussi.
# =============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[FAIL]${NC} $1"; }

STACK_NAME="monitoring"
PURGE_VOLUMES="false"

for arg in "$@"; do
    case "$arg" in
        --purge) PURGE_VOLUMES="true" ;;
        -h|--help)
            echo "Usage : $0 [--purge]"
            echo "  --purge  Supprime aussi les volumes prometheus-data et grafana-data"
            exit 0
            ;;
    esac
done

if ! docker stack ls --format '{{.Name}}' | grep -q "^${STACK_NAME}$"; then
    warn "Stack '${STACK_NAME}' non déployée."
    exit 0
fi

log "Suppression de la stack ${STACK_NAME}..."
docker stack rm "${STACK_NAME}"
ok "Stack ${STACK_NAME} supprimée"

log "Attente de l'arrêt complet des tâches (15s)..."
sleep 15

if [ "$PURGE_VOLUMES" = "true" ]; then
    warn "Suppression des volumes (les données seront perdues)..."
    for VOL in "${STACK_NAME}_prometheus-data" "${STACK_NAME}_grafana-data"; do
        if docker volume ls --format '{{.Name}}' | grep -q "^${VOL}$"; then
            docker volume rm "${VOL}" && ok "Volume ${VOL} supprimé" || warn "Échec suppression ${VOL} (encore utilisé ?)"
        fi
    done
else
    log "Volumes conservés. Pour les supprimer : $0 --purge"
fi

ok "Nettoyage monitoring terminé."
