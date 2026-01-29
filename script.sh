#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# --- CONFIGURATION ---
DEFAULT_NODE_MAJOR=20
RETRY_SSH_INTERVAL=10
MAX_SSH_ATTEMPTS=60   # ~10 minutes max wait for manual GitHub key add
LOGFILE="/var/log/server-setup-$(date +%Y%m%d-%H%M%S).log"

# Logging function
log() {
    echo "$@" | tee -a "$LOGFILE"
}

# Cleanup function
cleanup_on_error() {
    if [ $? -ne 0 ]; then
        log "❌ Script failed. Check log at: $LOGFILE"
    fi
}

trap cleanup_on_error EXIT

log "📝 Logging to: $LOGFILE"

# --- SAFETY CHECKS ---
# 1. OS Detection (only allow Debian/Ubuntu)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS="$NAME"
    CODENAME="${VERSION_CODENAME:-}"
elif type lsb_release >/dev/null 2>&1; then
    OS="$(lsb_release -si)"
    CODENAME="$(lsb_release -sc)"
else
    OS="$(uname -s)"
    CODENAME=""
fi

if [[ "$OS" != *"Ubuntu"* && "$OS" != *"Debian"* ]]; then
  log "❌ ERROR: This script is designed for Ubuntu/Debian servers only."
  log "   Detected OS: $OS"
  exit 1
fi

# 2. Root Check
if [ "$EUID" -ne 0 ]; then
  log "❌ Please run as root (use sudo)"
  exit 1
fi

# 3. Confirmation Prompt
cat <<EOF
⚠️  WARNING: SERVER PROVISIONING SCRIPT

This script will:
 - Install/Update Node.js (you choose major version)
 - Install/Update Nginx, Git, and PM2
 - Create SSH key (if missing) and check GitHub SSH access
 - Clone a repo (SSH URL)
EOF

read -p "Are you running this on a FRESH server? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  log "❌ Aborted."
  exit 1
fi

log "🚀 Starting Setup..."
log "--------------------------------------------------------"

# Helper to ensure packages installed non-interactively
export DEBIAN_FRONTEND=noninteractive

apt_get_update_if_needed() {
  if [ ! -f /var/lib/apt/periodic/update-success-stamp ] || [ "$(find /var/lib/apt/periodic/update-success-stamp -mtime -1 2>/dev/null || true)" = "" ]; then
    log "🔄 Updating package lists..."
    apt-get update -y >> "$LOGFILE" 2>&1
  fi
}

install_package_if_missing() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    log "📦 Installing $pkg..."
    apt-get install -y "$pkg" >> "$LOGFILE" 2>&1
  else
    log "✅ $pkg is already installed"
  fi
}

# Ensure basic tools present
apt_get_update_if_needed
install_package_if_missing curl
install_package_if_missing ca-certificates
install_package_if_missing gnupg
install_package_if_missing lsb-release
install_package_if_missing git
install_package_if_missing openssh-client
install_package_if_missing openssh-server

# --- Node.js Check/Install ---
if command -v node >/dev/null 2>&1; then
  CURRENT_VER=$(node -v)
  log "✅ Node.js is already installed: $CURRENT_VER"
else
  log "❌ Node.js is not installed"
  read -p "Do you want to install Node.js? (y/n): " INSTALL_NODE
  if [[ "$INSTALL_NODE" == "y" ]]; then
      # Validate Node version input
      while true; do
          read -p "Enter Node.js major version (default: ${DEFAULT_NODE_MAJOR}): " NODE_MAJOR
          NODE_MAJOR=${NODE_MAJOR:-$DEFAULT_NODE_MAJOR}
          
          if [[ "$NODE_MAJOR" =~ ^[0-9]+$ ]] && [ "$NODE_MAJOR" -ge 14 ] && [ "$NODE_MAJOR" -le 24 ]; then
              break
          else
              log "❌ Invalid version. Please enter a number between 14 and 22."
          fi
      done

      log "📦 Installing Node.js v$NODE_MAJOR (system-wide)..."
      # Use NodeSource setup script (recommended by NodeSource)
      curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - >> "$LOGFILE" 2>&1
      apt-get install -y nodejs >> "$LOGFILE" 2>&1

      # Verify installation was successful
      if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
          log "✅ Node.js installed successfully:"
          log "   Node: $(node -v)"
          log "   NPM: $(npm -v)"
      else
          log "❌ Node.js installation failed. Check log: $LOGFILE"
      fi
  else
      log "⚠️ Skipping Node.js installation."
  fi
fi

# --- PM2 SETUP ---
if command -v pm2 >/dev/null 2>&1; then
  log "✅ PM2 is already installed ($(pm2 -v))"
