#!/usr/bin/env bash

node_install_dir() {
    printf '/opt/node-v%s-linux-%s' "${NODE_VERSION}" "${WSLSTACK_ARCH}"
}

install_node() {
    case "${NODE_VERSION}" in
        24.14.0|25.8.1)
            ;;
        *)
            die "Unsupported NODE_VERSION: ${NODE_VERSION}. Use 24.14.0 or 25.8.1."
            ;;
    esac

    local current=""
    if command_exists node; then
        current="$(node -v 2>/dev/null | sed 's/^v//')"
    fi

    if [[ "${current}" == "${NODE_VERSION}" ]]; then
        log_info "Node.js ${NODE_VERSION} already installed."
        return 0
    fi

    local archive="node-v${NODE_VERSION}-linux-${WSLSTACK_ARCH}.tar.xz"
    local url="https://nodejs.org/dist/v${NODE_VERSION}/${archive}"
    local target="/tmp/${archive}"
    local install_dir
    install_dir="$(node_install_dir)"

    log_info "Installing Node.js ${NODE_VERSION}..."
    download_file "${url}" "${target}"

    rm -rf "${install_dir}"
    mkdir -p /opt
    tar -xJf "${target}" -C /opt

    ln -sf "${install_dir}/bin/node" /usr/local/bin/node
    ln -sf "${install_dir}/bin/npm" /usr/local/bin/npm
    ln -sf "${install_dir}/bin/npx" /usr/local/bin/npx
    ln -sf "${install_dir}/bin/corepack" /usr/local/bin/corepack

    node -v >/dev/null 2>&1 || die "Node.js install verification failed."
}
