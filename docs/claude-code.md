# Claude Code Development Environment

Claude Code is Anthropic's official CLI tool that helps users with software engineering tasks. This LXC container provides a complete development environment with Claude Code, claude-nine, and multiple MCP servers.

## Features

- **Claude Code CLI**: Full access to Claude's coding assistant
- **claude-nine**: Enhanced command-line interface for Claude
- **5 MCP Servers**: Pre-configured Model Context Protocol servers
- **Development Tools**: Node.js, Git, Zsh, and more
- **SSH Access**: Remote development ready

## Installation

Run the script on your Proxmox VE host:

```bash
bash -c "$(wget -qO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/claude-code.sh)"
```

## First-Time Setup

1. **SSH into the container**:
   ```bash
   ssh dev@<container-ip>
   ```

2. **API Key Configuration**:
   - Get your Anthropic API key from: https://console.anthropic.com/settings/keys
   - The first-run wizard will guide you through setup

3. **MCP Servers** (Optional):
   - Supabase: Database and authentication
   - DigitalOcean: Cloud infrastructure management
   - Shopify: E-commerce development
   - Puppeteer: Web automation
   - Upstash: Redis and Kafka

## Usage

### Claude Code Commands
```bash
claude         # Start Claude Code CLI
claude chat    # Interactive chat mode
claude commit  # AI-assisted git commits
claude help    # Show all commands
```

### MCP Management
```bash
claude mcp list    # List installed servers
claude mcp add     # Add new server
claude mcp remove  # Remove server
```

### Directory Structure
```
/home/dev/
├── workspace/      # General workspace
├── projects/       # Project directory
├── claude-nine/    # claude-nine installation
└── .config/
    └── claude-code/  # Configuration files
```

## Default Credentials

- **User**: `dev`
- **Password**: Set during installation or auto-generated
- **SSH**: Enabled by default

## Resources

- **CPU**: 2 cores (minimum)
- **RAM**: 4GB (minimum)
- **Disk**: 20GB (expandable)
- **OS**: Ubuntu 24.04 LTS

## Update

To update Claude Code and dependencies:

```bash
bash -c "$(wget -qO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/claude-code.sh)" -- --update
```

## Support

- **Claude Code Docs**: https://docs.anthropic.com/en/docs/claude-code
- **MCP Documentation**: https://modelcontextprotocol.io
- **Issues**: Submit via GitHub Issues