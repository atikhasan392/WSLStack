# WSLStack – Ubuntu LAMP Dev Environment Setup

A fully automated development environment setup script for Ubuntu 24.04 (WSL or native), designed for modern PHP/Laravel development.

This script installs and configures a complete LAMP stack with the latest tools, including PHP 8.5, MySQL 8.4, Node.js 24, Bun, Composer, and phpMyAdmin.

---

## ✨ Features

* PHP 8.5 with essential extensions
* Apache + PHP-FPM integration
* MySQL 8.4 LTS with preconfigured admin user
* Composer (latest)
* Node.js 24 via NVM
* Yarn + npm-check-updates
* Bun runtime
* phpMyAdmin with auto-login
* Fully automated setup (one command)

---

## 🧰 Tech Stack

* Ubuntu 24.04
* PHP 8.5
* MySQL 8.4
* Apache 2
* Node.js 24 (NVM)
* Bun
* Composer

---

## 🚀 Installation

```bash
chmod +x install.sh
sed -i 's/\r$//' install.sh
sudo bash install.sh
```

---

## 🔐 Default Credentials

⚠️ Change these immediately after installation.

```text
MySQL User: admin
MySQL Pass: Admin@1234
```

---

## 🌐 Access

* phpMyAdmin: [http://localhost/phpmyadmin](http://localhost/phpmyadmin)

---

## ⚙️ Laravel Configuration

Add this to your `.env` file:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=your_database
DB_USERNAME=admin
DB_PASSWORD=Admin@1234
```

---

## 👤 Node & Bun Setup

Installed for your system user (not root):

```bash
source ~/.bashrc
node -v
bun -v
```

---

## ⚠️ Security Notes

* This setup is intended for local development only
* phpMyAdmin auto-login is insecure for production
* Default MySQL credentials should be changed immediately
* Do not expose this environment to the public internet

---

## 📜 License

MIT License

---

## 🤝 Contributing

Pull requests are welcome. For major changes, open an issue first.

---

## 👨‍💻 Author

ATik HaSan
[https://atikhasan.com](https://atikhasan.com)

---

## 💡 Summary

This script eliminates repetitive setup steps and gives you a ready-to-use PHP/Laravel development environment in minutes.
