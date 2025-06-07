#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: playajames760
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://docs.anthropic.com/en/docs/claude-code

function header_info {
  clear
  cat <<"EOF"
   ________                __        ______          __     
  / ____/ /___ ___  ______/ /__     / ____/___  ____/ /__   
 / /   / / __ `/ / / / __  / _ \   / /   / __ \/ __  / _ \  
/ /___/ / /_/ / /_/ / /_/ /  __/  / /___/ /_/ / /_/ /  __/  
\____/_/\__,_/\__,_/\__,_/\___/   \____/\____/\__,_/\___/   
                                                             
EOF
}
APP="Claude Code"
var_tags="development;ai"
var_cpu="2"
var_ram="4096"
var_disk="20"
var_os="ubuntu"
var_version="24.04"
var_unprivileged="1"

header_info "$APP"
echo -e "Loading..."
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW="$(openssl rand -base64 8)"
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="yes"
  VERB="no"
  echo_default
}

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  
  if [[ ! -f /usr/local/bin/claude ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  
  msg_info "Updating ${APP} LXC"
  $STD apt-get update
  $STD apt-get -y upgrade
  
  msg_info "Updating Claude Code"
  $STD npm update -g @anthropic-ai/claude-code
  
  msg_ok "Updated Successfully"
  exit
}

start
build_container
description

# Get the container IP address
IP=$(pct exec "$CTID" ip a s dev eth0 | awk '/inet / {print $2}' | cut -d/ -f1)

# Read the dev user password from the container
if pct exec $CTID -- test -f /tmp/dev_password; then
  DEV_PW=$(pct exec $CTID -- cat /tmp/dev_password)
  pct exec $CTID -- rm /tmp/dev_password
else
  DEV_PW="Password generation failed"
fi

msg_ok "Completed Successfully!\n"
echo -e "${APP} Claude Code Development Environment has been installed successfully."
echo -e ""
echo -e "Access Information:"
echo -e "  ${BL}SSH:${CL} ssh dev@${IP}"
echo -e "  ${BL}Username:${CL} dev"
echo -e "  ${BL}Password:${CL} ${GN}$DEV_PW${CL}"
echo -e ""
echo -e "First-time setup:"
echo -e "  • Change the 'dev' user's password"
echo -e "  • Set up MCP servers (optional)"
echo -e "  • Start coding with Claude!"
echo -e ""
