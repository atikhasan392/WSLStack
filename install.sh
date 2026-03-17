#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# WSLStack - single-file WSL2 Laravel dev environment installer
# Target: Ubuntu / Debian on WSL2 only
# Local development only
###############################################################################

APP_NAME="WSLStack"
APP_VERSION="0.2.0"

PHP_VERSION="${PHP_VERSION:-8.4}"
COMPOSER_VERSION="${COMPOSER_VERSION:-2.9.5}"
NODE_VERSION="${NODE_VERSION:-24.14.0}"
NGINX_VERSION_PREFIX="${NGINX_VERSION_PREFIX:-1.28.2}"
MYSQL_COMPONENT="${MYSQL_COMPONENT:-mysql-8.4-lts}"
PHPMYADMIN_VERSION="${PHPMYADMIN_VERSION:-5.2.3}"
REDIS_VERSION_PREFIX="${REDIS_VERSION_PREFIX:-8.6}"
GIT_VERSION="${GIT_VERSION:-2.53.0}"
PHPMYADMIN_ALIAS="${PHPMYADMIN_ALIAS:-phpmyadmin}"
PHP_TIMEZONE="${PHP_TIMEZONE:-Asia/Dhaka}"

LOG_FILE="${LOG_FILE:-/tmp/wslstack-install.log}"
TMP_DIR=""
SUDO=""
DISTRO_ID=""
DISTRO_CODENAME=""
DISTRO_VERSION_ID=""
ARCH=""
PHP_FPM_SOCK=""
PHP_INI_CLI=""
PHP_INI_FPM=""
WSLSTACK_WEB_ROOT="/var/www/wslstack"

NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'

clear_screen() {
    command -v clear >/dev/null 2>&1 && clear || true
}

banner() {
    clear_screen
    printf "%b\n" "${CYAN}${BOLD}➜  ${APP_NAME}${NC}"
    printf "%b\n\n" "${DIM}Native Laravel development environment installer for WSL2${NC}"
}

info() {
    printf "%b\n" "${DIM}[info] $*${NC}"
}

success_line() {
    printf "%b\n" "${GREEN}✔ $*${NC}"
}

warn_line() {
    printf "%b\n" "${YELLOW}⚠ $*${NC}"
}

fail_line() {
    printf "%b\n" "${RED}✖ $*${NC}"
}

die() {
    fail_line "$*"
    [[ -f "${LOG_FILE}" ]] && printf "%b\n" "${DIM}Log: ${LOG_FILE}${NC}"
    exit 1
}

run_step() {
    local label="$1"
    shift

    printf "%b\n" "${CYAN}→ ${label}${NC}"
    if "$@" >>"${LOG_FILE}" 2>&1; then
        success_line "${label}"
    else
        fail_line "${label}"
        tail -n 30 "${LOG_FILE}" >&2 || true
        exit 1
    fi
}

cleanup() {
    [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]] && rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

as_root() {
    ${SUDO} "$@"
}

retry() {
    local tries="$1"
    shift
    local n=1
    until "$@"; do
        if (( n >= tries )); then
            return 1
        fi
        sleep 2
        ((n++))
    done
}

download() {
    local url="$1" target="$2"
    retry 3 curl -fL --connect-timeout 15 --retry 3 --retry-delay 2 -o "${target}" "${url}"
}

fetch_text() {
    local url="$1"
    curl -fsSL --connect-timeout 15 --retry 3 --retry-delay 2 "${url}"
}

sha256_file() {
    sha256sum "$1" | awk '{print $1}'
}

verify_sha256() {
    local file="$1" expected="$2"
    local actual
    actual="$(sha256_file "$file")"
    [[ "${actual}" == "${expected}" ]]
}

# FIX #5: awk regex এ dot escape করার জন্য helper function
escape_for_awk_regex() {
    printf '%s' "$1" | sed 's/\./\\./g'
}

setup_environment() {
    : >"${LOG_FILE}"
    TMP_DIR="$(mktemp -d)"
    export DEBIAN_FRONTEND=noninteractive

    if [[ "${EUID}" -eq 0 ]]; then
        SUDO=""
    else
        command_exists sudo || die "sudo is required."
        SUDO="sudo"
        sudo -v || die "sudo authentication failed."
    fi
}

