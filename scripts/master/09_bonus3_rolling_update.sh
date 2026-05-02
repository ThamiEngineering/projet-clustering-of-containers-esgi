#!/usr/bin/env bash
docker service update --force multiweb-stack_web-frontend
watch -n2 "docker service ps multiweb-stack_web-frontend"
