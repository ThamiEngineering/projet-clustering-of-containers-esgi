#!/usr/bin/env bash
# =============================================================
# Script de déploiement de la stack multiweb-stack sur Swarm
#
# Usage : ./deploy.sh
#
# Pré-requis :
#   - Cluster Swarm initialisé (1 manager + 2 workers)
#   - Le projet est cloné sur le manager dans le répertoire courant
#   - Docker daemon accessible
# =============================================================

set -euo pipefail

# Couleurs pour les messages
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
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    err "Le Swarm n'est pas actif. Lance 'docker swarm init' sur le manager d'abord."
    exit 1
fi
ok "Swarm actif"

if ! docker info 2>/dev/null | grep -q "Is Manager: true"; then
    err "Ce nœud n'est pas un manager. Exécute ce script sur swarm-master."
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
# 3. Distribution des images aux workers
#    (Swarm n'a pas de registre embarqué : on save/load via SSH)
#    Pour ce projet on utilise une astuce : on tag les images avec
#    "localhost/" et on les distribue manuellement aux workers.
#
#    Plus propre : monter un registre privé. Pour l'école, on simplifie.
# -------------------------------------------------------------
log "Distribution des images aux workers..."
WORKERS=$(docker node ls --filter role=worker --format '{{.Hostname}}')

if [ -z "$WORKERS" ]; then
    warn "Aucun worker détecté, les images resteront seulement sur le manager"
else
    for IMAGE in user-service task-service web-frontend; do
        log "  -> Export de $IMAGE..."
        docker save "localhost/${IMAGE}:latest" -o "/tmp/${IMAGE}.tar"

        for WORKER in $WORKERS; do
            # On suppose que les hostnames résolvent ou que l'utilisateur a
            # configuré /etc/hosts. Sinon, modifier ce script avec les IP privées.
            log "     -> Transfert vers $WORKER..."
            scp -o StrictHostKeyChecking=no "/tmp/${IMAGE}.tar" "root@${WORKER}:/tmp/${IMAGE}.tar" || \
                warn "Impossible de transférer vers $WORKER (vérifie SSH/DNS)"
            ssh -o StrictHostKeyChecking=no "root@${WORKER}" "docker load -i /tmp/${IMAGE}.tar && rm /tmp/${IMAGE}.tar" || \
                warn "Impossible de charger l'image sur $WORKER"
        done

        rm -f "/tmp/${IMAGE}.tar"
    done
    ok "Images distribuées"
fi

# -------------------------------------------------------------
# 4. Déploiement de la stack reverse-proxy (NPM) si pas déjà là
# -------------------------------------------------------------
if ! docker stack ls --format '{{.Name}}' | grep -q "^${PROXY_STACK_NAME}$"; then
    log "Déploiement du reverse proxy (Nginx Proxy Manager)..."
    docker stack deploy -c stacks/reverse-proxy-stack.yml ${PROXY_STACK_NAME}
    ok "Stack proxy déployée. Admin UI : http://$(hostname -I | awk '{print $1}'):81"
else
    ok "Stack proxy déjà déployée"
fi

# -------------------------------------------------------------
# 5. Déploiement de la stack applicative
# -------------------------------------------------------------
log "Déploiement de la stack ${STACK_NAME}..."
export INIT_SQL_PATH="${PROJECT_DIR}/db"
docker stack deploy -c docker-compose.prod.yml ${STACK_NAME}
ok "Stack ${STACK_NAME} déployée"

# -------------------------------------------------------------
# 6. Affichage de l'état
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
echo "  1. Configure Nginx Proxy Manager sur http://<master-ip>:81"
echo "     (login par défaut : admin@example.com / changeme)"
echo "  2. Crée un proxy host pour projet-esgi.thami.fr"
echo "     -> forward vers : web-frontend:80"
echo "  3. Active SSL via Let's Encrypt dans NPM"
echo ""
