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