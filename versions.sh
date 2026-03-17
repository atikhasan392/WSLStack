#!/usr/bin/env bash

export WSLSTACK_NAME="WSLStack"
export WSLSTACK_VERSION="0.1.0"

# Exact version locks
export PHP_VERSION="${PHP_VERSION:-8.4}"
export COMPOSER_VERSION="${COMPOSER_VERSION:-2.9.5}"
export NODE_VERSION="${NODE_VERSION:-24.14.0}"
export PHPMYADMIN_VERSION="${PHPMYADMIN_VERSION:-5.2.3}"
export MYSQL_VERSION_SERIES="${MYSQL_VERSION_SERIES:-8.4-lts}"
export REDIS_VERSION_SERIES="${REDIS_VERSION_SERIES:-8.6}"
export GIT_VERSION_SERIES="${GIT_VERSION_SERIES:-2.53.0}"

# Package names
export NGINX_PACKAGE="${NGINX_PACKAGE:-nginx}"
export MYSQL_PACKAGE="${MYSQL_PACKAGE:-mysql-community-server}"
export MYSQL_CLIENT_PACKAGE="${MYSQL_CLIENT_PACKAGE:-mysql-community-client}"
export REDIS_PACKAGE="${REDIS_PACKAGE:-redis}"
export GIT_PACKAGE="${GIT_PACKAGE:-git}"

# PHP packages
export PHP_PACKAGES=(
  "php${PHP_VERSION}"
  "php${PHP_VERSION}-cli"
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
)

export PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
export PHP_INI_CLI="/etc/php/${PHP_VERSION}/cli/php.ini"
export PHP_INI_FPM="/etc/php/${PHP_VERSION}/fpm/php.ini"

# Base dependencies
export REQUIRED_BASE_PACKAGES=(
  ca-certificates
  curl
  wget
  gnupg
  lsb-release
  software-properties-common
  apt-transport-https
  unzip
  tar
  xz-utils
  jq
  openssl
  debconf-utils
)

# MySQL / phpMyAdmin / local dev defaults
export MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
export MYSQL_DEFAULT_DATABASE="${MYSQL_DEFAULT_DATABASE:-wslstack}"
export PHPMYADMIN_ALIAS="${PHPMYADMIN_ALIAS:-phpmyadmin}"

# PHP recommended local-dev settings
export PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-1024M}"
export PHP_UPLOAD_MAX_FILESIZE="${PHP_UPLOAD_MAX_FILESIZE:-5120M}"
export PHP_POST_MAX_SIZE="${PHP_POST_MAX_SIZE:-512M}"
export PHP_MAX_INPUT_VARS="${PHP_MAX_INPUT_VARS:-3000}"
export PHP_DATE_TIMEZONE="${PHP_DATE_TIMEZONE:-Asia/Dhaka}"
export PHP_DISPLAY_ERRORS="${PHP_DISPLAY_ERRORS:-On}"
export PHP_LOG_ERRORS="${PHP_LOG_ERRORS:-On}"
export PHP_MAX_FILE_UPLOADS="${PHP_MAX_FILE_UPLOADS:-100}"
export PHP_REALPATH_CACHE_SIZE="${PHP_REALPATH_CACHE_SIZE:-16M}"
