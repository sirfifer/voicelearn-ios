#!/bin/bash
# VoiceLearn Server Stack Startup Script
# Starts all three services: Management Console, VibeVoice TTS, and Next.js Dashboard

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VIBEVOICE_DIR="$PROJECT_ROOT/../vibevoice-realtime-openai-api"

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║   ██╗   ██╗ ██████╗ ██╗ ██████╗███████╗                     ║"
echo "║   ██║   ██║██╔═══██╗██║██╔════╝██╔════╝                     ║"
echo "║   ██║   ██║██║   ██║██║██║     █████╗                       ║"
echo "║   ╚██╗ ██╔╝██║   ██║██║██║     ██╔══╝                       ║"
echo "║    ╚████╔╝ ╚██████╔╝██║╚██████╗███████╗                     ║"
echo "║     ╚═══╝   ╚═════╝ ╚═╝ ╚═════╝╚══════╝                     ║"
echo "║                                                              ║"
echo "║           VoiceLearn Server Stack Launcher                   ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to check if a port is in use
check_port() {
    lsof -i ":$1" >/dev/null 2>&1
}

# Function to wait for a service to be ready
wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=1

    echo -e "${YELLOW}Waiting for $name to be ready...${NC}"
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $name is ready${NC}"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    echo -e "${RED}✗ $name failed to start${NC}"
    return 1
}

# Check if services are already running
echo -e "${BLUE}Checking existing services...${NC}"

if check_port 8766; then
    echo -e "${YELLOW}⚠ Management Console already running on port 8766${NC}"
    MGMT_RUNNING=true
else
    MGMT_RUNNING=false
fi

if check_port 8880; then
    echo -e "${YELLOW}⚠ VibeVoice TTS already running on port 8880${NC}"
    VIBEVOICE_RUNNING=true
else
    VIBEVOICE_RUNNING=false
fi

if check_port 3000; then
    echo -e "${YELLOW}⚠ Next.js Dashboard already running on port 3000${NC}"
    NEXTJS_RUNNING=true
else
    NEXTJS_RUNNING=false
fi

echo ""

# Start Management Console (this one we need running first)
if [ "$MGMT_RUNNING" = false ]; then
    echo -e "${BLUE}Starting Management Console on port 8766...${NC}"
    cd "$SCRIPT_DIR/management"

    # Activate virtual environment if it exists
    if [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
    fi

    # Start in background
    python3 server.py &
    MGMT_PID=$!
    echo -e "${GREEN}✓ Management Console started (PID: $MGMT_PID)${NC}"

    # Wait for it to be ready
    wait_for_service "http://localhost:8766/health" "Management Console"
else
    echo -e "${GREEN}✓ Management Console already running${NC}"
fi

echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Management Console is ready!${NC}"
echo ""
echo -e "  ${PURPLE}Dashboard:${NC}      http://localhost:8766"
echo -e "  ${PURPLE}API:${NC}            http://localhost:8766/api/stats"
echo -e "  ${PURPLE}WebSocket:${NC}      ws://localhost:8766/ws"
echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}You can now use the Services tab in the Management Console"
echo -e "to start/stop VibeVoice TTS and the Next.js Dashboard.${NC}"
echo ""
echo -e "${GREEN}Or start them via API:${NC}"
echo "  curl -X POST http://localhost:8766/api/services/start-all"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the Management Console${NC}"
echo ""

# Keep the script running if we started the management server
if [ "$MGMT_RUNNING" = false ]; then
    # Wait for the management server process
    wait $MGMT_PID
fi
