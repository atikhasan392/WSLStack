#!/usr/bin/env bash

phpmyadmin_install_dir() {
    printf '/usr/share/phpmyadmin'
}

phpmyadmin_archive_name() {
    printf 'phpMyAdmin-%s-all-languages.tar.gz' "${PHPMYADMIN_VERSION}"
}

phpmyadmin_download_url() {
    printf 'https://files.phpmyadmin.net/phpMyAdmin/%s/phpMyAdmin-%s-all-languages.tar.gz' "${PHPMYADMIN_VERSION}" "${PHPMYADMIN_VERSION}"
}

phpmyadmin_is_installed() {
    local install_dir
    install_dir="$(phpmyadmin_install_dir)"
    [[ -f "${install_dir}/index.php" ]]
}

install_phpmyadmin_files() {
    local install_dir archive url extracted_dir
    install_dir="$(phpmyadmin_install_dir)"
    archive="/tmp/$(phpmyadmin_archive_name)"
    url="$(phpmyadmin_download_url)"
    extracted_dir="/usr/share/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages"

    if phpmyadmin_is_installed; then
        log_info "phpMyAdmin already installed."
        return 0
    fi

    log_info "Installing phpMyAdmin ${PHPMYADMIN_VERSION}..."
    download_file "${url}" "${archive}"

    rm -rf "${install_dir}" "${extracted_dir}"
    mkdir -p /usr/share
    tar -xzf "${archive}" -C /usr/share || die "Failed to extract phpMyAdmin archive."

    mv "${extracted_dir}" "${install_dir}" || die "Failed to move phpMyAdmin into place."

    mkdir -p "${install_dir}/tmp"
    chmod 777 "${install_dir}/tmp"
}

write_phpmyadmin_config() {
    local install_dir blowfish_secret
    install_dir="$(phpmyadmin_install_dir)"

    if [[ -f "${install_dir}/config.inc.php" ]]; then
        log_info "phpMyAdmin config already exists."
        return 0
    fi

    blowfish_secret="$(openssl rand -hex 16)"

    cat > "${install_dir}/config.inc.php" <<EOF
<?php
\$cfg['blowfish_secret'] = '${blowfish_secret}';

\$i = 0;
\$i++;

\$cfg['Servers'][\$i]['auth_type'] = 'config';
\$cfg['Servers'][\$i]['host'] = '127.0.0.1';
\$cfg['Servers'][\$i]['port'] = '3306';
\$cfg['Servers'][\$i]['user'] = 'root';
\$cfg['Servers'][\$i]['password'] = '';
\$cfg['Servers'][\$i]['AllowNoPassword'] = true;
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowRoot'] = true;

\$cfg['LoginCookieValidity'] = 31536000;
\$cfg['TempDir'] = '${install_dir}/tmp';
EOF

    log_info "phpMyAdmin config written."
}

apply_phpmyadmin_nginx_template() {
    local template="${SCRIPT_DIR}/templates/phpmyadmin.conf"
    local target="/etc/nginx/snippets/${PHPMYADMIN_ALIAS}.conf"

    [[ -f "${template}" ]] || die "phpMyAdmin template not found."

    mkdir -p /etc/nginx/snippets

    sed -e "s/__PHP_VERSION__/${PHP_VERSION}/g" \
        -e "s#__PHPMYADMIN_ALIAS__#${PHPMYADMIN_ALIAS}#g" \
        "${template}" > "${target}"

    log_info "phpMyAdmin Nginx config applied."
}

install_phpmyadmin() {
    install_phpmyadmin_files
    write_phpmyadmin_config
    apply_phpmyadmin_nginx_template

    nginx -t || die "Nginx config test failed after phpMyAdmin setup."
    service_enable_start nginx

    log_info "phpMyAdmin setup completed."
}