detect_wsl2() {
    [[ -f /proc/version ]] || die "Cannot verify WSL."
    grep -qi microsoft /proc/version || die "This installer supports WSL only."

    # FIX: /proc/sys/kernel/osrelease এর existence আগে চেক করা হচ্ছে
    local is_wsl2=0
    if [[ -f /proc/sys/kernel/osrelease ]] && grep -qiE 'WSL2|microsoft-standard-WSL2' /proc/sys/kernel/osrelease 2>/dev/null; then
        is_wsl2=1
    elif uname -r | grep -qi microsoft; then
        is_wsl2=1
    fi

    [[ "${is_wsl2}" -eq 1 ]] || die "WSL2 is required."
}

detect_os() {
    [[ -f /etc/os-release ]] || die "Missing /etc/os-release."
    . /etc/os-release

    DISTRO_ID="${ID}"
    DISTRO_VERSION_ID="${VERSION_ID:-}"
    DISTRO_CODENAME="${VERSION_CODENAME:-}"

    if [[ -z "${DISTRO_CODENAME}" ]] && command_exists lsb_release; then
        DISTRO_CODENAME="$(lsb_release -sc 2>/dev/null || true)"
    fi

    case "${DISTRO_ID}" in
        ubuntu|debian) ;;
        *) die "Unsupported distro: ${DISTRO_ID}. Only Ubuntu and Debian are supported." ;;
    esac

    [[ -n "${DISTRO_CODENAME}" ]] || die "Could not detect distro codename."

    case "$(uname -m)" in
        x86_64) ARCH="x64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) die "Unsupported architecture: $(uname -m)" ;;
    esac

    PHP_INI_CLI="/etc/php/${PHP_VERSION}/cli/php.ini"
    PHP_INI_FPM="/etc/php/${PHP_VERSION}/fpm/php.ini"
    PHP_FPM_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"
}

show_detected_distro() {
    success_line "Distro: ${PRETTY_NAME:-${DISTRO_ID}} detected"
}

apt_update() {
    as_root apt-get update -y
}

apt_install() {
    as_root apt-get install -y --no-install-recommends "$@"
}

apt_remove_if_exists() {
    local pkg="$1"
    if dpkg -s "${pkg}" >/dev/null 2>&1; then
        as_root apt-get remove -y "${pkg}"
    fi
}

ensure_base_packages() {
    apt_update
    apt_install ca-certificates curl wget gnupg lsb-release apt-transport-https software-properties-common \
        unzip xz-utils tar jq openssl gpg procps debconf-utils build-essential gettext-base \
        libcurl4-openssl-dev libexpat1-dev libz-dev libssl-dev libpcre2-dev zlib1g-dev libzip-dev \
        libsqlite3-dev libxml2-dev libonig-dev libreadline-dev libicu-dev libpng-dev libjpeg-dev \
        libfreetype6-dev pkg-config autoconf bison re2c libedit-dev libargon2-dev libxslt1-dev
    as_root mkdir -p /etc/apt/keyrings
}

add_nginx_repo() {
    local keyring="/etc/apt/keyrings/nginx-archive-keyring.gpg"
    fetch_text "https://nginx.org/keys/nginx_signing.key" | as_root gpg --dearmor -o "${keyring}"
    printf 'deb [signed-by=%s] https://nginx.org/packages/%s/ %s nginx\n' \
        "${keyring}" "${DISTRO_ID}" "${DISTRO_CODENAME}" | as_root tee /etc/apt/sources.list.d/nginx.list >/dev/null
}

add_mysql_repo() {
    local keyring="/etc/apt/keyrings/mysql.gpg"

    as_root rm -f "${keyring}"
    as_root rm -f /etc/apt/sources.list.d/mysql.list

    fetch_text "https://repo.mysql.com/RPM-GPG-KEY-mysql-2025" | as_root gpg --dearmor -o "${keyring}"

    printf 'deb [signed-by=%s] https://repo.mysql.com/apt/%s/ %s %s\n' \
        "${keyring}" "${DISTRO_ID}" "${DISTRO_CODENAME}" "${MYSQL_COMPONENT}" | as_root tee /etc/apt/sources.list.d/mysql.list >/dev/null
}

add_redis_repo() {
    local keyring="/etc/apt/keyrings/redis-archive-keyring.gpg"
    fetch_text "https://packages.redis.io/gpg" | as_root gpg --dearmor -o "${keyring}"
    printf 'deb [signed-by=%s] https://packages.redis.io/deb %s main\n' \
        "${keyring}" "${DISTRO_CODENAME}" | as_root tee /etc/apt/sources.list.d/redis.list >/dev/null
}

