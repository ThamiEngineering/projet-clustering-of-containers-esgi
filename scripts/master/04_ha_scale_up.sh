#!/usr/bin/env bash
docker service scale multiweb-stack_web-frontend=5
docker stack ps multiweb-stack | grep web-frontend
