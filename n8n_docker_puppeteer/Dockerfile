FROM n8nio/n8n:latest

USER root

RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ttf-freefont \
    ghostscript \
    && rm -rf /var/cache/apk/*

USER node

ENV PUPPETEER_EXECUTABLE_PATH="/usr/bin/chromium"