add_php_repo() {
    if [[ "${DISTRO_ID}" == "ubuntu" ]]; then
        as_root add-apt-repository -y ppa:ondrej/php
    else
        local keyring="/etc/apt/keyrings/sury-php.gpg"
        fetch_text "https://packages.sury.org/php/apt.gpg" | as_root gpg --dearmor -o "${keyring}"
        printf 'deb [signed-by=%s] https://packages.sury.org/php/ %s main\n' \
            "${keyring}" "${DISTRO_CODENAME}" | as_root tee /etc/apt/sources.list.d/php.list >/dev/null
    fi
}

configure_repos() {
    add_php_repo
    add_nginx_repo
    add_mysql_repo
    add_redis_repo
    apt_update
}

install_php() {
    local pkgs=(
        "php${PHP_VERSION}"
        "php${PHP_VERSION}-cli"
        "php${PHP_VERSION}-common"
        "php${PHP_VERSION}-fpm"
        "php${PHP_VERSION}-mysql"
        "php${PHP_VERSION}-xml"
        "php${PHP_VERSION}-curl"
        "php${PHP_VERSION}-mbstring"
        "php${PHP_VERSION}-zip"
        "php${PHP_VERSION}-bcmath"
        "php${PHP_VERSION}-intl"
        "php${PHP_VERSION}-readline"
        "php${PHP_VERSION}-opcache"
        "php${PHP_VERSION}-gd"
        "php${PHP_VERSION}-sqlite3"
        "php${PHP_VERSION}-redis"
    )
    apt_install "${pkgs[@]}"
}

composer_installed_version() {
    if command_exists composer; then
        composer --version 2>/dev/null | awk '{print $3}' | tr -d ','
    fi
}

install_composer() {
    local expected setup_file
    setup_file="${TMP_DIR}/composer-setup.php"

    if [[ "$(composer_installed_version || true)" == "${COMPOSER_VERSION}" ]]; then
        return 0
    fi

    expected="$(fetch_text "https://composer.github.io/installer.sig" | tr -d '\n\r')"
    download "https://getcomposer.org/installer" "${setup_file}"
    verify_sha256 "${setup_file}" "${expected}" || die "Composer installer checksum verification failed."

    as_root php "${setup_file}" --version="${COMPOSER_VERSION}" --install-dir=/usr/local/bin --filename=composer
    [[ "$(composer_installed_version || true)" == "${COMPOSER_VERSION}" ]] || die "Composer ${COMPOSER_VERSION} installation failed."
}

install_node() {
    local archive="node-v${NODE_VERSION}-linux-${ARCH}.tar.xz"
    local base_url="https://nodejs.org/dist/v${NODE_VERSION}"
    local archive_path="${TMP_DIR}/${archive}"
    local shasums_path="${TMP_DIR}/SHASUMS256.txt"
    local expected

    if command_exists node && [[ "$(node -v | sed 's/^v//')" == "${NODE_VERSION}" ]]; then
        return 0
    fi

    download "${base_url}/${archive}" "${archive_path}"
    download "${base_url}/SHASUMS256.txt" "${shasums_path}"
    expected="$(awk -v f="${archive}" '$2 == f {print $1}' "${shasums_path}")"
    [[ -n "${expected}" ]] || die "Node.js checksum not found."
    verify_sha256 "${archive_path}" "${expected}" || die "Node.js checksum verification failed."

    as_root rm -rf "/opt/node-v${NODE_VERSION}-linux-${ARCH}"
    as_root tar -xJf "${archive_path}" -C /opt
    as_root ln -sf "/opt/node-v${NODE_VERSION}-linux-${ARCH}/bin/node" /usr/local/bin/node
    as_root ln -sf "/opt/node-v${NODE_VERSION}-linux-${ARCH}/bin/npm" /usr/local/bin/npm
    as_root ln -sf "/opt/node-v${NODE_VERSION}-linux-${ARCH}/bin/npx" /usr/local/bin/npx
    as_root ln -sf "/opt/node-v${NODE_VERSION}-linux-${ARCH}/bin/corepack" /usr/local/bin/corepack

    [[ "$(node -v | sed 's/^v//')" == "${NODE_VERSION}" ]] || die "Node.js ${NODE_VERSION} installation failed."
}

