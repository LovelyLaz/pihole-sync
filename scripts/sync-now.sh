#!/bin/bash

# Quick sync script - exports from primary and imports to secondary

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-export}" # export or import

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

if [ "$MODE" = "export" ]; then
    log_info "Running export from primary Pi-hole..."
    "$SCRIPT_DIR/export-config.sh"
elif [ "$MODE" = "import" ]; then
    log_info "Running import to secondary Pi-hole..."
    "$SCRIPT_DIR/import-config.sh"
elif [ "$MODE" = "both" ]; then
    log_info "Running full sync (export + import)..."
    "$SCRIPT_DIR/export-config.sh"
    "$SCRIPT_DIR/import-config.sh"
else
    echo "Usage: $0 [export|import|both]"
    echo ""
    echo "  export - Export config from this Pi-hole instance"
    echo "  import - Import config to this Pi-hole instance"
    echo "  both   - Export then import (for testing)"
    exit 1
fi

log_info "Sync complete!"
