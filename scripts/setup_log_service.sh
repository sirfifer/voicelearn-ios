#!/bin/bash
#
# UnaMentis Log Server Service Setup
#
# This script installs/uninstalls the log server as a macOS launchd service
# that runs automatically in the background.
#
# Usage:
#   ./scripts/setup_log_service.sh install   - Install and start the service
#   ./scripts/setup_log_service.sh uninstall - Stop and remove the service
#   ./scripts/setup_log_service.sh status    - Check service status
#   ./scripts/setup_log_service.sh restart   - Restart the service
#   ./scripts/setup_log_service.sh logs      - Show service logs
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_NAME="com.unamentis.logserver"
PLIST_SOURCE="$SCRIPT_DIR/com.unamentis.logserver.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$SERVICE_NAME.plist"
LOG_SERVER="$SCRIPT_DIR/log_server.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

get_local_ip() {
    # Get local IP address
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1"
}

install_service() {
    print_status "Installing UnaMentis Log Server service..."

    # Create LaunchAgents directory if it doesn't exist
    mkdir -p "$HOME/Library/LaunchAgents"

    # Stop existing service if running
    if launchctl list | grep -q "$SERVICE_NAME"; then
        print_status "Stopping existing service..."
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
    fi

    # Create plist with correct paths
    print_status "Creating service configuration..."
    sed -e "s|SCRIPT_PATH_PLACEHOLDER|$LOG_SERVER|g" \
        -e "s|WORKING_DIR_PLACEHOLDER|$PROJECT_DIR|g" \
        "$PLIST_SOURCE" > "$PLIST_DEST"

    # Set correct permissions
    chmod 644 "$PLIST_DEST"

    # Load the service
    print_status "Starting service..."
    launchctl load "$PLIST_DEST"

    # Wait a moment for it to start
    sleep 2

    # Check if it's running
    if launchctl list | grep -q "$SERVICE_NAME"; then
        LOCAL_IP=$(get_local_ip)
        print_success "Log server service installed and running!"
        echo ""
        echo -e "  ${GREEN}Web Interface:${NC} http://localhost:8765/"
        echo -e "  ${GREEN}Network URL:${NC}   http://$LOCAL_IP:8765/"
        echo ""
        echo -e "  ${YELLOW}For device testing:${NC}"
        echo -e "  Set log server IP in app Settings to: ${GREEN}$LOCAL_IP${NC}"
        echo ""
    else
        print_error "Service failed to start. Check logs with: $0 logs"
        exit 1
    fi
}

uninstall_service() {
    print_status "Uninstalling UnaMentis Log Server service..."

    if [ -f "$PLIST_DEST" ]; then
        # Unload the service
        launchctl unload "$PLIST_DEST" 2>/dev/null || true

        # Remove the plist
        rm -f "$PLIST_DEST"

        print_success "Service uninstalled"
    else
        print_warning "Service not installed"
    fi
}

check_status() {
    echo -e "${BLUE}UnaMentis Log Server Status${NC}"
    echo "=============================="

    if launchctl list | grep -q "$SERVICE_NAME"; then
        PID=$(launchctl list | grep "$SERVICE_NAME" | awk '{print $1}')
        if [ "$PID" != "-" ] && [ -n "$PID" ]; then
            print_success "Service is running (PID: $PID)"

            LOCAL_IP=$(get_local_ip)
            echo ""
            echo -e "  Web Interface: ${GREEN}http://localhost:8765/${NC}"
            echo -e "  Network URL:   ${GREEN}http://$LOCAL_IP:8765/${NC}"

            # Check if port is actually listening
            if lsof -i :8765 >/dev/null 2>&1; then
                echo -e "  Port 8765:     ${GREEN}Listening${NC}"
            else
                echo -e "  Port 8765:     ${YELLOW}Not listening (may be starting)${NC}"
            fi
        else
            print_warning "Service is loaded but not running"
        fi
    else
        print_warning "Service is not running"
        if [ -f "$PLIST_DEST" ]; then
            echo "  Plist exists at: $PLIST_DEST"
            echo "  Try: $0 restart"
        else
            echo "  Service not installed. Run: $0 install"
        fi
    fi
}

restart_service() {
    print_status "Restarting UnaMentis Log Server service..."

    if [ -f "$PLIST_DEST" ]; then
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
        sleep 1
        launchctl load "$PLIST_DEST"
        sleep 2
        check_status
    else
        print_error "Service not installed. Run: $0 install"
        exit 1
    fi
}

show_logs() {
    echo -e "${BLUE}UnaMentis Log Server Logs${NC}"
    echo "============================"

    if [ -f /tmp/unamentis-logserver.log ]; then
        echo -e "\n${GREEN}=== stdout ===${NC}"
        tail -50 /tmp/unamentis-logserver.log
    fi

    if [ -f /tmp/unamentis-logserver.err ]; then
        echo -e "\n${RED}=== stderr ===${NC}"
        tail -50 /tmp/unamentis-logserver.err
    fi

    if [ ! -f /tmp/unamentis-logserver.log ] && [ ! -f /tmp/unamentis-logserver.err ]; then
        print_warning "No log files found. Service may not have run yet."
    fi
}

# Main
case "${1:-}" in
    install)
        install_service
        ;;
    uninstall|remove)
        uninstall_service
        ;;
    status)
        check_status
        ;;
    restart)
        restart_service
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "UnaMentis Log Server Service Manager"
        echo ""
        echo "Usage: $0 {install|uninstall|status|restart|logs}"
        echo ""
        echo "Commands:"
        echo "  install    Install and start the log server as a background service"
        echo "  uninstall  Stop and remove the service"
        echo "  status     Check if the service is running"
        echo "  restart    Restart the service"
        echo "  logs       Show service log output"
        echo ""
        echo "Once installed, the log server will:"
        echo "  - Start automatically when you log in"
        echo "  - Restart automatically if it crashes"
        echo "  - Provide a web interface at http://localhost:8765/"
        exit 1
        ;;
esac
