#!/usr/bin/env bash

export WSLSTACK_NAME="WSLStack"
export WSLSTACK_VERSION="1.2.0"

# Supported values:
# PHP_VERSION: 8.4 | 8.5
# NODE_VERSION: 24.14.0 | 25.8.1
export PHP_VERSION="${PHP_VERSION:-8.4}"
export COMPOSER_VERSION="${COMPOSER_VERSION:-2.9.5}"
export NODE_VERSION="${NODE_VERSION:-24.14.0}"

# Package families that can be tuned later.
export NGINX_PACKAGE="${NGINX_PACKAGE:-nginx}"
export MYSQL_PACKAGE="${MYSQL_PACKAGE:-mysql-server}"
export REDIS_PACKAGE="${REDIS_PACKAGE:-redis-server}"
export GIT_PACKAGE="${GIT_PACKAGE:-git}"

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
)

export PHPMYADMIN_VERSION="${PHPMYADMIN_VERSION:-5.2.2}"
export MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"
export PHPMYADMIN_ALIAS="${PHPMYADMIN_ALIAS:-phpmyadmin}"
