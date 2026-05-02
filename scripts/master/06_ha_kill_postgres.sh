#!/usr/bin/env bash
CONTAINER_ID=$(docker ps --filter name=multiweb-stack_postgres --format "{{.ID}}" | head -1)
docker kill "$CONTAINER_ID"
watch -n2 "docker service ps multiweb-stack_postgres"
