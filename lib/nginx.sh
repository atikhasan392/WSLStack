#!/usr/bin/env bash

install_nginx() {
    log_info "Installing Nginx..."
    apt_install "${NGINX_PACKAGE}"

    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

    if [[ -f "${SCRIPT_DIR}/templates/nginx-site.conf" ]]; then
        sed "s/__PHP_VERSION__/${PHP_VERSION}/g" \
            "${SCRIPT_DIR}/templates/nginx-site.conf" \
            > /etc/nginx/sites-available/wslstack.conf

        ln -sf /etc/nginx/sites-available/wslstack.conf /etc/nginx/sites-enabled/wslstack.conf
    else
        die "Nginx site template not found."
    fi

    rm -f /etc/nginx/sites-enabled/default || true

    nginx -t || die "Nginx config test failed."
    service_enable_start nginx
}