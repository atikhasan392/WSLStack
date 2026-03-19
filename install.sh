#!/usr/bin/env bash
# =====================================================================
# Laravel Development Environment Setup Script
# Target OS: WSL2 - Ubuntu 24.04 LTS
# Purpose:  Local development machine setup (NOT for production!)
#
# Features:
#   • PHP 8.5 + FPM + common extensions
#   • Composer + global Laravel installer
#   • MySQL 8.4 (root via auth_socket, no password)
#   • MySQL user = Linux username, password = Linux password
#   • phpMyAdmin with AUTOLOGIN (using above credentials)  → DEV ONLY!
#   • Redis server (localhost only, protected mode)
#   • Node.js 24 via NVM + NPM + yarn
#   • Bun
#   • Git + GitHub CLI (gh)
#   • Apache 2 + PHP-FPM integration
#
# Security notes:
#   • phpMyAdmin autologin → plaintext password in config file
#     → Extremely dangerous on any networked or shared machine
#   • Only use this script on a personal, isolated dev laptop/VM
#   • MySQL root access: sudo mysql (no password)
#
# Usage:
#   chmod +x install.sh
#   sudo ./install.sh
# =====================================================================

set -euo pipefail

# ────────────────────────────────────────────────
# 0. Basic validation – must run as root
# ────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo."
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

if [ -z "$REAL_HOME" ] || [ ! -d "$REAL_HOME" ]; then
    echo "Error: Cannot determine real user's home directory."
    exit 1
fi

echo ""
echo "===================================================="
echo " Laravel Dev Setup - Ubuntu 24.04"
echo " User:          ${REAL_USER}"
echo " Home:          ${REAL_HOME}"
echo " Date:          $(date '+%Y-%m-%d')"
echo "===================================================="
echo ""

# ────────────────────────────────────────────────
# 1. Ask for the user's password (used for MySQL)
# ────────────────────────────────────────────────
echo "Please enter password for Linux user '${REAL_USER}'"
echo "→ This same password will be used for MySQL user '${REAL_USER}'@'localhost'"
echo -n "Password: "
read -s USER_PASSWORD
echo ""
echo ""

if [ -z "${USER_PASSWORD}" ]; then
    echo "Error: Password cannot be empty."
    exit 1
fi

# ────────────────────────────────────────────────
# 2. System update + essential tools
# ────────────────────────────────────────────────
echo "→ Updating package lists and upgrading system..."

apt update -qq
apt upgrade -y -qq
apt autoremove -y -qq

echo "→ Installing base utilities..."
apt install -y -qq \
    curl wget gnupg ca-certificates lsb-release \
    apt-transport-https software-properties-common \
    unzip git build-essential

# ────────────────────────────────────────────────
# 3. PHP 8.5 (Ondřej Surý PPA)
# ────────────────────────────────────────────────
echo "→ Adding PHP PPA and installing PHP 8.5..."

LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y
apt update -qq

PHP_PACKAGES=(
    php8.5
    php8.5-fpm
    php8.5-cli
    php8.5-bcmath
    php8.5-curl
    php8.5-dom
    php8.5-gd
    php8.5-mbstring
    php8.5-mysql
    php8.5-xml
    php8.5-zip
    php8.5-intl
    php8.5-readline
    php8.5-redis
    php8.5-msgpack
    php8.5-igbinary
)

apt install -y -qq "${PHP_PACKAGES[@]}"

systemctl enable --now php8.5-fpm

# ────────────────────────────────────────────────
# 4. Composer + Laravel installer (user level)
# ────────────────────────────────────────────────
echo "→ Installing Composer globally..."

curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet
rm -f /tmp/composer-setup.php

echo "→ Installing Laravel installer for user ${REAL_USER}..."
sudo -u "${REAL_USER}" env HOME="${REAL_HOME}" bash <<'END'
    set -euo pipefail
    composer global require laravel/installer --prefer-dist --no-progress --no-interaction

    BIN_PATH="$HOME/.config/composer/vendor/bin"
    PROFILE="$HOME/.bashrc"

    grep -qxF "export PATH=\"\$PATH:$BIN_PATH\"" "$PROFILE" || \
        echo "export PATH=\"\$PATH:$BIN_PATH\"" >> "$PROFILE"
END

# ────────────────────────────────────────────────
# 5. Node.js 24 via NVM + Npm + Yarn
# ────────────────────────────────────────────────
echo "→ Installing Node.js 24 (via NVM) for user ${REAL_USER}..."

sudo -u "${REAL_USER}" bash <<'END'
    set -euo pipefail
    export NVM_DIR="$HOME/.nvm"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    nvm install 24 --latest-npm
    nvm use 24
    nvm alias default 24

    npm install -g yarn npm-check-updates --quiet
END

