#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: playajames760
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://docs.anthropic.com/en/docs/claude-code

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
SPINNER_PID=""
SPINNER_ACTIVE=0
SPINNER_MSG=""
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  make \
  mc \
  git \
  build-essential \
  software-properties-common \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release \
  zsh \
  tmux \
  htop \
  neovim \
  unzip \
  jq \
  python3 \
  python3-pip \
  openssh-server \
  ufw \
  fail2ban \
  net-tools \
  libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
  libdrm2 libdbus-1-3 libxkbcommon0 libxcomposite1 libxdamage1 \
  libxrandr2 libgbm1 libasound2t64
msg_ok "Installed Dependencies"

msg_info "Setting up Node.js Repository"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - &>/dev/null
msg_ok "Set up Node.js Repository"

msg_info "Installing Node.js"
$STD apt-get install -y nodejs
msg_ok "Installed Node.js"

msg_info "Installing Package Managers"
$STD npm install -g yarn pnpm typescript
msg_ok "Installed Package Managers"

msg_info "Setting up Development User"
useradd -m -s /bin/zsh -G sudo dev
echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev

# Set password for dev user
if [[ -n "$PASSWORD" ]]; then
  # Use the password provided by the main script
  echo "dev:$PASSWORD" | chpasswd
  # Store password for display in main script
  echo "$PASSWORD" > /tmp/dev_password
else
  # Generate random password if none provided
  DEV_PW=$(openssl rand -base64 12)
  echo "dev:$DEV_PW" | chpasswd
  echo "$DEV_PW" > /tmp/dev_password
fi
msg_ok "Created Development User"

msg_info "Installing Oh My Zsh"
$STD su - dev -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
msg_ok "Installed Oh My Zsh"


msg_info "Installing Claude Code"
$STD npm install -g @anthropic-ai/claude-code
msg_ok "Installed Claude Code"


msg_info "Creating Development Directories"
su - dev -c 'mkdir -p ~/workspace'
msg_ok "Created Development Directories"

msg_info "Creating CLI Helper Scripts"
# Create a convenient setup command
cat > /usr/local/bin/claude-setup << 'EOF'
#!/bin/bash
# Quick setup script for Claude Code
if [ "$EUID" -eq 0 ]; then
    echo "Please run this as the dev user, not as root"
    exit 1
fi

/home/dev/first-run.sh
EOF
chmod +x /usr/local/bin/claude-setup

# Create a status command
cat > /usr/local/bin/claude-status << 'EOF'
#!/bin/bash
# Show Claude Code configuration status
echo "Claude Code Status:"
echo "==================="

if [ -f ~/.claude-configured ]; then
    echo "✅ Development environment configured"
else
    echo "❌ Development environment not configured - run 'claude-setup' to configure"
fi

echo
echo "MCP Configuration:"
if [ -f ~/.config/claude/claude_desktop_config.json ]; then
    echo "✅ Global MCP config exists"
elif [ -f ~/workspace/.mcp.json ]; then
    echo "✅ Workspace MCP config exists (~/workspace/.mcp.json)"
    echo "   Use: claude --mcp-config ~/workspace/.mcp.json"
else
    echo "❌ No MCP configuration found"
fi

echo
echo "Useful commands:"
echo "• claude-setup   - Configure Claude Code"
echo "• claude help    - Show Claude commands"
echo "• claude chat    - Start interactive chat"
echo "• claude --mcp-config ~/workspace/.mcp.json  - Start with MCP servers"
EOF
chmod +x /usr/local/bin/claude-status
msg_ok "Created CLI Helper Scripts"

msg_info "Configuring SSH"
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries.*/MaxAuthTries 6/' /etc/ssh/sshd_config
sed -i 's/#AddressFamily.*/AddressFamily any/' /etc/ssh/sshd_config
# Ensure AddressFamily is set if not present
grep -q "^AddressFamily" /etc/ssh/sshd_config || echo "AddressFamily any" >> /etc/ssh/sshd_config
# Enable SSH service on boot and restart it
systemctl enable ssh &>/dev/null || systemctl enable sshd &>/dev/null
systemctl restart ssh || systemctl restart sshd
# Verify SSH is running
if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
  msg_ok "Configured SSH"
