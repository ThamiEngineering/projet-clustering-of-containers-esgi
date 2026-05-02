#!/usr/bin/env bash
HOST="projet-esgi.thami.fr"
echo | openssl s_client -connect "$HOST:443" -servername "$HOST" 2>/dev/null \
    | openssl x509 -noout -subject -issuer -dates
