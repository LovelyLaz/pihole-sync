#!/bin/bash

# Install Pi-hole Sync as a systemd service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_NAME="pihole-sync"
PIHOLE_CONTAINER="${PIHOLE_CONTAINER:-pihole}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running with appropriate privileges
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    log_error "This script requires sudo privileges"
    log_info "Please run: sudo $0"
    exit 1
fi

SUDO_CMD=""
if [ "$EUID" -ne 0 ]; then
    SUDO_CMD="sudo"
fi

log_info "Installing Pi-hole Sync systemd service..."

# Create systemd service file
SERVICE_FILE="/tmp/${SERVICE_NAME}.service"
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Pi-hole Configuration Sync Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$REPO_DIR
Environment="PIHOLE_CONTAINER=$PIHOLE_CONTAINER"
Environment="CHECK_INTERVAL=${CHECK_INTERVAL:-300}"
ExecStart=$SCRIPT_DIR/auto-sync.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Install service file
log_info "Installing service file..."
$SUDO_CMD mv "$SERVICE_FILE" "/etc/systemd/system/${SERVICE_NAME}.service"
$SUDO_CMD chmod 644 "/etc/systemd/system/${SERVICE_NAME}.service"

# Reload systemd
log_info "Reloading systemd daemon..."
$SUDO_CMD systemctl daemon-reload

# Enable and start service
log_info "Enabling service..."
$SUDO_CMD systemctl enable "$SERVICE_NAME"

log_info "Starting service..."
$SUDO_CMD systemctl start "$SERVICE_NAME"

echo ""
log_info "Service installed and started successfully!"
echo ""
echo "Useful commands:"
echo "  View status:  ${GREEN}sudo systemctl status $SERVICE_NAME${NC}"
echo "  View logs:    ${GREEN}sudo journalctl -u $SERVICE_NAME -f${NC}"
echo "  Stop service: ${GREEN}sudo systemctl stop $SERVICE_NAME${NC}"
echo "  Restart:      ${GREEN}sudo systemctl restart $SERVICE_NAME${NC}"
echo "  Disable:      ${GREEN}sudo systemctl disable $SERVICE_NAME${NC}"
echo ""