else
  msg_error "SSH service failed to start"
  exit 1
fi

msg_info "Setting up Firewall"
ufw allow ssh &>/dev/null
echo "y" | ufw enable &>/dev/null
msg_ok "Set up Firewall"

msg_info "Creating Welcome Script"
cat > /home/dev/welcome.sh << 'EOF'
#!/bin/bash
echo "
╔══════════════════════════════════════════════════════════════╗
║          Welcome to Claude Code Development Environment      ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Quick Commands:                                             ║
║  • claude         - Start Claude Code CLI                    ║
║  • claude chat    - Start interactive chat                   ║
║  • claude commit  - Create a commit                          ║
║  • claude help    - Show all commands                        ║
║                                                              ║
║  With MCP servers:                                           ║
║  • claude --mcp-config ~/workspace/.mcp.json                 ║
║                                                              ║
║  Directories:                                                ║
║  • ~/workspace    - General workspace (contains .mcp.json)   ║
║                                                              ║
║  Setup Helper: ~/first-run.sh                                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"
EOF
chmod +x /home/dev/welcome.sh
echo "/home/dev/welcome.sh" >> /home/dev/.zshrc
chown -R dev:dev /home/dev
msg_ok "Created Welcome Script"

msg_info "Creating Setup Helper"
cat > /home/dev/setup-mcp.sh << 'EOF'
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

msg() {
    echo -e "${2}${1}${NC}"
}

setup_api_key() {
    local service_name="$1"
    local var_name="$2"
    local url="$3"
    
    msg "Get your $service_name API key from: $url" "$BLUE"
    read -s -p "Enter $service_name API key: " api_key
    echo
    if [[ -n "$api_key" ]]; then
        export $var_name="$api_key"
        return 0
    else
        msg "No API key provided, skipping $service_name" "$YELLOW"
        return 1
    fi
}

# Initialize MCP config file
MCP_CONFIG="$HOME/workspace/.mcp.json"
cat > "$MCP_CONFIG" << 'JSON'
{
  "mcpServers": {}
}
JSON

msg "=== MCP Servers Setup ===" "$BLUE"

# Puppeteer MCP (always install)
msg "Installing Puppeteer MCP..." "$GREEN"
jq '.mcpServers.puppeteer = {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
}' "$MCP_CONFIG" > "$MCP_CONFIG.tmp" && mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"

# Supabase MCP
if read -p "Install Supabase MCP? [y/N]: " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    if setup_api_key "Supabase" "SUPABASE_ACCESS_TOKEN" "https://supabase.com/dashboard/account/tokens"; then
        jq --arg token "$SUPABASE_ACCESS_TOKEN" '.mcpServers.supabase = {
          "command": "npx",
          "args": ["-y", "@supabase/mcp-server-supabase@latest", "--access-token", $token]
        }' "$MCP_CONFIG" > "$MCP_CONFIG.tmp" && mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"
        msg "✅ Supabase MCP added" "$GREEN"
    fi
fi

# DigitalOcean MCP
if read -p "Install DigitalOcean MCP? [y/N]: " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    if setup_api_key "DigitalOcean" "DIGITALOCEAN_API_TOKEN" "https://cloud.digitalocean.com/account/api/tokens"; then
        jq --arg token "$DIGITALOCEAN_API_TOKEN" '.mcpServers.digitalocean = {
          "command": "npx",
          "args": ["@digitalocean/mcp"],
          "env": {
            "DIGITALOCEAN_API_TOKEN": $token
          }
        }' "$MCP_CONFIG" > "$MCP_CONFIG.tmp" && mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"
        msg "✅ DigitalOcean MCP added" "$GREEN"
    fi
fi

# Shopify MCP
if read -p "Install Shopify Dev MCP? [y/N]: " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    jq '.mcpServers["shopify-dev"] = {
      "command": "npx",
      "args": ["-y", "@shopify/dev-mcp@latest"]
    }' "$MCP_CONFIG" > "$MCP_CONFIG.tmp" && mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"
    msg "✅ Shopify Dev MCP added" "$GREEN"
