#!/usr/bin/env bash
for SERVICE in web-frontend user-service task-service postgres; do
    echo "=== multiweb-stack_${SERVICE} ==="
    docker service inspect "multiweb-stack_${SERVICE}" \
        --format '{{ json .Spec.TaskTemplate.Placement.Constraints }}'
    echo ""
done
