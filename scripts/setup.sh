#!/bin/bash

# Pi-hole Sync Setup Script
# Initializes the Git repository and sets up synchronization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_prompt() {
    echo -e "${BLUE}[?]${NC} $1"
}

echo "========================================="
echo "  Pi-hole Sync Setup"
echo "========================================="
echo ""

cd "$REPO_DIR"

# Initialize Git repository if not already
if [ ! -d ".git" ]; then
    log_info "Initializing Git repository..."
    git init
    log_info "Git repository initialized"
else
    log_info "Git repository already initialized"
fi

# Create .gitignore
log_info "Creating .gitignore..."
cat > .gitignore << 'EOF'
# Backup files
backup/

# State files
*.tmp
.sync-state

# OS files
.DS_Store
Thumbs.db

# Editor files
*.swp
*.swo
*~
.vscode/
.idea/
EOF

# Make scripts executable
log_info "Making scripts executable..."
chmod +x scripts/*.sh

# Check if remote is configured
if ! git remote | grep -q origin; then
    echo ""
    log_prompt "Enter Git remote URL (or press Enter to skip):"
    read -r REMOTE_URL

    if [ -n "$REMOTE_URL" ]; then
        git remote add origin "$REMOTE_URL"
        log_info "Remote 'origin' added: $REMOTE_URL"
    else
        log_warn "No remote configured. You can add it later with:"
        echo "  cd $REPO_DIR"
        echo "  git remote add origin <your-git-repo-url>"
    fi
else
    CURRENT_REMOTE=$(git remote get-url origin)
    log_info "Remote already configured: $CURRENT_REMOTE"
fi

# Initial commit
if ! git rev-parse HEAD >/dev/null 2>&1; then
    log_info "Creating initial commit..."

    # Create README
    cat > README.md << 'EOF'
# Pi-hole Sync

Automated Pi-hole configuration synchronization using Git.

## Quick Start

### Primary Instance (where you update blocklists)

1. Export configuration:
   ```bash
   ./scripts/export-config.sh
   ```

2. Start auto-sync (optional):
   ```bash
   ./scripts/auto-sync.sh
   ```

3. Or run as systemd service:
   ```bash
   ./scripts/install-service.sh
   ```

### Secondary Instances

1. Clone this repository
2. Import configuration:
   ```bash
   PIHOLE_CONTAINER=pihole ./scripts/import-config.sh
   ```

3. Set up periodic sync (cron):
   ```bash
   */15 * * * * cd /path/to/pihole-sync && ./scripts/import-config.sh >> /var/log/pihole-sync.log 2>&1
   ```

## Environment Variables

- `PIHOLE_CONTAINER`: Docker container name (default: `pihole`)
- `CHECK_INTERVAL`: Auto-sync check interval in seconds (default: `300`)

## Files Synced

- Gravity database (blocklists, whitelists, blacklists)
- Custom DNS records
- DNS masq configuration
- Pi-hole settings (setupVars.conf)
- Regex filters

## Directory Structure

```
pihole-sync/
├── config/          # Synced Pi-hole configuration
├── scripts/         # Sync scripts
├── backup/          # Local backups (not synced)
└── README.md
```
EOF

    git add .
    git commit -m "Initial commit - Pi-hole Sync setup"
    log_info "Initial commit created"

    if git remote | grep -q origin; then
        log_prompt "Push to remote? (y/n)"
        read -r PUSH_CONFIRM
        if [ "$PUSH_CONFIRM" = "y" ] || [ "$PUSH_CONFIRM" = "Y" ]; then
            git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null || log_warn "Push failed"
        fi
    fi
fi

# Configure Git user if not set
if [ -z "$(git config user.email)" ]; then
    log_prompt "Enter your Git email:"
    read -r GIT_EMAIL
    git config user.email "$GIT_EMAIL"
fi

if [ -z "$(git config user.name)" ]; then
    log_prompt "Enter your Git name:"
    read -r GIT_NAME
    git config user.name "$GIT_NAME"
fi

echo ""
echo "========================================="
log_info "Setup complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Export current Pi-hole config:"
echo "   ${BLUE}./scripts/export-config.sh${NC}"
echo ""
echo "2. Choose an auto-sync method:"
echo ""
echo "   Option A - Systemd service (recommended):"
echo "   ${BLUE}./scripts/install-service.sh${NC}"
echo ""
echo "   Option B - Run manually:"
echo "   ${BLUE}./scripts/auto-sync.sh${NC}"
echo ""
echo "   Option C - Cron job (add to crontab):"
echo "   ${BLUE}*/5 * * * * cd $REPO_DIR && ./scripts/export-config.sh${NC}"
echo ""
echo "3. On secondary instances:"
echo "   ${BLUE}git clone <your-repo> && cd pihole-sync${NC}"
echo "   ${BLUE}./scripts/import-config.sh${NC}"
echo ""