install_nginx() {
    # FIX #5: awk regex এ dot escape করা হয়েছে
    local escaped_prefix
    escaped_prefix="$(escape_for_awk_regex "${NGINX_VERSION_PREFIX}")"
    local pkg_version=""
    pkg_version="$(apt-cache madison nginx | awk -v p="${escaped_prefix}" '$3 ~ "^" p {print $3; exit}')"
    [[ -n "${pkg_version}" ]] || die "Could not find nginx version prefix ${NGINX_VERSION_PREFIX} in repo."
    apt_install "nginx=${pkg_version}"
}

mysql_preseed() {
    printf 'mysql-community-server mysql-community-server/root-pass password \n' | as_root debconf-set-selections
    printf 'mysql-community-server mysql-community-server/re-root-pass password \n' | as_root debconf-set-selections
    printf 'mysql-apt-config mysql-apt-config/select-server select %s\n' "${MYSQL_COMPONENT}" | as_root debconf-set-selections || true
}

install_mysql() {
    mysql_preseed
    apt_remove_if_exists mariadb-server || true
    apt_remove_if_exists mariadb-client || true
    apt_install mysql-community-client mysql-community-server
}

install_redis() {
    # FIX #5: awk regex এ dot escape করা হয়েছে
    local escaped_prefix
    escaped_prefix="$(escape_for_awk_regex "${REDIS_VERSION_PREFIX}")"
    local redis_pkg_version=""
    local tools_pkg_version=""
    redis_pkg_version="$(apt-cache madison redis | awk -v p="${escaped_prefix}" '$3 ~ "^" p {print $3; exit}')"
    tools_pkg_version="$(apt-cache madison redis-tools | awk -v p="${escaped_prefix}" '$3 ~ "^" p {print $3; exit}')"
    [[ -n "${redis_pkg_version}" && -n "${tools_pkg_version}" ]] || die "Could not find Redis ${REDIS_VERSION_PREFIX}.x in official repo."
    apt_install "redis=${redis_pkg_version}" "redis-tools=${tools_pkg_version}"
}

install_git_from_source() {
    local tarball="git-${GIT_VERSION}.tar.xz"
    local url="https://www.kernel.org/pub/software/scm/git/${tarball}"
    local source_dir="${TMP_DIR}/git-${GIT_VERSION}"

    if command_exists git && [[ "$(git --version | awk '{print $3}')" == "${GIT_VERSION}" ]]; then
        return 0
    fi

    download "${url}" "${TMP_DIR}/${tarball}"
    tar -xJf "${TMP_DIR}/${tarball}" -C "${TMP_DIR}"
    pushd "${source_dir}" >/dev/null
    make prefix=/usr/local all
    as_root make prefix=/usr/local install
    popd >/dev/null

    [[ "$(git --version | awk '{print $3}')" == "${GIT_VERSION}" ]] || die "Git ${GIT_VERSION} installation failed."
}

install_phpmyadmin() {
    local url="https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz"
    local archive="${TMP_DIR}/phpmyadmin.tar.gz"
    local dir="/usr/share/phpmyadmin"

    # FIX #4: সঠিক SHA256 URL ব্যবহার করা হয়েছে (www.phpmyadmin.net/files/ → files.phpmyadmin.net)
    local sha_url="https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz.sha256"
    local expected=""

    download "${url}" "${archive}"
    expected="$(fetch_text "${sha_url}" | awk '{print $1}' | tr -d '\n\r')"
    [[ -n "${expected}" ]] || die "phpMyAdmin checksum not found."
    verify_sha256 "${archive}" "${expected}" || die "phpMyAdmin checksum verification failed."

    as_root rm -rf "${dir}" "/usr/share/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages"
    as_root tar -xzf "${archive}" -C /usr/share
    as_root mv "/usr/share/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages" "${dir}"
    as_root mkdir -p "${dir}/tmp"
    as_root chmod 0777 "${dir}/tmp"
}

service_restart() {
    local svc="$1"
    if command_exists systemctl && [[ -d /run/systemd/system ]]; then
        as_root systemctl enable --now "${svc}"
        as_root systemctl restart "${svc}"
    else
        as_root service "${svc}" restart
    fi
}

