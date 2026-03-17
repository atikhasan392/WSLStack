# WSLStack

WSLStack is a native Laravel development environment installer for WSL2 on Ubuntu and Debian.

## Current status

This is an initial modular installer scaffold. It is designed for local development only.

## Install

```bash
git clone https://github.com/yourname/wslstack.git
cd wslstack
sudo bash install.sh
```

## Remote install target

```bash
bash <(curl -fsSL https://wslstack.pages.dev/install.sh)
```

## Project structure

```text
wslstack/
├── index.html
├── install.sh
├── versions.sh
├── lib/
│   ├── common.sh
│   ├── system.sh
│   ├── php.sh
│   ├── composer.sh
│   ├── node.sh
│   ├── nginx.sh
│   ├── mysql.sh
│   ├── phpmyadmin.sh
│   ├── redis.sh
│   └── git.sh
├── templates/
│   ├── nginx-site.conf
│   ├── phpmyadmin.conf
│   └── my.cnf
├── README.md
└── LICENSE
```

## Notes

- WSL2 only
- Ubuntu and Debian only
- Native install only
- Not for production use

## Environment variables

```bash
PHP_VERSION=8.5 NODE_VERSION=25.8.1 sudo -E bash install.sh
```
