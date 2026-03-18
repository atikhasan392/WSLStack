#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
# Ubuntu 24.04 – LAMP Dev Setup
# PHP 8.5, MySQL 8.4, Apache, phpMyAdmin, Node.js 24, Bun, Composer
# =====================================================================
# Usage:
#   chmod +x install.sh
#   sed -i 's/\r$//' install.sh
#   sudo bash install.sh
# =====================================================================

# =====================================================================
# ROOT CHECK
# =====================================================================
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo bash install.sh"
  exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo ">> Setup Getting started। Real user: $REAL_USER | Home: $REAL_HOME"

# =====================================================================
# SYSTEM UPDATE
# =====================================================================
apt update
apt upgrade -y
apt autoremove -y
apt install -y \
  curl unzip git wget gnupg2 ca-certificates \
  lsb-release apt-transport-https software-properties-common

# =====================================================================
# PHP 8.5, PHP 8.5-FPM, PHP 8.5-CLI + Extensions
# =====================================================================
LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y
apt update
apt install -y \
  php8.5 php8.5-fpm php8.5-cli \
  php8.5-bcmath \
  php8.5-curl \
  php8.5-dom \
  php8.5-gd \
  php8.5-mbstring \
  php8.5-mysql \
  php8.5-xml \
  php8.5-zip \
  php8.5-intl \
  php8.5-redis \
  php8.5-readline

systemctl enable php8.5-fpm
systemctl start php8.5-fpm

# =====================================================================
# Composer
# =====================================================================
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# =====================================================================
# Node.js 24 via NVM (Install for real users)
# =====================================================================
sudo -u "$REAL_USER" bash -c "
  export NVM_DIR=\"$REAL_HOME/.nvm\"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
  [ -s \"\$NVM_DIR/nvm.sh\" ] && source \"\$NVM_DIR/nvm.sh\"
  nvm install 24
  nvm use 24
  nvm alias default 24
  npm i -g yarn npm-check-updates
"

# =====================================================================
# Bun (Install for real users)
# =====================================================================
sudo -u "$REAL_USER" bash -c 'curl -fsSL https://bun.sh/install | bash'

# =====================================================================
# MySQL 8.4 LTS
# =====================================================================
MYSQL_DEB="mysql-apt-config_0.8.36-1_all.deb"
wget "https://dev.mysql.com/get/$MYSQL_DEB" -O "/tmp/$MYSQL_DEB"
DEBIAN_FRONTEND=noninteractive dpkg -i "/tmp/$MYSQL_DEB"
rm "/tmp/$MYSQL_DEB"
apt update
apt install -y mysql-server
systemctl enable mysql
systemctl start mysql
systemctl status mysql --no-pager || true

# MySQL User Setup (For phpMyAdmin)
DB_USER="admin"
DB_PASS="Admin@1234"
 
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# =====================================================================
# Apache + PHP-FPM Integration
# =====================================================================
apt install -y apache2
a2enmod rewrite
a2enmod proxy_fcgi setenvif
a2enconf php8.5-fpm
systemctl enable apache2
systemctl restart apache2

# =====================================================================
# phpMyAdmin
# =====================================================================
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true"             | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password ${DB_PASS}"  | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password ${DB_PASS}"      | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password ${DB_PASS}"        | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin

# phpMyAdmin Auto-Login Config
PMA_CONFIG="/etc/phpmyadmin/conf.d/autologin.php"
 
cat > "$PMA_CONFIG" <<EOF
<?php
\$cfg['Servers'][1]['auth_type']       = 'config';
\$cfg['Servers'][1]['user']            = '${DB_USER}';
\$cfg['Servers'][1]['password']        = '${DB_PASS}';
\$cfg['Servers'][1]['AllowNoPassword'] = false;
EOF
 
chmod 640 "$PMA_CONFIG"
chown root:www-data "$PMA_CONFIG"
 
systemctl restart apache2

# =====================================================================
# DONE
# =====================================================================
echo ""
echo "============================================"
echo " Installation Complete!"
echo "============================================"
echo " PHP       : $(php -v | head -1)"
echo " Composer  : $(composer --version 2>/dev/null)"
echo " MySQL     : $(mysql --version)"
echo " Apache    : $(apache2 -v 2>/dev/null | head -1)"
echo "============================================"
echo " phpMyAdmin: http://localhost/phpmyadmin"
echo "--------------------------------------------"
echo " MySQL root  → user: root  | pass: ${DB_PASS}"
echo " MySQL admin → user: admin | pass: ${DB_PASS}"
echo "--------------------------------------------"
echo " Use in Laravel .env:"
echo "   DB_USERNAME=admin"
echo "   DB_PASSWORD=${DB_PASS}"
echo "============================================"
echo ""
echo " Node.js and Bun have been installed for user '$REAL_USER'."
echo " Restart the terminal or run:"
echo "   source ~/.bashrc"
echo ""