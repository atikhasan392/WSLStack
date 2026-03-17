#!/usr/bin/env bash

install_redis() {
    log_info "Installing Redis..."
    apt_install "${REDIS_PACKAGE}"

    if [[ -f /etc/redis/redis.conf ]]; then
        sed -i 's/^supervised .*/supervised no/' /etc/redis/redis.conf || true
        sed -i 's/^bind .*/bind 127.0.0.1 ::1/' /etc/redis/redis.conf || true
    fi

    service_enable_start redis-server || service_enable_start redis || true
}
