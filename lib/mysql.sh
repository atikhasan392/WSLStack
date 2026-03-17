#!/usr/bin/env bash

mysql_service_name() {
    if systemctl list-unit-files 2>/dev/null | grep -q '^mysql\.service'; then
        printf 'mysql'
        return
    fi

    if systemctl list-unit-files 2>/dev/null | grep -q '^mysqld\.service'; then
        printf 'mysqld'
        return
    fi

    printf 'mysql'
}

mysql_is_installed() {
    command_exists mysql
}

configure_mysql_root_passwordless() {
    log_info "Configuring MySQL root user for passwordless local access..."

    mysql --protocol=socket -uroot <<'SQL' || die "Failed to configure MySQL root authentication."
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
}

create_default_database() {
    log_info "Creating default database..."
    mysql --protocol=tcp -h127.0.0.1 -uroot --password='' <<'SQL' || log_warn "Could not create default database."
CREATE DATABASE IF NOT EXISTS wslstack CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SQL
}

apply_mysql_config() {
    local target="/etc/mysql/conf.d/wslstack.cnf"

    if [[ -f "${SCRIPT_DIR}/templates/my.cnf" ]]; then
        cp -f "${SCRIPT_DIR}/templates/my.cnf" "${target}"
        log_info "Applied MySQL config template."
    else
        log_warn "MySQL template not found: ${SCRIPT_DIR}/templates/my.cnf"
    fi
}

wait_for_mysql() {
    local attempts=20
    local i

    for ((i=1; i<=attempts; i++)); do
        if mysqladmin ping --silent >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done

    return 1
}

install_mysql() {
    local service_name
    service_name="$(mysql_service_name)"

    if mysql_is_installed; then
        log_info "MySQL already installed."
    else
        log_info "Installing MySQL..."
        apt_install "${MYSQL_PACKAGE}"
    fi

    apply_mysql_config

    service_enable_start "${service_name}"

    if ! wait_for_mysql; then
        die "MySQL service did not become ready in time."
    fi

    configure_mysql_root_passwordless
    create_default_database

    log_info "MySQL setup completed."
}