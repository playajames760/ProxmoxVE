#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/playajames760/ProxmoxVE/raw/main/LICENSE

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
su - dev -c 'claude mcp add puppeteer -- npx -y @modelcontextprotocol/server-puppeteer' &>/dev/null
msg_ok "Installed Claude Code"

msg_info "Setting up claude-nine"
# Handle git clone
if [ -d "/home/dev/claude-nine" ]; then
  su - dev -c 'rm -rf ~/claude-nine' &>/dev/null
fi
su - dev -c 'git clone https://github.com/playajames760/claude-nine.git ~/claude-nine' &>/dev/null
# Create .config/claude-code directory if it doesn't exist
su - dev -c 'mkdir -p ~/.config/claude-code' &>/dev/null
# Move commands directory
su - dev -c 'cp -r ~/claude-nine/commands ~/.config/claude-code/' &>/dev/null
su - dev -c 'rm -rf ~/claude-nine' &>/dev/null
msg_ok "Set up claude-nine"

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
echo "MCP Servers:"
claude mcp list 2>/dev/null || echo "No MCP servers configured"

echo
echo "Useful commands:"
echo "• claude-setup   - Configure Claude Code"
echo "• claude help    - Show Claude commands"
echo "• claude chat    - Start interactive chat"
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
║  Directories:                                                ║
║  • ~/workspace    - General workspace                        ║
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

# API Key setup function
setup_api_key() {
    local service=$1
    local key_name=$2
    local key_url=$3
    
    msg "\nSetting up $service..." "$YELLOW"
    msg "Get your API key from: $key_url" "$BLUE"
    read -s -p "Enter your $service API key (or press Enter to skip): " api_key
    echo
    
    if [[ -n "$api_key" ]]; then
        echo "export ${key_name}='$api_key'" >> ~/.zshrc
        echo "export ${key_name}='$api_key'" >> ~/.bashrc
        export ${key_name}="$api_key"
        msg "$service API key configured!" "$GREEN"
        return 0
    else
        msg "Skipping $service setup" "$YELLOW"
        return 1
    fi
}

msg "=== MCP Servers Setup ===" "$BLUE"

# Supabase MCP
if read -p "Install Supabase MCP? [y/N]: " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    if setup_api_key "Supabase" "SUPABASE_ACCESS_TOKEN" "https://supabase.com/dashboard/account/tokens"; then
        claude mcp add supabase -- npx -y @supabase/mcp-server-supabase@latest --access-token $SUPABASE_ACCESS_TOKEN
    fi
fi

# DigitalOcean MCP
if read -p "Install DigitalOcean MCP? [y/N]: " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    if setup_api_key "DigitalOcean" "DIGITALOCEAN_API_TOKEN" "https://cloud.digitalocean.com/account/api/tokens"; then
        claude mcp add digitalocean -- env DIGITALOCEAN_API_TOKEN=$DIGITALOCEAN_API_TOKEN npx @digitalocean/mcp
    fi
fi

# Shopify MCP
if read -p "Install Shopify Dev MCP? [y/N]: " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    claude mcp add shopify-dev-mcp -- npx -y @shopify/dev-mcp@latest
fi

# Puppeteer MCP
# Now installed by default
# if read -p "Install Puppeteer MCP? [y/N]: " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
#     echo
#     # Install Chrome dependencies
#     sudo apt-get install -y \
#         libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
#         libdrm2 libdbus-1-3 libxkbcommon0 libxcomposite1 libxdamage1 \
#         libxrandr2 libgbm1 libasound2
#     claude mcp add puppeteer -- npx -y @modelcontextprotocol/server-puppeteer
# fi

# Upstash MCP
if read -p "Install Upstash MCP? [y/N]: " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    msg "Get your Upstash credentials from: https://console.upstash.com" "$BLUE"
    read -p "Enter Upstash email: " upstash_email
    read -s -p "Enter Upstash token: " upstash_token
    echo
    if [[ -n "$upstash_email" && -n "$upstash_token" ]]; then
        claude mcp add upstash -- npx -y @upstash/mcp-server run $upstash_email $upstash_token
    fi
fi

msg "\nMCP setup complete!" "$GREEN"
msg "Run 'claude mcp list' to see installed servers" "$BLUE"
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
msg_ok "Cleaned"
