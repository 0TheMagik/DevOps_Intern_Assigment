#!/bin/bash
set -e

CURRENT_DIR=$(cd "$(dirname "$0")" && pwd)

sudo apt update
sudo apt install -y nginx

sudo cp -f "$CURRENT_DIR/index.html" /var/www/html/index.html

sudo ufw allow 'Nginx HTTP'
sudo ufw enable

sudo systemctl enable nginx
sudo systemctl restart nginx

curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
  && echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list \
  && sudo apt update \
  && sudo apt install ngrok

ngrok config add-authtoken $(grep TOKEN "$CURRENT_DIR/.env" | cut -d '=' -f2)
ngrok http 80 --pooling-enabled=true