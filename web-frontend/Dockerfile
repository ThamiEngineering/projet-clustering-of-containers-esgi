FROM php:8.2-apache
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
COPY public/ /var/www/html/
EXPOSE 80