set_ini_value() {
    local file="$1" key="$2" value="$3"
    [[ -f "${file}" ]] || return 0
    if grep -Eq "^[; ]*${key}[[:space:]]*=" "${file}"; then
        as_root sed -ri "s|^[; ]*${key}[[:space:]]*=.*|${key} = ${value}|g" "${file}"
    else
        printf '%s = %s\n' "${key}" "${value}" | as_root tee -a "${file}" >/dev/null
    fi
}

configure_php() {
    set_ini_value "${PHP_INI_CLI}" "memory_limit" "1024M"
    set_ini_value "${PHP_INI_CLI}" "upload_max_filesize" "5120M"
    # FIX #1: post_max_size অবশ্যই upload_max_filesize এর সমান বা বড় হতে হবে
    set_ini_value "${PHP_INI_CLI}" "post_max_size" "5120M"
    set_ini_value "${PHP_INI_CLI}" "max_input_vars" "3000"
    set_ini_value "${PHP_INI_CLI}" "date.timezone" "${PHP_TIMEZONE}"
    set_ini_value "${PHP_INI_CLI}" "display_errors" "On"
    set_ini_value "${PHP_INI_CLI}" "log_errors" "On"
    set_ini_value "${PHP_INI_CLI}" "max_file_uploads" "100"
    set_ini_value "${PHP_INI_CLI}" "realpath_cache_size" "16M"
    set_ini_value "${PHP_INI_CLI}" "error_reporting" "E_ALL"
    set_ini_value "${PHP_INI_CLI}" "default_socket_timeout" "60"

    set_ini_value "${PHP_INI_FPM}" "memory_limit" "1024M"
    set_ini_value "${PHP_INI_FPM}" "upload_max_filesize" "5120M"
    # FIX #1: post_max_size অবশ্যই upload_max_filesize এর সমান বা বড় হতে হবে
    set_ini_value "${PHP_INI_FPM}" "post_max_size" "5120M"
    set_ini_value "${PHP_INI_FPM}" "max_input_vars" "3000"
    set_ini_value "${PHP_INI_FPM}" "date.timezone" "${PHP_TIMEZONE}"
    set_ini_value "${PHP_INI_FPM}" "display_errors" "On"
    set_ini_value "${PHP_INI_FPM}" "log_errors" "On"
    set_ini_value "${PHP_INI_FPM}" "max_file_uploads" "100"
    set_ini_value "${PHP_INI_FPM}" "realpath_cache_size" "16M"
    set_ini_value "${PHP_INI_FPM}" "error_reporting" "E_ALL"
    set_ini_value "${PHP_INI_FPM}" "default_socket_timeout" "60"
    set_ini_value "${PHP_INI_FPM}" "cgi.fix_pathinfo" "0"

    service_restart "php${PHP_VERSION}-fpm"
}

