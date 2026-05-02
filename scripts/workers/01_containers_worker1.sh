#!/usr/bin/env bash
WORKER1=$(docker node ls --filter role=worker --format '{{.ID}}' | head -1 \
    | xargs -I{} docker node inspect {} --format '{{.Status.Addr}}')
ssh -o StrictHostKeyChecking=no root@"$WORKER1" \
    "docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}'"
