# Scripts de démonstration

Tous les scripts `master/` et `workers/` s'exécutent depuis le **swarm-master** (en SSH).
Les scripts `local/` s'exécutent depuis **ta machine**.

```bash
find scripts/ -name "*.sh" -exec chmod +x {} \;
```

---

## reset.sh — à exécuter après les tests

| Script | Ce que ça remet à zéro | Ce qu'on voit |
|---|---|---|
| `reset.sh` | `web-frontend` → 3 replicas, `user-service` → 2, `task-service` → 2, attente de convergence | État final de tous les services avec leurs replicas à la valeur d'origine |

---

## master/

| Script | Ce que ça teste | Ce qu'on voit |
|---|---|---|
| `01_cluster_nodes.sh` | État de tous les nœuds du cluster | Les 3 nœuds (1 Leader + 2 workers) avec leur statut `Ready/Active` |
| `02_stack_services.sh` | Vue d'ensemble des services de la stack | Nombre de replicas démarrés vs attendus (`3/3`, `2/2`, `1/1`) et image utilisée |
| `03_stack_tasks.sh` | Distribution des containers sur les nœuds | Quel container tourne sur quel nœud, leur état `Running` et l'historique des redémarrages |
| `04_ha_scale_up.sh` | Scalabilité horizontale à chaud | Le frontend passe de 3 à 5 replicas sans interruption, Swarm distribue les nouveaux containers automatiquement |
| `05_ha_scale_down.sh` | Réduction des replicas à chaud | 2 containers arrêtés proprement, les 3 restants continuent de servir le trafic |
| `06_ha_kill_postgres.sh` | Persistance des données + tolérance aux pannes BDD | Postgres tué brutalement, redémarré par Swarm en ~10s, données intactes grâce au volume `postgres-data` |
| `07_bonus1_resources.sh` | **Bonus 1** — Resource Requests & Limits | Limites CPU/RAM (`Limits`) et ressources réservées (`Reservations`) pour chaque service |
| `08_bonus2_placement.sh` | **Bonus 2** — Placement constraints | `postgres` contraint à `node.role == manager`, services applicatifs à `node.role == worker` |
| `09_bonus3_rolling_update.sh` | **Bonus 3** — Rolling update progressif | Les 3 replicas mis à jour 1 par 1 avec 10s de délai, service disponible pendant toute la durée |
| `10_bonus3_rollback.sh` | **Bonus 3** — Rollback | Retour à la version précédente replica par replica |
| `11_secrets.sh` | Gestion des secrets Docker | Secrets `postgres_user` et `postgres_password` enregistrés dans Swarm, valeurs jamais visibles en clair |

---

## workers/

> Ces scripts s'exécutent depuis le master — ils récupèrent automatiquement l'IP du worker via `docker node inspect`.

| Script | Ce que ça teste | Ce qu'on voit |
|---|---|---|
| `01_containers_worker1.sh` | État des containers sur le worker 1 | Liste des containers actifs avec image, statut et uptime |
| `02_containers_worker2.sh` | État des containers sur le worker 2 | Idem worker 1 — confirme la distribution des replicas entre les deux workers |
| `03_kill_frontend_worker1.sh` | Haute disponibilité — panne container sur worker 1 | Container frontend tué, Swarm reprogramme un remplaçant en quelques secondes, service accessible pendant toute la durée |
| `04_kill_frontend_worker2.sh` | Haute disponibilité — panne container sur worker 2 | Même résultat que le précédent, confirme que la tolérance aux pannes fonctionne sur n'importe quel nœud |

---

## local/

| Script | Ce que ça teste | Ce qu'on voit |
|---|---|---|
| `01_load_balancing.sh` | Load balancing du routing mesh Swarm | 10 requêtes affichent des hostnames différents (`Servi par : <container>`), prouve la distribution du trafic entre les 3 replicas |
| `02_https_check.sh` | Certificat TLS Let's Encrypt | Subject, issuer (`Let's Encrypt`) et dates de validité du certificat |
| `03_app_status.sh` | Disponibilité et temps de réponse | Code HTTP `200` et temps de réponse en secondes — confirme que toute la chaîne DNS → NPM → Swarm → BDD fonctionne |
