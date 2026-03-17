#!/usr/bin/env bash

php_repo_configured() {
    if [[ "${DISTRO_ID}" == "ubuntu" ]]; then
        [[ -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list ]] || grep -Rqs "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null
    else
        [[ -f /etc/apt/sources.list.d/php.list ]] || grep -Rqs "packages.sury.org/php" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null
    fi
}

configure_php_repo() {
    if php_repo_configured; then
        log_info "PHP repository already configured."
        return 0
    fi

    if [[ "${DISTRO_ID}" == "ubuntu" ]]; then
        run add-apt-repository ppa:ondrej/php -y
    else
        download_file "https://packages.sury.org/php/apt.gpg" "/tmp/sury-php.gpg"
        run gpg --dearmor -o /etc/apt/keyrings/sury-php.gpg /tmp/sury-php.gpg
        printf 'deb [signed-by=/etc/apt/keyrings/sury-php.gpg] https://packages.sury.org/php/ %s main\n' "${DISTRO_CODENAME}" > /etc/apt/sources.list.d/php.list
    fi

    retry 3 apt-get update || die "Failed to refresh apt after adding PHP repo."
}

install_php() {
    case "${PHP_VERSION}" in
        8.4|8.5)
            ;;
        *)
            die "Unsupported PHP_VERSION: ${PHP_VERSION}. Use 8.4 or 8.5."
            ;;
    esac

    configure_php_repo

    log_info "Installing PHP ${PHP_VERSION} packages..."
    apt_install "${PHP_PACKAGES[@]}"

    if [[ -f "/etc/php/${PHP_VERSION}/cli/php.ini" ]]; then
        sed -i 's/^;date.timezone =.*/date.timezone = UTC/' "/etc/php/${PHP_VERSION}/cli/php.ini" || true
    fi

    if [[ -f "/etc/php/${PHP_VERSION}/fpm/php.ini" ]]; then
        sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' "/etc/php/${PHP_VERSION}/fpm/php.ini" || true
    fi

    service_enable_start "${PHP_FPM_SERVICE}"
}