else
  log "❌ PM2 is not installed"
  read -p "Do you want to install PM2 globally via npm? (y/n): " INSTALL_PM2
  if [[ "$INSTALL_PM2" == "y" ]]; then
      if ! command -v npm >/dev/null 2>&1; then
        log "❌ npm not found — Node is required for PM2. Please install Node first."
      else
        log "📦 Installing PM2..."
        npm install -g pm2 >> "$LOGFILE" 2>&1
        
        # Verify PM2 installation was successful
        if command -v pm2 >/dev/null 2>&1; then
            log "✅ PM2 installed successfully ($(pm2 -v))"
            
            # Configure PM2 startup
            log "🔧 Configuring PM2 startup..."
            STARTUP_CMD=$(pm2 startup systemd -u root --hp /root | grep "sudo env" || true)
            if [ -n "$STARTUP_CMD" ]; then
                # Remove 'sudo' from the command since we're already root
                STARTUP_CMD=${STARTUP_CMD#sudo }
                log "Executing: $STARTUP_CMD"
                eval "$STARTUP_CMD" >> "$LOGFILE" 2>&1 || true
            fi
            pm2 save >> "$LOGFILE" 2>&1 || true
            log "✅ PM2 configured for startup"
        else
            log "❌ PM2 installation failed. Check log: $LOGFILE"
        fi
      fi
  else
      log "⚠️ Skipping PM2 installation."
  fi
fi

# --- NGINX SETUP ---
if command -v nginx >/dev/null 2>&1; then
  log "✅ Nginx is already installed ($(nginx -v 2>&1))"
else
  log "❌ Nginx is not installed"
  read -p "Do you want to install Nginx? (y/n): " INSTALL_NGINX
  if [[ "$INSTALL_NGINX" == "y" ]]; then
      log "📦 Installing Nginx..."
      apt-get install -y nginx >> "$LOGFILE" 2>&1
      
      # Verify installation was successful
      if command -v nginx >/dev/null 2>&1; then
          systemctl enable --now nginx >> "$LOGFILE" 2>&1
          
          # Check if service started successfully
          if systemctl is-active --quiet nginx; then
              log "✅ Nginx installed and started ($(nginx -v 2>&1))"
          else
              log "⚠️ Nginx installed but failed to start. Check: systemctl status nginx"
          fi
      else
          log "❌ Nginx installation failed. Check log: $LOGFILE"
      fi
  else
      log "⚠️ Skipping Nginx installation."
  fi
fi

# --- GIT (already ensured earlier) ---
if command -v git >/dev/null 2>&1; then
  log "✅ Git is available ($(git --version))"
else
  log "❌ Git not available after attempted install."
fi

# --- SSH Setup (root) ---
SSH_DIR="$HOME/.ssh"
KEY="$SSH_DIR/id_ed25519"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ ! -f "$KEY" ]; then
  log "🔐 Creating SSH key..."
  read -p "Enter email for SSH key (leave empty to skip key generation): " EMAIL
  if [ -z "$EMAIL" ]; then
    log "⚠️ No email provided. Skipping key generation."
  else
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY" -N "" -q
    chmod 600 "$KEY"
    chmod 644 "$KEY.pub"
    log "✅ SSH key created at $KEY"
    
    # Add to ssh-agent if running
    if pgrep -x ssh-agent > /dev/null; then
        eval "$(ssh-agent -s)" >> "$LOGFILE" 2>&1 || true
        ssh-add "$KEY" >> "$LOGFILE" 2>&1 || true
    fi
  fi
else
  log "✅ SSH key already exists at: $KEY"
fi

# --- The Auth Loop (wait for user to add key to GitHub) ---
if [ -f "$KEY.pub" ]; then
  log ""
  log "🔍 Checking Git SSH access..."
  attempts=0
  
  while true; do
    attempts=$((attempts+1))
    
    # FIX: Add StrictHostKeyChecking=accept-new to avoid hanging on first connection
    output=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
    
    if echo "$output" | grep -q -E "successfully authenticated|Hi .*! You've successfully authenticated"; then
      log "✅ Git SSH is configured correctly!"
      break
    fi

    if echo "$output" | grep -q "Permission denied (publickey)"; then
      log "❌ Git SSH is not authorized yet."
    else
      log "⚠️ SSH test returned: $output"
    fi

    log ""
    log "👉 COPY AND ADD THIS KEY TO GITHUB (or your Git host):"
    log "----------------------------------------------------"
    cat "$KEY.pub"
    log "----------------------------------------------------"
    log "🔗 URL: https://github.com/settings/ssh/new"
    log ""
    
    if [ "$attempts" -ge "$MAX_SSH_ATTEMPTS" ]; then
      log "❌ Reached max attempts ($MAX_SSH_ATTEMPTS). Aborting."
      exit 1
    fi
    
    log "Waiting $RETRY_SSH_INTERVAL seconds before retrying (attempt $attempts/$MAX_SSH_ATTEMPTS)..."
    sleep "$RETRY_SSH_INTERVAL"
  done
else
  log "⚠️ No public key available to show. Skipping Git SSH check."
fi

# --- Clone Repo ---
log ""
read -p "Enter the SSH repo URL to clone (e.g. git@github.com:user/repo.git): " REPO_URL

if [[ -z "$REPO_URL" ]]; then
  log "❌ No repo URL provided. Exiting."
  exit 1
fi

if [[ "$REPO_URL" =~ ^https?:// ]]; then
  log "❌ Error: Please use the SSH URL (git@...), not HTTP(S)."
  exit 1
fi

read -p "Enter directory name (leave empty to clone into repo folder): " DIR_NAME

# FIX: Check if directory already exists
if [ -n "$DIR_NAME" ] && [ -d "$DIR_NAME" ]; then
    log "❌ Error: Directory '$DIR_NAME' already exists."
    read -p "Remove and re-clone? (y/n): " REMOVE_DIR
    if [[ "$REMOVE_DIR" == "y" ]]; then
        rm -rf "$DIR_NAME"
    else
        log "❌ Aborting to avoid overwriting existing directory."
        exit 1
    fi
fi

log "📥 Cloning repository..."
if [ -z "$DIR_NAME" ]; then
  git clone "$REPO_URL" 2>&1 | tee -a "$LOGFILE" || { log "❌ git clone failed"; exit 1; }
else
  git clone "$REPO_URL" "$DIR_NAME" 2>&1 | tee -a "$LOGFILE" || { log "❌ git clone failed"; exit 1; }
fi

log ""
log "🎉 Setup Complete!"
log "📝 Full log available at: $LOGFILE"
