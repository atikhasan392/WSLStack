#!/usr/bin/env bash
# =====================================================================
# Laravel Development Environment Setup Script
# Target OS: WSL2 / Ubuntu 24.04 LTS
# Purpose:  Local development machine setup (NOT for production!)
#
# This script automates a complete Laravel dev environment:
#   - Modern PHP with FPM for better performance
#   - Composer + official Laravel installer (global)
#   - Secure MySQL setup with user matching Linux login
#   - phpMyAdmin with auto-login (DEV ONLY – insecure!)
#   - Latest stable Redis from official repo
#   - Node.js LTS via NVM + common tools
#   - Bun for fast JS runtime
#   - Git + GitHub CLI for version control
#   - Apache with PHP-FPM proxy
#
# Security reminders:
#   - phpMyAdmin autologin stores password in plain text → NEVER expose to network!
#   - MySQL root uses socket auth (sudo mysql) → no password needed locally
#   - Redis bound to localhost only
#   - Run this on isolated machine/VM/WSL only
#
# Usage:
#   chmod +x install.sh
#   sudo ./install.sh
# =====================================================================

set -euo pipefail  # Strict mode: exit on error, undefined vars, pipe failures

# ────────────────────────────────────────────────
# 0. Root & User Validation
#    - Ensures script runs as root (sudo)
#    - Detects real user (SUDO_USER) and home dir
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
echo " Laravel Dev Setup - Ubuntu 24.04 (WSL2 compatible)"
echo " User:          ${REAL_USER}"
echo " Home:          ${REAL_HOME}"
echo " Date:          $(date '+%Y-%m-%d %H:%M:%S')"
echo "===================================================="
echo ""

# ────────────────────────────────────────────────
# 1. User Password Prompt
#    - Used for both sudo (implicit) and MySQL user creation
#    - Password never shown on screen (-s flag)
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
# 2. System Update & Base Packages
#    - Keeps system current + installs tools needed later
# ────────────────────────────────────────────────
echo "→ Updating package lists and upgrading system (quiet mode)..."

apt update -qq
apt upgrade -y -qq
apt autoremove -y -qq

echo "→ Installing essential utilities (curl, git, build tools, etc.)..."
apt install -y -qq \
    curl wget gnupg ca-certificates lsb-release \
    apt-transport-https software-properties-common \
    unzip git build-essential

# ────────────────────────────────────────────────
# 3. PHP 8.5 Installation via Ondřej PPA
#    - Latest PHP 8.5 with FPM + common extensions for Laravel
#    - FPM preferred over mod_php for better performance/security
# ────────────────────────────────────────────────
echo "→ Adding Ondřej Surý PHP PPA (reliable source for latest PHP)..."

LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y
apt update -qq

PHP_PACKAGES=(
    php8.5 php8.5-fpm php8.5-cli php8.5-bcmath php8.5-curl
    php8.5-dom php8.5-gd php8.5-mbstring php8.5-mysql
    php8.5-xml php8.5-zip php8.5-intl php8.5-readline
    php8.5-redis php8.5-msgpack php8.5-igbinary
)

echo "→ Installing PHP 8.5 packages..."
apt install -y -qq "${PHP_PACKAGES[@]}"

# Enable and start PHP-FPM service
systemctl enable --now php8.5-fpm

# ────────────────────────────────────────────────
# 4. Composer + Laravel Installer
#    - Global Composer in /usr/local/bin
#    - Laravel installer installed per-user (~/.config/composer)
# ────────────────────────────────────────────────
echo "→ Installing latest Composer globally..."

curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet
rm -f /tmp/composer-setup.php

echo "→ Installing Laravel installer for user ${REAL_USER} (non-root)..."
sudo -u "${REAL_USER}" env HOME="${REAL_HOME}" bash <<'END'
    set -euo pipefail
    composer global require laravel/installer --prefer-dist --no-progress --no-interaction

    BIN_PATH="$HOME/.config/composer/vendor/bin"
    PROFILE="$HOME/.bashrc"

    # Add to PATH if not already present
    grep -qxF "export PATH=\"\$PATH:$BIN_PATH\"" "$PROFILE" || \
        echo "export PATH=\"\$PATH:$BIN_PATH\"" >> "$PROFILE"
END

# ────────────────────────────────────────────────
# 5. Node.js 24 via NVM (user-level)
#    - Latest LTS Node + yarn/npm tools
# ────────────────────────────────────────────────
echo "→ Installing Node.js 24 LTS via NVM for user ${REAL_USER}..."

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
# 6. Bun Installation (fast JS/TS runtime)
# ────────────────────────────────────────────────
echo "→ Installing latest Bun for user ${REAL_USER}..."
sudo -u "${REAL_USER}" bash -c 'curl -fsSL https://bun.sh/install | bash'

# ────────────────────────────────────────────────
# 7. MySQL 8.4 LTS – Secure & Non-interactive
#    - Uses auth_socket for root (sudo mysql)
#    - Creates user matching Linux username/password
# ────────────────────────────────────────────────
echo "→ Installing MySQL 8.4 LTS (root via auth_socket)..."

