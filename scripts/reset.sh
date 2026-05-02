#!/usr/bin/env bash
set -euo pipefail

docker service scale \
    multiweb-stack_web-frontend=3 \
    multiweb-stack_user-service=2 \
    multiweb-stack_task-service=2

echo "Waiting for convergence..."
sleep 15

docker stack services multiweb-stack
