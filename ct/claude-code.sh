#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

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
header_info
echo -e "Loading..."
APP="claude-code"
var_disk="20"
var_cpu="2"
var_ram="4096"
var_os="ubuntu"
var_version="24.04"
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
  if [[ ! -d /home/dev/claude-nine ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating ${APP} LXC"
  apt-get update &>/dev/null
  apt-get -y upgrade &>/dev/null
  
  msg_info "Updating Claude Code"
  npm update -g @anthropic-ai/claude-code &>/dev/null
  
  msg_info "Updating claude-nine"
  cd /home/dev/claude-nine
  git pull &>/dev/null
  npm update &>/dev/null
  
  msg_ok "Updated Successfully"
  exit
}

start
build_container
description

# Read the dev user password from the container
if pct exec $CTID -- test -f /tmp/dev_password; then
  DEV_PW=$(pct exec $CTID -- cat /tmp/dev_password)
  pct exec $CTID -- rm /tmp/dev_password
else
  DEV_PW="Not set"
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
echo -e "  • Configure your Anthropic API key"
echo -e "  • Set up MCP servers (optional)"
echo -e "  • Start coding with Claude!"
echo -e ""