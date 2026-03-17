#!/usr/bin/env bash

detect_arch() {
    local machine
    machine="$(uname -m)"

    case "${machine}" in
        x86_64) export WSLSTACK_ARCH="x64" ;;
        aarch64|arm64) export WSLSTACK_ARCH="arm64" ;;
        *)
            die "Unsupported CPU architecture: ${machine}"
            ;;
    esac

    log_info "Detected architecture: ${WSLSTACK_ARCH}"
}

detect_wsl2() {
    [[ -f /proc/version ]] || die "Cannot verify WSL environment."

    if ! grep -qi microsoft /proc/version; then
        die "This installer only supports WSL."
    fi

    if ! grep -qiE 'WSL2|microsoft-standard-WSL2' /proc/sys/kernel/osrelease && ! uname -r | grep -qi microsoft; then
        die "WSL2 is required."
    fi

    log_info "WSL environment detected."
}

detect_os() {
    [[ -f /etc/os-release ]] || die "Cannot read /etc/os-release"

    # shellcheck disable=SC1091
    source /etc/os-release

    export DISTRO_ID="${ID}"
    export DISTRO_CODENAME="${VERSION_CODENAME:-}"

    case "${DISTRO_ID}" in
        ubuntu|debian)
            ;;
        *)
            die "Unsupported OS: ${DISTRO_ID}. Only Ubuntu and Debian are supported."
            ;;
    esac

    if [[ -z "${DISTRO_CODENAME}" ]]; then
        DISTRO_CODENAME="$(lsb_release -sc 2>/dev/null || true)"
        export DISTRO_CODENAME
    fi

    [[ -n "${DISTRO_CODENAME}" ]] || die "Could not detect distro codename."
    log_info "Detected OS: ${DISTRO_ID} (${DISTRO_CODENAME})"
}

prepare_system() {
    log_info "Updating apt package index..."
    retry 3 apt-get update || die "apt update failed."

    log_info "Installing base dependencies..."
    apt_install "${REQUIRED_BASE_PACKAGES[@]}"

    mkdir -p /etc/apt/keyrings
}