# ────────────────────────────────────────────────
# 6. Bun
# ────────────────────────────────────────────────
echo "→ Installing Bun for user ${REAL_USER}..."
sudo -u "${REAL_USER}" bash -c 'curl -fsSL https://bun.sh/install | bash'

# ────────────────────────────────────────────────
# 7. MySQL 8.4 – no root password, user = Linux user
# ────────────────────────────────────────────────
echo "→ Installing MySQL 8.4 LTS (root via auth_socket)..."

# Use explicit known-good version instead of _latest (more stable in automation)
MYSQL_CONFIG_DEB="mysql-apt-config_0.8.36-1_all.deb"
wget -q "https://dev.mysql.com/get/${MYSQL_CONFIG_DEB}" -O "/tmp/${MYSQL_CONFIG_DEB}"

if [ ! -s "/tmp/${MYSQL_CONFIG_DEB}" ]; then
    echo "Error: Failed to download MySQL apt config package."
    exit 1
fi

# Pre-seed the version choice so no interactive dialog appears
echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4-lts" | sudo debconf-set-selections
echo "mysql-apt-config mysql-apt-config/select-tools select" | sudo debconf-set-selections  # optional tools

DEBIAN_FRONTEND=noninteractive sudo dpkg -i "/tmp/${MYSQL_CONFIG_DEB}"

# Clean up
rm -f "/tmp/${MYSQL_CONFIG_DEB}"

# Now update and install
apt update -qq
apt install -y -qq mysql-server mysql-client

systemctl enable --now mysql

# Create user (same as before)
echo "→ Creating MySQL user '${REAL_USER}'@'localhost' ..."
mysql -e "CREATE USER IF NOT EXISTS '${REAL_USER}'@'localhost' IDENTIFIED BY '${USER_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${REAL_USER}'@'localhost' WITH GRANT OPTION;"
mysql -e "FLUSH PRIVILEGES;"

# ────────────────────────────────────────────────
# 8. Redis Server
# ────────────────────────────────────────────────
echo "→ Installing Redis..."

apt install -y -qq redis-server redis-tools

# Minimal dev hardening
sed -i 's/^bind .*/bind 127.0.0.1/' /etc/redis/redis.conf
sed -i 's/^protected-mode no/protected-mode yes/' /etc/redis/redis.conf 2>/dev/null || true

systemctl enable --now redis-server

# ────────────────────────────────────────────────
# 9. Apache + PHP-FPM
# ────────────────────────────────────────────────
echo "→ Configuring Apache..."

apt install -y -qq apache2

a2enmod rewrite proxy_fcgi setenvif headers
a2enconf php8.5-fpm
systemctl restart apache2

# ────────────────────────────────────────────────
# 10. phpMyAdmin + AUTOLOGIN (DEV MACHINE ONLY!)
# ────────────────────────────────────────────────
echo "→ Installing phpMyAdmin with autologin (DEV ONLY!)..."

echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt install -y -qq phpmyadmin

# Autologin configuration – VERY INSECURE outside localhost
PMA_AUTOLOGIN="/etc/phpmyadmin/conf.d/99-autologin.php"

cat > "${PMA_AUTOLOGIN}" <<EOF
<?php
\$cfg['Servers'][1]['auth_type']       = 'config';
\$cfg['Servers'][1]['user']            = '${REAL_USER}';
\$cfg['Servers'][1]['password']        = '${USER_PASSWORD}';
\$cfg['Servers'][1]['AllowNoPassword'] = false;
?>
EOF

chmod 640 "${PMA_AUTOLOGIN}"
chown root:www-data "${PMA_AUTOLOGIN}"

systemctl restart apache2

# ────────────────────────────────────────────────
# 11. GitHub CLI
# ────────────────────────────────────────────────
echo "→ Installing GitHub CLI (gh)..."

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list >/dev/null

apt update -qq
apt install -y -qq gh

# ────────────────────────────────────────────────
# Final summary
# ────────────────────────────────────────────────
echo ""
echo "===================================================="
echo "             SETUP FINISHED"
echo "===================================================="
echo ""
echo "PHP          : $(php -v | head -n 1)"
echo "Composer     : $(composer --version)"
echo "MySQL        : $(mysql --version)"
echo "Redis        : $(redis-server --version)   (localhost:6379)"
echo "Apache       : $(apache2 -v | head -n 1)"
echo ""
echo "MySQL:"
echo "  sudo mysql                        → root (no password)"
echo "  mysql -u ${REAL_USER} -p          → your password"
echo ""
echo "phpMyAdmin:"
echo "  http://localhost/phpmyadmin       → should auto-login as ${REAL_USER}"
echo "  WARNING: Autologin is INSECURE outside personal dev machine!"
echo ""
echo "Redis:"
echo "  redis-cli                         → works on localhost"
echo ""
echo "Next steps:"
echo "  source ~/.bashrc"
echo "  laravel new my-project"
echo "  cd my-project && php artisan serve"
echo ""
echo "===================================================="
echo ""
