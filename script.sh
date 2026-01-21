#!/bin/bash

# --- CONFIGURATION ---
NODE_MAJOR=20

# --- SAFETY CHECKS ---

# 1. OS Detection (Prevent running on Mac/Windows/RedHat)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
else
    OS=$(uname -s)
fi

if [[ "$OS" != *"Ubuntu"* && "$OS" != *"Debian"* ]]; then
  echo "❌ ERROR: This script is designed for Ubuntu/Debian servers only."
  echo "   Your detected OS: $OS"
  echo "   Aborting to protect your system."
  exit 1
fi

# 2. Root Check
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (use sudo)"
  exit 1
fi

# 3. Confirmation Prompt (The "Are you sure?" check)
echo "⚠️  WARNING: SERVER PROVISIONING SCRIPT"
echo "   This script will:"
echo "   - Replace system Node.js with v$NODE_MAJOR"
echo "   - Install Nginx, Git, and PM2"
echo "   - Modify Firewall settings"
echo
read -p "Are you running this on a FRESH server? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "❌ Aborted."
  exit 1
fi

echo "🚀 Starting Setup..."
echo "--------------------------------------------------------"

# 2. Node.js Check/Install
if command -v node >/dev/null 2>&1; then
  CURRENT_VER=$(node -v)
  echo "✅ Node.js is already installed: $CURRENT_VER"
else
  echo "❌ Node.js is not installed"
  echo "📦 Installing Node.js v$NODE_MAJOR (system-wide)..."

  # Clean cleanup
  apt-get remove -y nodejs >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true

  # Dependencies
  apt-get update -y
  apt-get install -y curl ca-certificates gnupg

  # Add NodeSource repo
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

  # Install
  apt-get update -y
  apt-get install -y nodejs

  # Verify
  echo "✅ Node installed:"
  node -v
  npm -v
fi

# --- PM2 SETUP ---
if command -v pm2 >/dev/null 2>&1; then
  echo "✅ PM2 is already installed"
else
  echo "📦 Installing PM2 Global Process Manager..."
  npm install -g pm2
  pm2 startup systemd -u root --hp /root >/dev/null 2>&1
  echo "✅ PM2 installed and configured for startup"
fi

# --- NGINX SETUP ---
if command -v nginx >/dev/null 2>&1; then
  echo "✅ Nginx is already installed"
else
  echo "📦 Installing Nginx..."
  apt-get install -y nginx
  echo "✅ Nginx installed"
fi

# 3. Git Check/Install
if command -v git >/dev/null 2>&1; then
  echo "✅ Git is already installed"
else
  echo "📦 Git not found. Installing..."
  apt-get update -y
  apt-get install -y git
  echo "✅ Git installed successfully"
fi

# 4. SSH Setup (Handling Root vs User)
# NOTE: Since we are root, $HOME is /root. 
# This is fine for servers where you ONLY operate as root.
SSH_DIR="$HOME/.ssh"
KEY="$SSH_DIR/id_ed25519"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ ! -f "$KEY" ]; then
  echo "🔐 Creating SSH key..."
  # -q silences the output, -N "" sets empty passphrase
  if [ -z "$EMAIL" ]; then
     read -p "Enter email for SSH key: " EMAIL
  fi
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY" -N "" -q
  
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add "$KEY" >/dev/null
else
  echo "✅ SSH key already exists at: $KEY"
fi

# 5. The Auth Loop
while true; do
  echo
  echo "🔍 Checking Git SSH access..."

  # We use StrictHostKeyChecking=no to avoid the "Are you sure?" prompt breaking the script
  if ssh -o StrictHostKeyChecking=no -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "✅ Git SSH is configured correctly!"
    break
  fi

  echo "❌ Git SSH is not authorized yet."
  echo
  echo "👉 COPY AND ADD THIS KEY TO GITHUB:"
  echo "----------------------------------------------------"
  cat "$KEY.pub"
  echo "----------------------------------------------------"
  echo "🔗 URL: https://github.com/settings/ssh/new"
  echo
  read -p "Press ENTER once you have added the key to GitHub..."
done

# 6. Clone Repo
echo
read -p "Enter the SSH repo URL to clone: " REPO_URL

# Optional: Ask where to clone it
# read -p "Enter directory name (leave empty for default): " DIR_NAME

if [ -z "$DIR_NAME" ]; then
  git clone "$REPO_URL"
else
  git clone "$REPO_URL" "$DIR_NAME"
fi

echo "🎉 Setup Complete!"