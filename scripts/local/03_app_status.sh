#!/usr/bin/env bash
APP_URL="https://projet-esgi.thami.fr"
curl -sw "HTTP %{http_code} | %{time_total}s\n" -o /dev/null "$APP_URL"
