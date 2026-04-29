#!/usr/bin/env bash
# =============================================================
# Script de déploiement de la stack multiweb-stack sur Swarm
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

STACK_NAME="multiweb-stack"
PROXY_STACK_NAME="proxy"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# -------------------------------------------------------------
# 2. Build des images locales
# -------------------------------------------------------------
log "Construction des images Docker..."
docker build -t localhost/user-service:latest ./user-service
docker build -t localhost/task-service:latest ./task-service
docker build -t localhost/web-frontend:latest ./web-frontend
ok "Images construites"

# -------------------------------------------------------------
# 3. Distribution des images aux workers via leur IP privée
# -------------------------------------------------------------
log "Récupération des IPs privées des workers via 'docker node inspect'..."
WORKER_IPS=()
for NODE_ID in $(docker node ls --filter role=worker --format '{{.ID}}'); do
    IP=$(docker node inspect "$NODE_ID" --format '{{.Status.Addr}}')
    WORKER_IPS+=("$IP")
done

if [ ${#WORKER_IPS[@]} -eq 0 ]; then
    warn "Aucun worker détecté"
else
    log "Workers détectés : ${WORKER_IPS[*]}"
    for IMAGE in user-service task-service web-frontend; do
        log "  -> Export de $IMAGE..."
        docker save "localhost/${IMAGE}:latest" -o "/tmp/${IMAGE}.tar"

        for IP in "${WORKER_IPS[@]}"; do
            log "     -> Transfert vers $IP..."
            scp -o StrictHostKeyChecking=accept-new -q "/tmp/${IMAGE}.tar" "root@${IP}:/tmp/${IMAGE}.tar"
            ssh -o StrictHostKeyChecking=accept-new "root@${IP}" "docker load -i /tmp/${IMAGE}.tar && rm /tmp/${IMAGE}.tar" > /dev/null
        done

        rm -f "/tmp/${IMAGE}.tar"
    done
    ok "Images distribuées sur tous les workers"
fi

# -------------------------------------------------------------
# 4. Stack reverse proxy
# -------------------------------------------------------------
if ! docker stack ls --format '{{.Name}}' | grep -q "^${PROXY_STACK_NAME}$"; then
    log "Déploiement du reverse proxy (Nginx Proxy Manager)..."
    docker stack deploy -c stacks/reverse-proxy-stack.yml ${PROXY_STACK_NAME}
    ok "Stack proxy déployée"
else
    ok "Stack proxy déjà déployée"
fi

# -------------------------------------------------------------
# 5. Stack applicative
# -------------------------------------------------------------
log "Déploiement de la stack ${STACK_NAME}..."
export INIT_SQL_PATH="${PROJECT_DIR}/db"
docker stack deploy -c docker-compose.prod.yml ${STACK_NAME}
ok "Stack ${STACK_NAME} déployée"

# -------------------------------------------------------------
# 6. État final
# -------------------------------------------------------------
echo ""
log "Attente du démarrage des services (30s)..."
sleep 30

echo ""
echo "============================================================="
echo " STATUT DES NŒUDS"
echo "============================================================="
docker node ls

echo ""
echo "============================================================="
echo " STATUT DES SERVICES"
echo "============================================================="
docker stack services ${STACK_NAME}

echo ""
echo "============================================================="
echo " RÉPARTITION DES TÂCHES"
echo "============================================================="
docker stack ps ${STACK_NAME} --no-trunc

echo ""
ok "Déploiement terminé !"
echo ""
echo "Prochaines étapes :"
echo "  1. Configure NPM sur http://$(curl -s ifconfig.me):81"
echo "     (login par défaut : admin@example.com / changeme)"
echo "  2. Crée un proxy host pour projet-esgi.thami.fr"
echo "     -> forward vers : web-frontend:80"
echo "  3. Active SSL via Let's Encrypt dans NPM"
echo ""
