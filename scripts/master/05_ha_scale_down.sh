#!/usr/bin/env bash
docker service scale multiweb-stack_web-frontend=3
docker stack ps multiweb-stack | grep web-frontend
