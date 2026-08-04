#!/bin/bash
set -euo pipefail


# Optimalisasi sysctl untuk menangani koneksi tinggi (1 CPU, 1 GB RAM)
cat << 'EOF' > /etc/sysctl.d/99-custom-tuning.conf
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
vm.swappiness = 10
EOF
sysctl --system

# Sesuaikan limit file terbuka
cat << 'EOF' > /etc/security/limits.d/99-custom-limits.conf
* soft nofile 65535
* hard nofile 65535
* soft nproc 2048
* hard nproc 2048
EOF

# Swap space (1GB) untuk pencegahan OOM pada server 1GB RAM
if ! grep -q '/swapfile' /etc/fstab; then
    fallocate -l 1G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=1024
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# UFW setup
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Ingress Rules
ufw allow 22/tcp comment 'SSH Access'
ufw allow 80/tcp comment 'HTTP Web App'
ufw allow 443/tcp comment 'HTTPS Web App'

# Egress Rules 
ufw default deny outgoing
ufw allow out 53 comment 'DNS resolution'
ufw allow out 80/tcp comment 'HTTP outbound'
ufw allow out 443/tcp comment 'HTTPS outbound'
ufw allow out 123/udp comment 'NTP synchronization'

ufw --force enable

# User creation dan ssh key setup
sed -i 's/#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# Group
groupadd -f devops
groupadd -f dev

# sudo no password
echo "%devops ALL=(ALL:ALL) ALL" > /etc/sudoers.d/devops
chmod 0440 /etc/sudoers.d/devops

# Fungsi utilitas untuk pembuatan user (menggunakan SSH Public Key)
# Penggunaan: create_user <username> <group> "<ssh_public_key>"
create_user() {
    local username="$1"
    local group="$2"
    local pubkey="$3"

    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash -g "$group" "$username"
    fi

    local ssh_dir="/home/${username}/.ssh"
    mkdir -p "$ssh_dir"
    echo "$pubkey" > "${ssh_dir}/authorized_keys"
    chmod 700 "$ssh_dir"
    chmod 600 "${ssh_dir}/authorized_keys"
    chown -R "${username}:${group}" "$ssh_dir"
}

# Create user with SSH Keys (replace with real public keys)
create_user "devops1" "devops" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
create_user "dev1" "dev" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
create_user "dev2" "dev" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."



# Direktori Web App dengan SGID Bit untuk kolaborasi grup 'dev'
mkdir -p /opt/rey/sample-web-app
chown -R :dev /opt/rey/sample-web-app
chmod -R 2775 /opt/rey/sample-web-app
# SGID (2775) memastikan setiap file/folder baru yang dibuat dev1/dev2 otomatis mewarisi grup 'dev'

# Akses pembacaan log untuk grup 'dev' via POSIX ACL
apt-get update -y && apt-get install -y acl
setfacl -R -m g:dev:rX /var/log
setfacl -d -m g:dev:rX /var/log

# Postgresql dan nginx untuk web app
apt-get install -y postgresql postgresql-contrib nginx


# Konfigurasi log retention 14 hari
cat << 'EOF' > /etc/logrotate.d/custom_app_logs
/var/log/*.log {
    daily
    rotate 14
    missingok
    compress
    delaycompress
    notifempty
    create 0640 root dev
    dateext
    dateformat -%Y%m%m
}
EOF


#  Collect log script
DEST_DIR="/tmp/archive_logs"
DATE_STAMP=$(date +%Y%m%d)
ARCHIVE_NAME="logs_${DATE_STAMP}.tar.gz"

mkdir -p "$DEST_DIR"

# Mencari dan mengumpulkan semua file .log di /var/log lalu mengompresnya
find /var/log -type f -name "*.log" -print0 | tar -czvf "${DEST_DIR}/${ARCHIVE_NAME}" --null -T -

# Set izin akses pada hasil arsip agar grup dev dapat membaca/mengunduhnya
chmod 644 "${DEST_DIR}/${ARCHIVE_NAME}"

echo "Proses selesai. File log berhasil diarsipkan di: ${DEST_DIR}/${ARCHIVE_NAME}"