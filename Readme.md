# 🚀 Server Setup Scripts

Automated server provisioning scripts for Ubuntu/Debian servers. Installs and configures Node.js, PM2, Nginx, Git, and sets up SSH keys for GitHub.

## ✨ Features

* ✅  **Automated Installation** : Node.js, PM2, Nginx, Git
* ✅  **SSH Key Management** : Creates keys and waits for GitHub authorization
* ✅  **Version Control** : Clone repositories via SSH
* ✅  **Verification** : Confirms all installations succeeded
* ✅  **Logging** : Full operation logs for debugging
* ✅  **Error Handling** : Graceful failure with helpful messages
* ✅  **Interactive** : Prompts for user choices and confirmations

## 🎯 Quick Start

### One-Line Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Maaniksharma/deployNewServer/main/script.sh -o script.sh && chmod +x script.sh && sudo ./script.sh
```

### What This Does

1. Downloads the setup script from GitHub
2. Shows you a preview of what will run
3. Asks for confirmation
4. Executes the server setup
5. Installs Node.js, PM2, Nginx (optional)
6. Sets up SSH keys for GitHub
7. Clones your repository

## 📋 Requirements

* **OS** : Ubuntu 18.04+ or Debian 10+
* **Access** : Root/sudo privileges
* **Network** : Internet connection
* **GitHub** : Account for SSH key setup

## 🔧 Manual Installation

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/Maaniksharma/deployNewServer/refs/heads/main/script.sh -o script.sh

# Review it (important!)
cat ./script.sh

# Make executable
chmod +x ./script.sh

# Run as root
sudo ./script.sh
```

## 📖 What Gets Installed

| Component | Purpose                       | Optional              |
| --------- | ----------------------------- | --------------------- |
| Node.js   | JavaScript runtime            | Yes (choose version)  |
| NPM       | Node package manager          | Included with Node.js |
| PM2       | Process manager for Node apps | Yes                   |
| Nginx     | Web server / reverse proxy    | Yes                   |
| Git       | Version control               | Required              |
| SSH Key   | GitHub authentication         | Yes (can skip)        |

## Usage Flow

```
1. Start script
   ↓
2. Choose Node.js version (or skip)
   ↓
3. Choose to install PM2 (or skip)
   ↓
4. Choose to install Nginx (or skip)
   ↓
5. Generate SSH key (or use existing)
   ↓
6. Add key to GitHub (script waits and retries)
   ↓
7. Enter repository URL to clone
   ↓
8. Done! 🎉
```

## 🔐 Security

* ✅ Runs with root privileges (required for system-wide installation)
* ✅ Asks for confirmation before execution
* ✅ Shows script preview before running
* ✅ Validates all downloads
* ✅ Uses HTTPS for all downloads
* ✅ No hardcoded credentials
* ✅ SSH keys generated locally

## 📊 Example Session

```bash
$ curl -fsSL https://raw.githubusercontent.com/Maaniksharma/deployNewServer/refs/heads/main/script.sh | sudo bash


⚠️  WARNING: SERVER PROVISIONING SCRIPT

This script will:
 - Install/Update Node.js (you choose major version)
 - Install/Update Nginx, Git, and PM2
 - Create SSH key (if missing) and check GitHub SSH access
 - Clone a repo (SSH URL)

Are you running this on a FRESH server? (y/n): y

🚀 Starting Setup...
--------------------------------------------------------
✅ curl is already installed
✅ ca-certificates is already installed
...
```

## 🐛 Troubleshooting

### Script Download Fails

**Problem:** `Failed to download script from GitHub`

**Solutions:**

* Check USERNAME/REPO/BRANCH are correct
* Test URL manually: `curl -I https://raw.githubusercontent.com/Maaniksharma/deployNewServer/refs/heads/main/script.sh`

### Permission Denied

**Problem:** `This script must be run as root`

**Solution:**

```bash
# Add sudo to the command
curl -fsSL https://raw.githubusercontent.com/Maaniksharma/deployNewServer/refs/heads/main/script.sh | sudo bash
```

### SSH Key Issues

**Problem:** Script keeps waiting for SSH authorization

**Solution:**

1. Copy the public key shown in the terminal
2. Go to https://github.com/settings/ssh/new or go to https://github.com/Username/repo-name/settings/keys for a specific repository
3. Paste and save
4. Script will auto-detect and continue

## 📁 Files in This Repository

* **script.sh** - Main setup script with verification
* **bootstrap.sh** - Safe bootstrap wrapper with confirmation
* **quick-setup.sh** - Quick one-liner (no confirmation)
* **BOOTSTRAP_GUIDE.md** - Comprehensive documentation
* **README.md** - This file

## 📝 Logs

All operations are logged to: `/var/log/server-setup-YYYYMMDD-HHMMSS.log`

View logs:

```bash
# Find latest log
ls -lt /var/log/server-setup-*.log | head -1

# View it
tail -f /var/log/server-setup-*.log
```

## 🤝 Contributing

Feel free to fork, modify, and improve these scripts!

## ⚠️ Disclaimer

These scripts modify system configurations. Always:

* Run on fresh servers
* Understand what each command does

## 📄 License

MIT License - Use freely, modify as needed

**Made with ❤️ for easy server provisioning**
