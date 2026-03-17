#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=versions.sh
source "${SCRIPT_DIR}/versions.sh"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/system.sh
source "${SCRIPT_DIR}/lib/system.sh"
# shellcheck source=lib/php.sh
source "${SCRIPT_DIR}/lib/php.sh"
# shellcheck source=lib/composer.sh
source "${SCRIPT_DIR}/lib/composer.sh"
# shellcheck source=lib/node.sh
source "${SCRIPT_DIR}/lib/node.sh"
# shellcheck source=lib/nginx.sh
source "${SCRIPT_DIR}/lib/nginx.sh"
# shellcheck source=lib/mysql.sh
source "${SCRIPT_DIR}/lib/mysql.sh"
# shellcheck source=lib/phpmyadmin.sh
source "${SCRIPT_DIR}/lib/phpmyadmin.sh"
# shellcheck source=lib/redis.sh
source "${SCRIPT_DIR}/lib/redis.sh"
# shellcheck source=lib/git.sh
source "${SCRIPT_DIR}/lib/git.sh"

main() {
    require_root
    print_banner

    detect_arch
    detect_wsl2
    detect_os
    prepare_system

    install_git
    install_php
    install_composer
    install_node
    install_nginx
    install_mysql
    install_phpmyadmin
    install_redis

    print_summary
}

main "$@"
