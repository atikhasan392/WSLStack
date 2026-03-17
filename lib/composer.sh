#!/usr/bin/env bash

install_composer() {
    local current=""
    if command_exists composer; then
        current="$(composer --version 2>/dev/null | awk '{print $3}' | sed 's/,//')"
    fi

    if [[ "${current}" == "${COMPOSER_VERSION}" ]]; then
        log_info "Composer ${COMPOSER_VERSION} already installed."
        return 0
    fi

    log_info "Installing Composer ${COMPOSER_VERSION}..."
    download_file "https://getcomposer.org/installer" "/tmp/composer-setup.php"
    php /tmp/composer-setup.php --version="${COMPOSER_VERSION}" --install-dir=/usr/local/bin --filename=composer \
        || die "Composer installation failed."

    composer --version >/dev/null 2>&1 || die "Composer was installed but is not working."
}
