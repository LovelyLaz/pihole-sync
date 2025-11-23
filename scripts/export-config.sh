#!/bin/bash

# Pi-hole Configuration Export Script
# This script exports Pi-hole configuration to Git for synchronization

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$REPO_DIR/config"
BACKUP_DIR="$REPO_DIR/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Load .env file if it exists
if [ -f "$REPO_DIR/.env" ]; then
    source "$REPO_DIR/.env"
fi

# Docker container name (customize this)
PIHOLE_CONTAINER="${PIHOLE_CONTAINER:-pihole}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Pi-hole container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${PIHOLE_CONTAINER}$"; then
    log_error "Pi-hole container '${PIHOLE_CONTAINER}' is not running"
    exit 1
fi

log_info "Exporting Pi-hole configuration from container: $PIHOLE_CONTAINER"

# Create backup of previous config
if [ -f "$CONFIG_DIR/gravity.db" ]; then
    log_info "Creating backup of previous configuration..."
    mkdir -p "$BACKUP_DIR"
    tar -czf "$BACKUP_DIR/pihole-config-$TIMESTAMP.tar.gz" -C "$CONFIG_DIR" . 2>/dev/null || true

    # Keep only last 10 backups
    ls -t "$BACKUP_DIR"/pihole-config-*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
fi

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Export gravity database (contains blocklists, whitelists, etc.)
log_info "Exporting gravity database..."
docker cp "${PIHOLE_CONTAINER}:/etc/pihole/gravity.db" "$CONFIG_DIR/gravity.db"

# Export custom DNS records
log_info "Exporting custom DNS records..."
docker cp "${PIHOLE_CONTAINER}:/etc/pihole/custom.list" "$CONFIG_DIR/custom.list" 2>/dev/null || touch "$CONFIG_DIR/custom.list"

# Export DNS masq configuration
log_info "Exporting dnsmasq configuration..."
docker exec "${PIHOLE_CONTAINER}" sh -c 'tar -czf - /etc/dnsmasq.d/*.conf 2>/dev/null' > "$CONFIG_DIR/dnsmasq.tar.gz" 2>/dev/null || log_warn "No custom dnsmasq configs found"

# Export setupVars.conf (Pi-hole settings)
log_info "Exporting Pi-hole settings..."
docker cp "${PIHOLE_CONTAINER}:/etc/pihole/setupVars.conf" "$CONFIG_DIR/setupVars.conf" 2>/dev/null || log_warn "setupVars.conf not found"

# Export adlists (if using custom list file)
log_info "Exporting adlists..."
docker exec "${PIHOLE_CONTAINER}" sqlite3 /etc/pihole/gravity.db "SELECT address FROM adlist WHERE enabled = 1;" > "$CONFIG_DIR/adlists.txt" 2>/dev/null || log_warn "Could not export adlists"

# Export whitelist, blacklist, and regex lists
log_info "Exporting domain lists..."
docker exec "${PIHOLE_CONTAINER}" sqlite3 /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE type = 0 AND enabled = 1;" > "$CONFIG_DIR/whitelist.txt" 2>/dev/null || touch "$CONFIG_DIR/whitelist.txt"
docker exec "${PIHOLE_CONTAINER}" sqlite3 /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE type = 1 AND enabled = 1;" > "$CONFIG_DIR/blacklist.txt" 2>/dev/null || touch "$CONFIG_DIR/blacklist.txt"
docker exec "${PIHOLE_CONTAINER}" sqlite3 /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE type = 2 AND enabled = 1;" > "$CONFIG_DIR/regex_whitelist.txt" 2>/dev/null || touch "$CONFIG_DIR/regex_whitelist.txt"
docker exec "${PIHOLE_CONTAINER}" sqlite3 /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE type = 3 AND enabled = 1;" > "$CONFIG_DIR/regex_blacklist.txt" 2>/dev/null || touch "$CONFIG_DIR/regex_blacklist.txt"

# Create metadata file
log_info "Creating metadata..."
cat > "$CONFIG_DIR/metadata.txt" << EOF
Export Date: $(date)
Pi-hole Container: $PIHOLE_CONTAINER
Hostname: $(hostname)
Pi-hole Version: $(docker exec "${PIHOLE_CONTAINER}" pihole -v | grep "Pi-hole version" || echo "Unknown")
EOF

log_info "Export completed successfully!"

# Git operations
cd "$REPO_DIR"
if [ -d ".git" ]; then
    log_info "Committing changes to Git..."

    git add config/

    # Check if there are changes to commit
    if git diff --staged --quiet; then
        log_info "No changes detected, nothing to commit"
    else
        git commit -m "Auto-update Pi-hole config - $(date '+%Y-%m-%d %H:%M:%S')"
        log_info "Changes committed locally"

        # Push to remote if configured
        if git remote | grep -q origin; then
            log_info "Pushing to remote repository..."
            if git push; then
                log_info "Successfully pushed to remote"
            else
                log_warn "Failed to push to remote (check connectivity/credentials)"
            fi
        else
            log_warn "No remote repository configured (run 'git remote add origin <url>')"
        fi
    fi
else
    log_warn "Not a Git repository. Run 'git init' and 'git remote add origin <url>' in $REPO_DIR"
fi

echo ""
log_info "Configuration exported to: $CONFIG_DIR"
log_info "To sync to other instances, run: ./scripts/import-config.sh"
