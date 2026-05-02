#!/usr/bin/env bash
APP_URL="https://projet-esgi.thami.fr"
for i in $(seq 1 10); do
    curl -sk "$APP_URL" | grep -o 'Servi par : [^<]*'
    sleep 0.5
done
