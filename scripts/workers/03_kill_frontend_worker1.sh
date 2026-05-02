#!/usr/bin/env bash
WORKER1=$(docker node ls --filter role=worker --format '{{.ID}}' | head -1 \
    | xargs -I{} docker node inspect {} --format '{{.Status.Addr}}')
CONTAINER_ID=$(ssh -o StrictHostKeyChecking=no root@"$WORKER1" \
    "docker ps --filter name=web-frontend --format '{{.ID}}' | head -1")
ssh -o StrictHostKeyChecking=no root@"$WORKER1" "docker kill $CONTAINER_ID"
watch -n2 "docker service ps multiweb-stack_web-frontend"