configure_nginx() {
    as_root mkdir -p "${WSLSTACK_WEB_ROOT}/public"

    cat <<'HTML' | as_root tee "${WSLSTACK_WEB_ROOT}/public/index.php" >/dev/null
<?php
header('Content-Type: text/html; charset=utf-8');
echo "<h1>WSLStack</h1><p>PHP is working.</p>";
HTML

    cat <<EOF2 | as_root tee /etc/nginx/conf.d/wslstack-app.conf >/dev/null
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name localhost;
    root ${WSLSTACK_WEB_ROOT}/public;
    index index.php index.html index.htm;

    client_max_body_size 5120M;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass unix:${PHP_FPM_SOCK};
        fastcgi_index index.php;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF2

    cat <<EOF3 | as_root tee /etc/nginx/conf.d/wslstack-phpmyadmin.conf >/dev/null
server {
    listen 8080;
    listen [::]:8080;
    server_name localhost;

    root /usr/share/phpmyadmin;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass unix:${PHP_FPM_SOCK};
        fastcgi_index index.php;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF3

    as_root rm -f /etc/nginx/conf.d/default.conf /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default
    as_root nginx -t
    service_restart nginx
}

wait_for_mysql() {
    local i
    for i in $(seq 1 60); do
        if as_root mysqladmin ping --protocol=socket -uroot >/dev/null 2>&1 || \
           mysqladmin ping --protocol=tcp -h127.0.0.1 -uroot --password='' >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    return 1
}

configure_mysql() {
    wait_for_mysql || die "MySQL did not become ready in time."

    # FIX #3: mysql socket connection এ as_root ব্যবহার করা হয়েছে
    as_root mysql --protocol=socket -uroot <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

    mysql --protocol=tcp -h127.0.0.1 -uroot --password='' <<'SQL'
CREATE DATABASE IF NOT EXISTS wslstack CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SQL

    # FIX #2: default_authentication_plugin MySQL 8.4 তে remove করা হয়েছে।
    # authentication_policy ব্যবহার করা হয়েছে (MySQL 8.0.27+ এ valid)।
    cat <<'EOF4' | as_root tee /etc/mysql/conf.d/wslstack.cnf >/dev/null
[mysqld]
authentication_policy = caching_sha2_password,
bind-address = 127.0.0.1
mysqlx = 0
sql_mode = STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
EOF4

    service_restart mysql
}

configure_phpmyadmin() {
    local secret
    secret="$(openssl rand -hex 16)"

    cat <<EOF5 | as_root tee /usr/share/phpmyadmin/config.inc.php >/dev/null
<?php
\$cfg['blowfish_secret'] = '${secret}';

\$i = 0;
\$i++;

\$cfg['Servers'][\$i]['auth_type'] = 'config';
\$cfg['Servers'][\$i]['host'] = '127.0.0.1';
\$cfg['Servers'][\$i]['port'] = '3306';
\$cfg['Servers'][\$i]['user'] = 'root';
\$cfg['Servers'][\$i]['password'] = '';
\$cfg['Servers'][\$i]['AllowNoPassword'] = true;
\$cfg['Servers'][\$i]['AllowRoot'] = true;
\$cfg['Servers'][\$i]['compress'] = false;

\$cfg['TempDir'] = '/usr/share/phpmyadmin/tmp';
EOF5
}

configure_redis() {
    local conf="/etc/redis/redis.conf"
    [[ -f "${conf}" ]] || return 0
    as_root sed -ri 's|^bind .*|bind 127.0.0.1 ::1|g' "${conf}" || true
    as_root sed -ri 's|^protected-mode .*|protected-mode yes|g' "${conf}" || true
    service_restart redis
}

summary() {
    printf "\n"
    printf "%b\n" "${CYAN}${BOLD}Stack ready! Access your dev environment:${NC}"
    printf "\n"
    printf "  • Nginx:       http://localhost\n"
    printf "  • MySQL:       Port 3306\n"
    printf "  • Redis:       Port 6379\n"
    printf "  • phpMyAdmin:  http://localhost:8080\n"
    printf "\n"
    printf "%b\n" "${DIM}Installed versions${NC}"
    printf "  • PHP:         %s\n" "${PHP_VERSION}"
    printf "  • Composer:    %s\n" "${COMPOSER_VERSION}"
    printf "  • Node.js:     %s\n" "${NODE_VERSION}"
    printf "  • Nginx:       %s\n" "${NGINX_VERSION_PREFIX}"
    printf "  • MySQL:       8.4 LTS\n"
    printf "  • phpMyAdmin:  %s\n" "${PHPMYADMIN_VERSION}"
    printf "  • Redis:       %s.x\n" "${REDIS_VERSION_PREFIX}"
    printf "  • Git:         %s\n" "${GIT_VERSION}"
    printf "\n"
    printf "%b\n" "${DIM}Log file: ${LOG_FILE}${NC}"
}

main() {
    banner
    setup_environment

    info "Detecting WSL2 Environment..."
    detect_wsl2
    detect_os
    show_detected_distro

    run_step "Updating system packages..." ensure_base_packages
    run_step "Configuring package sources..." configure_repos
    run_step "Installing PHP ${PHP_VERSION} & Extensions..." install_php
    run_step "Applying PHP recommended settings..." configure_php
    run_step "Installing Composer v${COMPOSER_VERSION}..." install_composer
    run_step "Installing Node.js v${NODE_VERSION}..." install_node
    run_step "Installing Nginx v${NGINX_VERSION_PREFIX}..." install_nginx
    run_step "Installing Redis Open Source ${REDIS_VERSION_PREFIX}..." install_redis
    run_step "Installing MySQL 8.4 & phpMyAdmin..." install_mysql
    run_step "Configuring MySQL..." configure_mysql
    run_step "Installing phpMyAdmin v${PHPMYADMIN_VERSION}..." install_phpmyadmin
    run_step "Configuring phpMyAdmin..." configure_phpmyadmin
    run_step "Installing Git v${GIT_VERSION}..." install_git_from_source
    run_step "Configuring Nginx..." configure_nginx
    run_step "Configuring Redis..." configure_redis

    summary
}

main "$@"
