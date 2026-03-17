#!/usr/bin/env bash

install_git() {
    if command_exists git; then
        log_info "Git already installed: $(git --version)"
        return 0
    fi

    log_info "Installing Git..."
    apt_install "${GIT_PACKAGE}"
}
