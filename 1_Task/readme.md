# Deployment Static web page  
Link Access: https://dish-populace-scarcity.ngrok-free.dev/  
link access ini di jalankan pada self hosted VM dan menggunakan ngrok sebagai gateway untuk access publik.
  
website ini di deploy dengan menggunakan bash script untuk automaticdeployment yaitu `deploy.sh`. Bash script ini akan melakukan instalasi dependency yang dibutuhkan yaitu nginx dan ngrok.

Sebelum script ini dijalankan perlu dibuat file `.env` yang berisi token dari ngrok.
```
TOKEN=[your token]
```
## Dokumentasi Bash script
```bash
set -e

CURRENT_DIR=$(cd "$(dirname "$0")" && pwd)

sudo apt update
sudo apt install -y nginx
```
`set -e` akan menghentikan script saat ada eror.  
mengambil lokasi directory script.   
melakukan pengecekan update dan instalasi nginx

```bash
sudo cp -f "$CURRENT_DIR/index.html" /var/www/html/index.html
```
melakukan copy file index.html ke directory utama nginx

```bash
sudo ufw allow 'Nginx HTTP'
sudo ufw enable
```
melakukan konfigurasi firewall untuk mengizinkan traffic nginx HTTP

```bash
sudo systemctl enable nginx
sudo systemctl restart nginx
```
menyalakan nginx agar static web page bisa dilihat

```bash
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
  && echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list \
  && sudo apt update \
  && sudo apt install ngrok

ngrok config add-authtoken $(grep TOKEN "$CURRENT_DIR/.env" | cut -d '=' -f2)
ngrok http 80 --pooling-enabled=true
```
mengkonfigurasi ngrok dengan token agar website dapat di akses lewat internet