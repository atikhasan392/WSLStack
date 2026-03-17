#!/usr/bin/env bash

if [[ -n "${WSLSTACK_COMMON_SH_LOADED:-}" ]]; then
    return 0
fi
readonly WSLSTACK_COMMON_SH_LOADED=1

readonly LOG_PREFIX="[WSLStack]"

log_info() {
    printf '%s [INFO] %s\n' "${LOG_PREFIX}" "$*"
}

log_warn() {
    printf '%s [WARN] %s\n' "${LOG_PREFIX}" "$*" >&2
}

log_error() {
    printf '%s [ERROR] %s\n' "${LOG_PREFIX}" "$*" >&2
}

die() {
    log_error "$*"
    exit 1
}

run() {
    log_info "$*"
    "$@"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "Run this installer as root: sudo bash install.sh"
    fi
}

print_banner() {
    cat <<'EOF'
========================================
              WSLStack
 Native Laravel development installer
========================================
EOF
}

safe_source() {
    local file="$1"
    [[ -f "${file}" ]] || die "Missing required file: ${file}"
    # shellcheck source=/dev/null
    source "${file}"
}

retry() {
    local attempts="${1:-3}"
    shift
    local count=1

    until "$@"; do
        if (( count >= attempts )); then
            return 1
        fi
        log_warn "Command failed. Retrying (${count}/${attempts})..."
        sleep 2
        ((count++))
    done
}

ensure_line_in_file() {
    local line="$1"
    local file="$2"

    mkdir -p "$(dirname "${file}")"
    touch "${file}"

    if ! grep -Fqx "${line}" "${file}"; then
        printf '%s\n' "${line}" >> "${file}"
    fi
}

write_file() {
    local target="$1"
    local content="$2"

    mkdir -p "$(dirname "${target}")"
    printf '%s' "${content}" > "${target}"
}

service_enable_start() {
    local service="$1"

    if command_exists systemctl && [[ -d /run/systemd/system ]]; then
        run systemctl enable --now "${service}"
        return 0
    fi

    if command_exists service; then
        run service "${service}" start || log_warn "Could not start ${service} via service command."
        return 0
    fi

    log_warn "No supported service manager detected. Please start ${service} manually."
}

apt_install() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

download_file() {
    local url="$1"
    local target="$2"
    retry 3 curl -fsSL "${url}" -o "${target}" || die "Failed to download: ${url}"
}

print_summary() {
    cat <<EOF
========================================
 Installation complete
========================================
PHP:        ${PHP_VERSION}
Composer:   ${COMPOSER_VERSION}
Node.js:    ${NODE_VERSION}
Nginx:      installed
MySQL:      installed
phpMyAdmin: installed
Redis:      installed
Git:        installed

Open phpMyAdmin:
http://localhost/${PHPMYADMIN_ALIAS}
========================================
EOF
}
