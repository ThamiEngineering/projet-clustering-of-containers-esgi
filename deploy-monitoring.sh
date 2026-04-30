#!/usr/bin/env bash
# =============================================================
# Déploiement de la stack monitoring (Prometheus + Grafana
# + cAdvisor + Node Exporter) sur Docker Swarm
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
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_FILE="${PROJECT_DIR}/stacks/monitoring-stack.yml"

cd "$PROJECT_DIR"

# -------------------------------------------------------------
# 1. Vérifications préalables
# -------------------------------------------------------------
log "Vérification de l'état du cluster Swarm..."
SWARM_INFO=$(docker info 2>/dev/null || true)
if ! echo "$SWARM_INFO" | grep -q "Swarm: active"; then
    err "Le Swarm n'est pas actif."
    exit 1
fi
ok "Swarm actif"

if ! echo "$SWARM_INFO" | grep -q "Is Manager: true"; then
    err "Ce nœud n'est pas un manager."
    exit 1
fi
ok "Nœud manager confirmé"

if ! docker network ls --format '{{.Name}}' | grep -q '^proxy-network$'; then
    err "Le réseau 'proxy-network' n'existe pas."
    err "Déploie d'abord la stack proxy : docker stack deploy -c stacks/reverse-proxy-stack.yml proxy"
    exit 1
fi
ok "Réseau proxy-network détecté"

if [ ! -f "$STACK_FILE" ]; then
    err "Stack file introuvable : $STACK_FILE"
    exit 1
fi

# -------------------------------------------------------------
# 2. Déploiement
# -------------------------------------------------------------
export MONITORING_DIR="${PROJECT_DIR}/monitoring"
log "MONITORING_DIR = $MONITORING_DIR"

log "Déploiement de la stack ${STACK_NAME}..."
docker stack deploy -c "$STACK_FILE" "$STACK_NAME"
ok "Stack ${STACK_NAME} déployée"

# -------------------------------------------------------------
# 3. État final
# -------------------------------------------------------------
echo ""
log "Attente du démarrage des services (20s)..."
sleep 20

echo ""
echo "============================================================="
echo " STATUT DES SERVICES MONITORING"
echo "============================================================="
docker stack services ${STACK_NAME}

echo ""
echo "============================================================="
echo " RÉPARTITION DES TÂCHES"
echo "============================================================="
docker stack ps ${STACK_NAME} --no-trunc

echo ""
ok "Monitoring déployé !"
echo ""
echo "Prochaines étapes :"
echo "  1. NPM -> nouveau Proxy Host : grafana.thami.fr -> grafana:3000 (+ SSL Let's Encrypt)"
echo "  2. Login Grafana : admin / admin (changement de mot de passe au 1er login)"
echo "  3. Dashboards déjà provisionnés : Node Exporter Full, Docker Swarm Cluster Monitoring"
echo ""
