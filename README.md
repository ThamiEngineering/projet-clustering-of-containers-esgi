# Projet ESGI – Clusterisation de containers

[![CI](https://github.com/ThamiEngineering/projet-clustering-of-containers-esgi/actions/workflows/ci.yml/badge.svg)](https://github.com/ThamiEngineering/projet-clustering-of-containers-esgi/actions/workflows/ci.yml)

> **Projet final IW1 T2** – Orchestration d'une application microservices sur un cluster Docker Swarm

---

## Table des matières

- [Contexte](#-contexte)
- [Architecture](#-architecture)
- [Stack technique](#-stack-technique)
- [Pré-requis](#-pré-requis)
- [Installation pas à pas](#-installation-pas-à-pas)
- [Déploiement de l'application](#-déploiement-de-lapplication)
- [Configuration HTTPS (Nginx Proxy Manager)](#-configuration-https-nginx-proxy-manager)
- [Tests de haute disponibilité](#-tests-de-haute-disponibilité)
- [Démonstration des bonus](#-démonstration-des-bonus)
- [Nettoyage](#-nettoyage)
- [Dépannage](#-dépannage)

---

## Contexte

Ce projet implémente une **application ToDo** composée de plusieurs microservices, déployée sur un **cluster Docker Swarm** de 3 nœuds (1 manager + 2 workers).

**Objectifs validés :**

| Critère | Points | Statut |
|---|---|---|
| Cluster (1 master + 2 workers) | 2 | ✅ |
| Déploiement (front, back, BDD conteneurisés) | 5 | ✅ |
| Persistance (volumes, BDD survit) | 2 | ✅ |
| Sécurité (secrets, HTTPS) | 2 | ✅ |
| Exposition (Reverse Proxy + DNS) | 2 | ✅ |
| Documentation & scripts | 2 | ✅ |
| ** Bonus 1** : Resources limits & reservations | +1 | ✅ |
| ** Bonus 2** : Placement constraints | +1 | ✅ |
| ** Bonus 3** : Rolling update + rollback automatique | +1 | ✅ |
| ** Bonus 6** : CI/CD (GitHub Actions – lint, test, scan, build, push) | +1 | ✅ |

---

## Architecture

```
                          ┌──────────────────────┐
                          │  Internet (HTTPS)    │
                          │  projet-esgi.thami.fr│
                          └──────────┬───────────┘
                                     │ :443
                                     ▼
       ┌───────────────────────────────────────────────────┐
       │                  swarm-master                     │
       │  ┌─────────────────────────────────────────────┐  │
       │  │  Nginx Proxy Manager (HTTPS / Let's Encrypt)│  │
       │  └────────────────┬────────────────────────────┘  │
       │                   │                                │
       │  ┌────────────────▼─────────────┐                  │
       │  │  PostgreSQL 16 (×1, manager) │                  │
       │  │  Volume : postgres-data      │                  │
       │  └──────────────────────────────┘                  │
       └───────────────────┬───────────────────────────────┘
                           │ overlay network "todo-network"
              ┌────────────┼────────────┐
              ▼                         ▼
       ┌───────────────┐         ┌───────────────┐
       │ swarm-worker-1│         │ swarm-worker-2│
       │               │         │               │
       │ web-frontend  │         │ web-frontend  │
       │ user-service  │         │ user-service  │
       │ task-service  │         │ task-service  │
       └───────────────┘         └───────────────┘
              ▲                         ▲
              └─── web-frontend ×3 ─────┘
              └─── user-service ×2 ─────┘
              └─── task-service ×2 ─────┘
```

**Distribution des replicas :**

| Service | Replicas | Placement |
|---|---|---|
| `web-frontend` (PHP) | 3 | workers (contrainte) |
| `user-service` (Node.js) | 2 | workers (contrainte) |
| `task-service` (Flask) | 2 | workers (contrainte) |
| `postgres` (PostgreSQL 16) | 1 | manager (contrainte, persistance) |

---

## Stack technique

- **Orchestration** : Docker Swarm
- **OS serveurs** : Debian 12
- **Frontend** : PHP 8.2 + Apache
- **User-service** : Node.js 22 (Express + pg)
- **Task-service** : Python 3.12 (Flask + psycopg2)
- **Base de données** : PostgreSQL 16 Alpine
- **Reverse proxy** : Nginx Proxy Manager (jc21/nginx-proxy-manager)
- **TLS** : Let's Encrypt (automatique via NPM)
- **DNS** : IONOS (`thami.fr`)

---

## Pré-requis

### Sur les 3 serveurs (1 manager + 2 workers)
- Debian 12 ou Ubuntu 22.04+
- Docker CE (≥ 24.x) avec plugin Compose
- Ports ouverts entre les nœuds : `2377/tcp`, `7946/tcp+udp`, `4789/udp`
- Ports ouverts vers Internet sur le manager : `80`, `443`, `81` (admin NPM)

### DNS
- Nom de domaine pointant vers l'IP publique du manager
- Pour ce projet : `projet-esgi.thami.fr` et `npm.thami.fr` → `<IP_MASTER>`

---

## Installation pas à pas

### 1. Provisionner les 3 serveurs

3 droplets DigitalOcean (ou tout autre VPS) sous Debian 12 :
- `swarm-master` : 2 GB RAM, 1 vCPU
- `swarm-worker-1` : 1 GB RAM, 1 vCPU
- `swarm-worker-2` : 1 GB RAM, 1 vCPU

### 2. Installer Docker (sur les 3 serveurs)

```bash
apt update && apt upgrade -y
apt install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
docker --version
```

### 3. Initialiser le Swarm sur le manager

```bash
# Sur swarm-master, en utilisant l'IP privée du VPC
docker swarm init --advertise-addr <IP_PRIVÉE_MASTER>
```

Récupère le token de jointure affiché.

### 4. Joindre les workers

Sur **chaque worker**, exécute la commande affichée par `swarm init` :

```bash
docker swarm join --token SWMTKN-1-xxxxxxxx <IP_PRIVÉE_MASTER>:2377
```

### 5. Vérifier le cluster (sur le manager)

```bash
docker node ls
```

Tu dois voir :

```
ID         HOSTNAME         STATUS    AVAILABILITY   MANAGER STATUS
xxx *      swarm-master     Ready     Active         Leader
yyy        swarm-worker-1   Ready     Active
zzz        swarm-worker-2   Ready     Active
```

---

## Déploiement de l'application

### 1. Cloner le projet sur le manager

```bash
cd /opt
git clone https://github.com/<ton-user>/projet-final.git
cd projet-final
```

### 2. Lancer le script de déploiement

```bash
chmod +x deploy.sh rm.sh
./deploy.sh
```

Le script :
1. Vérifie que le Swarm est actif
2. Build les 3 images Docker (`user-service`, `task-service`, `web-frontend`)
3. Distribue les images aux workers (via `docker save` + `scp` + `docker load`)
4. Déploie le reverse proxy si pas déjà présent
5. Déploie la stack `multiweb-stack`
6. Affiche l'état final

### 3. Vérifier l'état

```bash
docker stack services multiweb-stack
docker stack ps multiweb-stack
```

---

## Configuration HTTPS (Nginx Proxy Manager)

### 1. Premier accès à NPM

```
http://<IP_MASTER>:81
```

**Identifiants par défaut** :
- Email : `admin@example.com`
- Password : `changeme`

NPM te demandera de changer ces identifiants au premier login. **Fais-le immédiatement.**

### 2. Créer le proxy host pour l'application

Dans NPM → **Hosts** → **Proxy Hosts** → **Add Proxy Host** :

**Onglet Details :**
- Domain Names : `projet-esgi.thami.fr`
- Scheme : `http`
- Forward Hostname / IP : `web-frontend`
- Forward Port : `80`
- ✅ Block Common Exploits
- ✅ Websockets Support

**Onglet SSL :**
- SSL Certificate : *Request a new SSL Certificate*
- ✅ Force SSL
- ✅ HTTP/2 Support
- Email : ton email
- ✅ I Agree to the Let's Encrypt TOS
- → **Save**

Let's Encrypt génère automatiquement le certificat (≈30s).

### 3. (Optionnel) Sécuriser l'admin de NPM

Crée un autre proxy host pour `npm.thami.fr` → `127.0.0.1:81` avec SSL Let's Encrypt.

---

## Tests de haute disponibilité

### Test 1 : voir le load balancing

Rafraîchis plusieurs fois `https://projet-esgi.thami.fr` : le hostname affiché en haut de la page change → c'est le **routing mesh de Swarm** qui distribue les requêtes entre les 3 replicas du frontend.

### Test 2 : tuer un container, voir Swarm le redémarrer

```bash
# Lister les tâches du frontend
docker stack ps multiweb-stack | grep web-frontend

# Tuer un container sur un worker (en SSH)
ssh root@swarm-worker-1
docker ps | grep web-frontend
docker kill <container-id>

# Sur le master, observer la reprogrammation
docker stack ps multiweb-stack | grep web-frontend
# -> "Shutdown" puis "Running" automatiquement (~10s)
```

### Test 3 : scaling à chaud

```bash
docker service scale multiweb-stack_web-frontend=5
docker stack ps multiweb-stack | grep web-frontend
# -> 5 replicas distribués
docker service scale multiweb-stack_web-frontend=3   # retour à la normale
```

### Test 4 : persistance de la BDD

```bash
# Ajouter un user via le frontend
# Tuer le container postgres
docker ps | grep postgres
docker kill <container-id>

# Attendre que Swarm le relance (~30s)
docker stack ps multiweb-stack | grep postgres

# Rafraîchir le frontend → l'utilisateur est toujours là (volume persistant)
```

---

## Démonstration des bonus

### Bonus 1 : Resources limits & reservations

```bash
docker service inspect multiweb-stack_web-frontend \
  --format '{{ json .Spec.TaskTemplate.Resources }}' | python3 -m json.tool
```

### Bonus 2 : Placement constraints

```bash
docker service inspect multiweb-stack_postgres \
  --format '{{ json .Spec.TaskTemplate.Placement.Constraints }}'
# -> ["node.role == manager"]

docker service inspect multiweb-stack_web-frontend \
  --format '{{ json .Spec.TaskTemplate.Placement.Constraints }}'
# -> ["node.role == worker"]
```

### Bonus 3 : Rolling update + rollback automatique

```bash
# Modifier index.php (ex: changer le titre), rebuild
docker build -t localhost/web-frontend:latest ./web-frontend

# Distribuer aux workers (ou utiliser un registry)
# ... (cf. deploy.sh)

# Mise à jour progressive (parallelism: 1)
docker service update --image localhost/web-frontend:latest multiweb-stack_web-frontend

# Suivi
docker service ps multiweb-stack_web-frontend
# -> les tâches sont remplacées 1 par 1 (delay 10s entre chaque)

# Si échec, rollback automatique grâce à update_config.failure_action: rollback
# Pour un rollback manuel :
docker service rollback multiweb-stack_web-frontend
```

---

## Nettoyage

```bash
# Supprimer la stack applicative seulement (volumes conservés)
./rm.sh

# Tout nettoyer (stacks + volumes BDD + NPM)
./rm.sh --all
```

---

## Dépannage

### Le frontend ne démarre pas
- Vérifie que `user-service` et `task-service` sont healthy : `docker service ls`
- Logs : `docker service logs multiweb-stack_web-frontend`

### PostgreSQL ne démarre pas
- Le init.sql doit être présent dans `/opt/projet-final/db/` sur le master
- Vérifie le chemin : `INIT_SQL_PATH` dans `deploy.sh`

### NPM ne génère pas le certificat
- Vérifie que les ports 80/443 sont ouverts
- Vérifie que `projet-esgi.thami.fr` pointe bien vers l'IP du master (`nslookup`)
- Vérifie la propagation DNS : `dig projet-esgi.thami.fr`

### Les workers n'ont pas les images
- Re-exécute la phase de distribution dans `deploy.sh`
- Ou monte un registre Docker privé (plus propre)

---

## Auteurs

Projet réalisé en groupe – ESGI IW1 T2 – Promotion 2025/2026

## Licence

Projet académique, à usage pédagogique uniquement.
