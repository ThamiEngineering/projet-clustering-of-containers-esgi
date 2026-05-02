#!/usr/bin/env bash
WORKER2=$(docker node ls --filter role=worker --format '{{.ID}}' | tail -1 \
    | xargs -I{} docker node inspect {} --format '{{.Status.Addr}}')
ssh -o StrictHostKeyChecking=no root@"$WORKER2" \
    "docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}'"