fi

# Upstash MCP
if read -p "Install Upstash MCP? [y/N]: " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    msg "Get your Upstash credentials from: https://console.upstash.com" "$BLUE"
    read -p "Enter Upstash email: " upstash_email
    read -s -p "Enter Upstash token: " upstash_token
    echo
    if [[ -n "$upstash_email" && -n "$upstash_token" ]]; then
        jq --arg email "$upstash_email" --arg token "$upstash_token" '.mcpServers.upstash = {
          "command": "npx",
          "args": ["-y", "@upstash/mcp-server", "run", $email, $token]
        }' "$MCP_CONFIG" > "$MCP_CONFIG.tmp" && mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"
        msg "✅ Upstash MCP added" "$GREEN"
    fi
fi

msg "\nMCP setup complete!" "$GREEN"
msg "Configuration saved to ~/workspace/.mcp.json" "$BLUE"
msg "Use 'claude --mcp-config ~/workspace/.mcp.json' to use these servers" "$BLUE"
EOF
chmod +x /home/dev/setup-mcp.sh
chown dev:dev /home/dev/setup-mcp.sh
msg_ok "Created MCP Setup Helper"

msg_info "Creating First-Run Configuration"
cat > /home/dev/first-run.sh << 'EOF'
#!/bin/bash

if [ ! -f ~/.claude-configured ]; then
    echo "
╔══════════════════════════════════════════════════════════════╗
║                First Time User Setup                         ║
╚══════════════════════════════════════════════════════════════╝
"
    echo "It is highly recommended to change the 'dev' user's password for security."
    echo "You will be prompted to enter a new password for the 'dev' user."
    
    # Check if we have a default password set
    if [ -f /tmp/dev_password ]; then
        OLD_PW=$(cat /tmp/dev_password)
        # Use a different approach for password change
        echo "Please enter a new password:"
        read -s NEW_PW1
        echo
        echo "Please confirm the new password:"
        read -s NEW_PW2
        echo
        
        if [ "$NEW_PW1" = "$NEW_PW2" ]; then
            echo -e "$OLD_PW\n$NEW_PW1\n$NEW_PW1" | passwd 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "✅ Password changed successfully!"
                rm -f /tmp/dev_password
                touch ~/.claude-configured
            else
                echo "❌ Failed to change password. You can try again later by running 'passwd'."
                echo "Note: To change password manually, use: sudo passwd dev"
            fi
        else
            echo "❌ Passwords do not match. You can try again later by running 'passwd'."
        fi
    else
        # If no default password file exists, suggest using sudo
        echo "❌ Unable to change password automatically."
        echo "Please run the following command to set a password:"
        echo "  sudo passwd dev"
        echo
        read -p "Press Enter to continue..."
        touch ~/.claude-configured
    fi
            
    echo
    echo "Would you like to set up MCP servers now?"
    read -p "Setup MCP servers? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ~/setup-mcp.sh
    fi
    clear
    ~/welcome.sh
else
    clear
    ~/welcome.sh
fi
EOF
chmod +x /home/dev/first-run.sh
echo "~/first-run.sh" >> /home/dev/.zshrc
chown dev:dev /home/dev/first-run.sh
msg_ok "Created First-Run Configuration"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
# Clean up home directory - only keep workspace and first-run.sh
su - dev -c 'find ~ -maxdepth 1 -type f ! -name "first-run.sh" ! -name ".zshrc" ! -name ".bashrc" ! -name ".profile" ! -name ".bash_logout" ! -name ".claude-configured" -delete 2>/dev/null || true'
su - dev -c 'rm -rf ~/.oh-my-zsh/.git 2>/dev/null || true'
su - dev -c 'rm -f ~/setup-mcp.sh ~/welcome.sh 2>/dev/null || true'
# Remove temporary password file
rm -f /tmp/dev_password
msg_ok "Cleaned"
