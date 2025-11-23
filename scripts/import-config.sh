#!/bin/bash

# Pi-hole Configuration Import Script
# This script imports Pi-hole configuration from Git to a Pi-hole instance

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$REPO_DIR/config"

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

# Check if config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    log_error "Config directory not found: $CONFIG_DIR"
    log_error "Run './scripts/export-config.sh' on the primary instance first"
    exit 1
fi

# Check if Pi-hole container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${PIHOLE_CONTAINER}$"; then
    log_error "Pi-hole container '${PIHOLE_CONTAINER}' is not running"
    exit 1
fi

log_info "Importing Pi-hole configuration to container: $PIHOLE_CONTAINER"

# Pull latest changes from Git
cd "$REPO_DIR"
if [ -d ".git" ]; then
    log_info "Pulling latest changes from Git..."
    if git pull; then
        log_info "Git pull successful"
    else
        log_warn "Git pull failed (continuing with local config)"
    fi
else
    log_warn "Not a Git repository"
fi

# Create temporary directory for import
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy gravity database
if [ -f "$CONFIG_DIR/gravity.db" ]; then
    log_info "Importing gravity database..."

    # Stop Pi-hole DNS before replacing database
    docker exec "${PIHOLE_CONTAINER}" pihole restartdns

    # Backup current gravity.db
    docker exec "${PIHOLE_CONTAINER}" cp /etc/pihole/gravity.db /etc/pihole/gravity.db.backup 2>/dev/null || true

    # Copy new gravity.db
    docker cp "$CONFIG_DIR/gravity.db" "${PIHOLE_CONTAINER}:/etc/pihole/gravity.db"
    docker exec "${PIHOLE_CONTAINER}" chown pihole:pihole /etc/pihole/gravity.db
    docker exec "${PIHOLE_CONTAINER}" chmod 644 /etc/pihole/gravity.db
else
    log_warn "gravity.db not found in config"
fi

# Import custom DNS records
if [ -f "$CONFIG_DIR/custom.list" ]; then
    log_info "Importing custom DNS records..."
    docker cp "$CONFIG_DIR/custom.list" "${PIHOLE_CONTAINER}:/etc/pihole/custom.list"
    docker exec "${PIHOLE_CONTAINER}" chown pihole:pihole /etc/pihole/custom.list
fi

# Import dnsmasq configuration
if [ -f "$CONFIG_DIR/dnsmasq.tar.gz" ]; then
    log_info "Importing dnsmasq configuration..."
    docker exec "${PIHOLE_CONTAINER}" sh -c 'tar -xzf - -C /' < "$CONFIG_DIR/dnsmasq.tar.gz" 2>/dev/null || log_warn "Could not import dnsmasq configs"
fi

# Import setupVars.conf (but preserve IP-specific settings)
if [ -f "$CONFIG_DIR/setupVars.conf" ]; then
    log_info "Importing Pi-hole settings..."

    # Get current IP settings
    CURRENT_IP=$(docker exec "${PIHOLE_CONTAINER}" grep "^IPV4_ADDRESS=" /etc/pihole/setupVars.conf 2>/dev/null || echo "")
    CURRENT_IP6=$(docker exec "${PIHOLE_CONTAINER}" grep "^IPV6_ADDRESS=" /etc/pihole/setupVars.conf 2>/dev/null || echo "")

    # Copy new settings
    docker cp "$CONFIG_DIR/setupVars.conf" "${PIHOLE_CONTAINER}:/etc/pihole/setupVars.conf"

    # Restore IP settings if they existed
    if [ -n "$CURRENT_IP" ]; then
        docker exec "${PIHOLE_CONTAINER}" sh -c "sed -i '/^IPV4_ADDRESS=/d' /etc/pihole/setupVars.conf && echo '$CURRENT_IP' >> /etc/pihole/setupVars.conf"
    fi
    if [ -n "$CURRENT_IP6" ]; then
        docker exec "${PIHOLE_CONTAINER}" sh -c "sed -i '/^IPV6_ADDRESS=/d' /etc/pihole/setupVars.conf && echo '$CURRENT_IP6' >> /etc/pihole/setupVars.conf"
    fi
fi

# Restart Pi-hole to apply changes
log_info "Restarting Pi-hole to apply changes..."
docker exec "${PIHOLE_CONTAINER}" pihole restartdns

# Update gravity
log_info "Updating gravity (this may take a moment)..."
docker exec "${PIHOLE_CONTAINER}" pihole -g

log_info "Import completed successfully!"
log_info "Pi-hole configuration has been synchronized"

# Show summary
echo ""
log_info "Summary:"
if [ -f "$CONFIG_DIR/metadata.txt" ]; then
    cat "$CONFIG_DIR/metadata.txt" | while read line; do
        echo "  $line"
    done
fi
