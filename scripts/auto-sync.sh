#!/bin/bash

# Pi-hole Auto-Sync Script
# Monitors Pi-hole gravity database for changes and auto-exports to Git

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Load .env file if it exists
if [ -f "$REPO_DIR/.env" ]; then
    source "$REPO_DIR/.env"
fi

PIHOLE_CONTAINER="${PIHOLE_CONTAINER:-pihole}"
CHECK_INTERVAL="${CHECK_INTERVAL:-300}" # Check every 5 minutes by default
STATE_FILE="/tmp/pihole-sync-state-$(echo $PIHOLE_CONTAINER | tr '/' '_')"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    fi
}

get_gravity_hash() {
    docker exec "${PIHOLE_CONTAINER}" md5sum /etc/pihole/gravity.db 2>/dev/null | awk '{print $1}' || echo ""
}

log_info "Starting Pi-hole auto-sync monitor for container: $PIHOLE_CONTAINER"
log_info "Check interval: ${CHECK_INTERVAL} seconds"
log_info "Press Ctrl+C to stop"

# Get initial hash
LAST_HASH=$(get_gravity_hash)
echo "$LAST_HASH" > "$STATE_FILE"

if [ -z "$LAST_HASH" ]; then
    log_warn "Could not get initial gravity.db hash (container may not be running)"
fi

# Main monitoring loop
while true; do
    sleep "$CHECK_INTERVAL"

    # Check if container is still running
    if ! docker ps --format '{{.Names}}' | grep -q "^${PIHOLE_CONTAINER}$"; then
        log_warn "Container $PIHOLE_CONTAINER is not running, waiting..."
        continue
    fi

    CURRENT_HASH=$(get_gravity_hash)

    if [ -z "$CURRENT_HASH" ]; then
        log_warn "Could not get current gravity.db hash"
        continue
    fi

    log_debug "Current hash: $CURRENT_HASH, Last hash: $LAST_HASH"

    if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
        log_info "Change detected in gravity.db!"
        log_info "Running export-config.sh..."

        if "${SCRIPT_DIR}/export-config.sh"; then
            log_info "Export completed successfully"
            LAST_HASH="$CURRENT_HASH"
            echo "$LAST_HASH" > "$STATE_FILE"
        else
            log_warn "Export failed, will retry on next check"
        fi
    else
        log_debug "No changes detected"
    fi
done