MYSQL_CONFIG_DEB="mysql-apt-config_0.8.36-1_all.deb"
wget -q "https://dev.mysql.com/get/${MYSQL_CONFIG_DEB}" -O "/tmp/${MYSQL_CONFIG_DEB}"

if [ ! -s "/tmp/${MYSQL_CONFIG_DEB}" ]; then
    echo "Error: Failed to download MySQL apt config package."
    exit 1
fi

# Pre-seed debconf to avoid interactive prompt
echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4-lts" | debconf-set-selections
echo "mysql-apt-config mysql-apt-config/select-tools select" | debconf-set-selections

DEBIAN_FRONTEND=noninteractive dpkg -i "/tmp/${MYSQL_CONFIG_DEB}"

rm -f "/tmp/${MYSQL_CONFIG_DEB}"

apt update -qq
apt install -y -qq mysql-server mysql-client

systemctl enable --now mysql

echo "→ Creating MySQL user '${REAL_USER}'@'localhost' with your password..."
mysql -e "CREATE USER IF NOT EXISTS '${REAL_USER}'@'localhost' IDENTIFIED BY '${USER_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${REAL_USER}'@'localhost' WITH GRANT OPTION;"
mysql -e "FLUSH PRIVILEGES;"

# ────────────────────────────────────────────────
# 8. Redis – Latest Stable from Official Repo
#    - Avoids outdated Ubuntu package (7.0.x)
#    - Binds to localhost + protected mode
# ────────────────────────────────────────────────
echo "→ Installing latest stable Redis from official repository..."

curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list >/dev/null

apt update -qq
apt install -y -qq redis

# Dev hardening: localhost only + protected mode
sed -i 's/^bind .*/bind 127.0.0.1/' /etc/redis/redis.conf
sed -i 's/^protected-mode no/protected-mode yes/' /etc/redis/redis.conf 2>/dev/null || true

systemctl enable --now redis-server

# Quick health check
if redis-cli ping | grep -q PONG; then
    echo "→ Redis running successfully (latest version)"
else
    echo "Warning: Redis ping failed – check 'systemctl status redis-server'"
fi

# ────────────────────────────────────────────────
# 9. Apache + PHP-FPM Integration
#    - Enables rewrite, proxy_fcgi for Laravel routing
# ────────────────────────────────────────────────
echo "→ Configuring Apache with PHP 8.5-FPM..."

apt install -y -qq apache2

a2enmod rewrite proxy_fcgi setenvif headers
a2enconf php8.5-fpm
systemctl restart apache2

# ────────────────────────────────────────────────
# 10. phpMyAdmin with Autologin (DEV ONLY!)
#    - Config file timestamped to avoid overwrites
# ────────────────────────────────────────────────
echo "→ Installing phpMyAdmin with autologin (DEV MACHINE ONLY!)..."

echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt install -y -qq phpmyadmin

PMA_AUTOLOGIN="/etc/phpmyadmin/conf.d/99-autologin-$(date +%s).php"

cat > "${PMA_AUTOLOGIN}" <<EOF
<?php
// Autologin config - DEV ONLY! Password stored in plain text
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
# 11. GitHub CLI (gh) – Useful for repo management
# ────────────────────────────────────────────────
echo "→ Installing GitHub CLI (gh)..."

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null

apt update -qq
apt install -y -qq gh

# ────────────────────────────────────────────────
# Final Summary – Clean & Aligned Output
# ────────────────────────────────────────────────
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃                SETUP FINISHED – Laravel Dev Ready             ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

printf " %-20s : %s\n" "PHP"              "$(php -v | head -n1 | cut -d' ' -f2-)"
printf " %-20s : %s\n" "Composer"         "$(composer --version 2>/dev/null | cut -d' ' -f1-3 || echo 'Installed')"
printf " %-20s : %s\n" "MySQL"            "$(mysql --version)"
printf " %-20s : %s\n" "Redis"            "$(redis-server --version | awk '{print $3 " (official latest)"}')   localhost:6379"
printf " %-20s : %s\n" "Apache"           "$(apache2 -v | awk '{print $3}')"
echo ""
echo "MySQL Access:"
echo "  • sudo mysql                        → root access (no password)"
echo "  • mysql -u ${REAL_USER} -p          → your Linux password"
echo ""
echo "phpMyAdmin:"
echo "  • URL: http://localhost/phpmyadmin"
echo "  • Auto-login as '${REAL_USER}' (DEV ONLY – insecure!)"
echo ""
echo "Redis:"
echo "  • Test: redis-cli ping              → should return PONG"
echo ""
echo "Next Steps:"
echo "  1. source ~/.bashrc                 (or restart terminal)"
echo "  2. laravel new my-project"
echo "  3. cd my-project && php artisan serve"
echo ""
echo "===================================================="
echo "          Enjoy coding with Laravel! 🚀             "
echo "===================================================="
echo ""
