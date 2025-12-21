#!/bin/bash
#
# UnaMentis Server Setup Script
#
# Single-command deployment for self-hosted AI services on macOS.
# Installs and configures: Ollama (LLM), whisper.cpp (STT), Piper (TTS)
#
# Usage: ./setup.sh [options]
#   --model MODEL    LLM model to install (default: qwen2.5:7b)
#   --whisper SIZE   Whisper model size: tiny|base|small|medium|large (default: small)
#   --port PORT      Base port for services (default: 11400)
#   --no-autostart   Don't configure services to start automatically
#   --uninstall      Remove UnaMentis server components
#
# Services will be available at:
#   LLM:  http://localhost:11434 (Ollama)
#   STT:  http://localhost:11401 (Whisper)
#   TTS:  http://localhost:11402 (Piper)
#   API:  http://localhost:11400 (Unified gateway)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
LLM_MODEL="qwen2.5:7b"
WHISPER_SIZE="small"
BASE_PORT=11400
AUTOSTART=true
UNINSTALL=false

# Directories
UNAMENTIS_DIR="$HOME/.unamentis-server"
BIN_DIR="$UNAMENTIS_DIR/bin"
MODELS_DIR="$UNAMENTIS_DIR/models"
LOGS_DIR="$UNAMENTIS_DIR/logs"
CONFIG_DIR="$UNAMENTIS_DIR/config"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            LLM_MODEL="$2"
            shift 2
            ;;
        --whisper)
            WHISPER_SIZE="$2"
            shift 2
            ;;
        --port)
            BASE_PORT="$2"
            shift 2
            ;;
        --no-autostart)
            AUTOSTART=false
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Port assignments
GATEWAY_PORT=$BASE_PORT
STT_PORT=$((BASE_PORT + 1))
TTS_PORT=$((BASE_PORT + 2))
OLLAMA_PORT=11434  # Standard Ollama port

print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║          UnaMentis Server Setup for macOS                ║"
    echo "║                                                           ║"
    echo "║  LLM: Ollama    STT: whisper.cpp    TTS: Piper            ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}Error: This script is designed for macOS only.${NC}"
        echo "For other platforms, see docs/server/PROXMOX_CPU_DEPLOYMENT.md"
        exit 1
    fi

    # Check for Apple Silicon
    if [[ "$(uname -m)" == "arm64" ]]; then
        echo -e "${GREEN}✓ Apple Silicon detected - optimal performance expected${NC}"
        ARCH="arm64"
    else
        echo -e "${YELLOW}⚠ Intel Mac detected - performance will be limited${NC}"
        ARCH="x86_64"
    fi
}

check_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Homebrew not found. Installing...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add to path for Apple Silicon
        if [[ "$ARCH" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    echo -e "${GREEN}✓ Homebrew available${NC}"
}

create_directories() {
    echo -e "${BLUE}Creating directories...${NC}"
    mkdir -p "$BIN_DIR" "$MODELS_DIR" "$LOGS_DIR" "$CONFIG_DIR"
    mkdir -p "$MODELS_DIR/whisper" "$MODELS_DIR/piper"
}

install_ollama() {
    echo -e "${BLUE}Setting up Ollama...${NC}"

    if ! command -v ollama &> /dev/null; then
        echo "Installing Ollama..."
        brew install ollama
    else
        echo -e "${GREEN}✓ Ollama already installed${NC}"
    fi

    # Start Ollama service
    echo "Starting Ollama service..."
    brew services start ollama 2>/dev/null || true
    sleep 3

    # Pull the model
    echo "Pulling model: $LLM_MODEL (this may take a while)..."
    ollama pull "$LLM_MODEL"

    echo -e "${GREEN}✓ Ollama configured with $LLM_MODEL${NC}"
}

install_whisper() {
    echo -e "${BLUE}Setting up whisper.cpp...${NC}"

    WHISPER_DIR="$UNAMENTIS_DIR/whisper.cpp"

    if [[ ! -d "$WHISPER_DIR" ]]; then
        echo "Cloning whisper.cpp..."
        git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
    fi

    cd "$WHISPER_DIR"
    git pull --quiet

    # Build with Metal support for Apple Silicon
    echo "Building whisper.cpp with Metal acceleration..."
    cmake -B build -DWHISPER_METAL=ON -DWHISPER_BUILD_SERVER=ON -DCMAKE_BUILD_TYPE=Release
    cmake --build build --config Release -j$(sysctl -n hw.ncpu)

    # Download model
    echo "Downloading Whisper $WHISPER_SIZE model..."
    ./models/download-ggml-model.sh "$WHISPER_SIZE"

    # Copy binary to our bin directory
    cp build/bin/whisper-server "$BIN_DIR/"
    cp "models/ggml-$WHISPER_SIZE.bin" "$MODELS_DIR/whisper/"

    echo -e "${GREEN}✓ whisper.cpp configured with $WHISPER_SIZE model${NC}"
}

install_piper() {
    echo -e "${BLUE}Setting up Piper TTS...${NC}"

    PIPER_DIR="$UNAMENTIS_DIR/piper"

    # Download Piper binary
    if [[ ! -f "$BIN_DIR/piper" ]]; then
        echo "Downloading Piper..."

        if [[ "$ARCH" == "arm64" ]]; then
            PIPER_URL="https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_macos_aarch64.tar.gz"
        else
            PIPER_URL="https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_macos_x64.tar.gz"
        fi

        curl -L "$PIPER_URL" | tar -xz -C "$BIN_DIR"
        mv "$BIN_DIR/piper/piper" "$BIN_DIR/"
        rm -rf "$BIN_DIR/piper" 2>/dev/null || true
    fi

    # Download voice model (Amy - US English)
    VOICE_NAME="en_US-amy-medium"
    if [[ ! -f "$MODELS_DIR/piper/$VOICE_NAME.onnx" ]]; then
        echo "Downloading Piper voice: $VOICE_NAME..."
        curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium/$VOICE_NAME.onnx" \
            -o "$MODELS_DIR/piper/$VOICE_NAME.onnx"
        curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium/$VOICE_NAME.onnx.json" \
            -o "$MODELS_DIR/piper/$VOICE_NAME.onnx.json"
    fi

    echo -e "${GREEN}✓ Piper TTS configured with $VOICE_NAME voice${NC}"
}

create_whisper_server() {
    echo -e "${BLUE}Creating Whisper HTTP server wrapper...${NC}"

    cat > "$BIN_DIR/whisper-http-server.py" << 'WHISPER_SERVER'
#!/usr/bin/env python3
"""
Whisper HTTP Server - OpenAI-compatible transcription API
"""
import subprocess
import tempfile
import os
import sys
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs
import cgi

WHISPER_CMD = os.environ.get('WHISPER_CMD', 'whisper-server')
WHISPER_MODEL = os.environ.get('WHISPER_MODEL', 'ggml-small.bin')
PORT = int(os.environ.get('STT_PORT', '11401'))

class WhisperHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/v1/audio/transcriptions':
            self.handle_transcription()
        elif self.path == '/health':
            self.send_json({'status': 'ok'})
        else:
            self.send_error(404)

    def do_GET(self):
        if self.path == '/health':
            self.send_json({'status': 'ok', 'model': WHISPER_MODEL})
        else:
            self.send_error(404)

    def handle_transcription(self):
        content_type = self.headers.get('Content-Type', '')

        if 'multipart/form-data' not in content_type:
            self.send_error(400, 'Expected multipart/form-data')
            return

        # Parse multipart form data
        form = cgi.FieldStorage(
            fp=self.rfile,
            headers=self.headers,
            environ={'REQUEST_METHOD': 'POST'}
        )

        if 'file' not in form:
            self.send_error(400, 'No file provided')
            return

        # Save uploaded file
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
            tmp.write(form['file'].file.read())
            tmp_path = tmp.name

        try:
            # Run whisper.cpp
            result = subprocess.run(
                [WHISPER_CMD, '-m', WHISPER_MODEL, '-f', tmp_path, '--output-json'],
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                self.send_error(500, f'Whisper failed: {result.stderr}')
                return

            # Parse output
            text = result.stdout.strip()

            self.send_json({'text': text})

        finally:
            os.unlink(tmp_path)

    def send_json(self, data):
        response = json.dumps(data).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(response))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, format, *args):
        pass  # Suppress logging

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', PORT), WhisperHandler)
    print(f'Whisper server listening on port {PORT}')
    server.serve_forever()
WHISPER_SERVER

    chmod +x "$BIN_DIR/whisper-http-server.py"
}

create_piper_server() {
    echo -e "${BLUE}Creating Piper HTTP server wrapper...${NC}"

    cat > "$BIN_DIR/piper-http-server.py" << 'PIPER_SERVER'
#!/usr/bin/env python3
"""
Piper HTTP Server - OpenAI-compatible TTS API
"""
import subprocess
import tempfile
import os
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

PIPER_CMD = os.environ.get('PIPER_CMD', 'piper')
PIPER_MODEL = os.environ.get('PIPER_MODEL', 'en_US-amy-medium.onnx')
PORT = int(os.environ.get('TTS_PORT', '11402'))

class PiperHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/v1/audio/speech':
            self.handle_synthesis()
        elif self.path == '/health':
            self.send_json({'status': 'ok'})
        else:
            self.send_error(404)

    def do_GET(self):
        if self.path == '/health':
            self.send_json({'status': 'ok', 'model': PIPER_MODEL})
        else:
            self.send_error(404)

    def handle_synthesis(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)

        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            self.send_error(400, 'Invalid JSON')
            return

        text = data.get('input', '')
        if not text:
            self.send_error(400, 'No input text provided')
            return

        # Generate audio with Piper
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
            tmp_path = tmp.name

        try:
            result = subprocess.run(
                [PIPER_CMD, '--model', PIPER_MODEL, '--output_file', tmp_path],
                input=text,
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                self.send_error(500, f'Piper failed: {result.stderr}')
                return

            # Read and return audio
            with open(tmp_path, 'rb') as f:
                audio_data = f.read()

            self.send_response(200)
            self.send_header('Content-Type', 'audio/wav')
            self.send_header('Content-Length', len(audio_data))
            self.end_headers()
            self.wfile.write(audio_data)

        finally:
            os.unlink(tmp_path)

    def send_json(self, data):
        response = json.dumps(data).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(response))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, format, *args):
        pass  # Suppress logging

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', PORT), PiperHandler)
    print(f'Piper server listening on port {PORT}')
    server.serve_forever()
PIPER_SERVER

    chmod +x "$BIN_DIR/piper-http-server.py"
}

create_unified_server() {
    echo -e "${BLUE}Creating unified API gateway...${NC}"

    cat > "$BIN_DIR/unamentis-gateway.py" << 'GATEWAY_SERVER'
#!/usr/bin/env python3
"""
UnaMentis API Gateway
Unified endpoint that routes to all services and provides discovery.
"""
import os
import json
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

# Service configuration from environment
OLLAMA_URL = os.environ.get('OLLAMA_URL', 'http://localhost:11434')
STT_URL = os.environ.get('STT_URL', 'http://localhost:11401')
TTS_URL = os.environ.get('TTS_URL', 'http://localhost:11402')
GATEWAY_PORT = int(os.environ.get('GATEWAY_PORT', '11400'))
LLM_MODEL = os.environ.get('LLM_MODEL', 'qwen2.5:7b')

class GatewayHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.handle_discovery()
        elif self.path == '/health':
            self.handle_health()
        elif self.path.startswith('/v1/'):
            self.proxy_request('GET')
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path.startswith('/v1/'):
            self.proxy_request('POST')
        else:
            self.send_error(404)

    def handle_discovery(self):
        """Return server configuration for auto-discovery"""
        config = {
            'unamentis_server': True,
            'version': '1.0.0',
            'services': {
                'llm': {
                    'url': OLLAMA_URL,
                    'model': LLM_MODEL,
                    'type': 'ollama',
                    'endpoints': {
                        'chat': '/v1/chat/completions',
                        'generate': '/api/generate'
                    }
                },
                'stt': {
                    'url': STT_URL,
                    'type': 'whisper',
                    'endpoints': {
                        'transcribe': '/v1/audio/transcriptions'
                    }
                },
                'tts': {
                    'url': TTS_URL,
                    'type': 'piper',
                    'endpoints': {
                        'speech': '/v1/audio/speech'
                    }
                }
            },
            'unified_endpoints': {
                'llm': f'http://localhost:{GATEWAY_PORT}/v1/chat/completions',
                'stt': f'http://localhost:{GATEWAY_PORT}/v1/audio/transcriptions',
                'tts': f'http://localhost:{GATEWAY_PORT}/v1/audio/speech'
            }
        }
        self.send_json(config)

    def handle_health(self):
        """Check health of all services"""
        health = {
            'gateway': 'ok',
            'services': {}
        }

        # Check each service
        for name, url in [('llm', OLLAMA_URL), ('stt', STT_URL), ('tts', TTS_URL)]:
            try:
                req = urllib.request.Request(f'{url}/health', method='GET')
                with urllib.request.urlopen(req, timeout=2) as resp:
                    health['services'][name] = 'ok'
            except:
                health['services'][name] = 'unavailable'

        self.send_json(health)

    def proxy_request(self, method):
        """Proxy requests to appropriate backend service"""
        path = self.path

        # Route based on path
        if '/chat/completions' in path or '/api/generate' in path:
            backend = OLLAMA_URL
        elif '/audio/transcriptions' in path:
            backend = STT_URL
        elif '/audio/speech' in path:
            backend = TTS_URL
        else:
            self.send_error(404, 'Unknown endpoint')
            return

        # Build target URL
        target_url = f'{backend}{path}'

        # Read request body if present
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        # Forward request
        try:
            req = urllib.request.Request(
                target_url,
                data=body,
                method=method
            )

            # Copy relevant headers
            for header in ['Content-Type', 'Authorization']:
                if header in self.headers:
                    req.add_header(header, self.headers[header])

            with urllib.request.urlopen(req, timeout=300) as resp:
                # Forward response
                self.send_response(resp.status)
                for header, value in resp.getheaders():
                    if header.lower() not in ['transfer-encoding', 'connection']:
                        self.send_header(header, value)
                self.end_headers()
                self.wfile.write(resp.read())

        except urllib.error.HTTPError as e:
            self.send_error(e.code, str(e.reason))
        except Exception as e:
            self.send_error(502, f'Backend error: {str(e)}')

    def send_json(self, data):
        response = json.dumps(data, indent=2).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(response))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, format, *args):
        print(f'[Gateway] {args[0]}')

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', GATEWAY_PORT), GatewayHandler)
    print(f'UnaMentis Gateway listening on port {GATEWAY_PORT}')
    print(f'Discovery endpoint: http://localhost:{GATEWAY_PORT}/')
    print(f'Health endpoint: http://localhost:{GATEWAY_PORT}/health')
    server.serve_forever()
GATEWAY_SERVER

    chmod +x "$BIN_DIR/unamentis-gateway.py"
}

create_control_script() {
    echo -e "${BLUE}Creating control script...${NC}"

    cat > "$BIN_DIR/unamentis-server" << CONTROL
#!/bin/bash
#
# UnaMentis Server Control Script
#
# Usage: unamentis-server [start|stop|status|restart]
#

UNAMENTIS_DIR="$UNAMENTIS_DIR"
BIN_DIR="$BIN_DIR"
MODELS_DIR="$MODELS_DIR"
LOGS_DIR="$LOGS_DIR"

GATEWAY_PORT=$GATEWAY_PORT
STT_PORT=$STT_PORT
TTS_PORT=$TTS_PORT
LLM_MODEL="$LLM_MODEL"
WHISPER_MODEL="ggml-$WHISPER_SIZE.bin"
PIPER_MODEL="en_US-amy-medium.onnx"

start_services() {
    echo "Starting UnaMentis services..."

    # Start Ollama if not running
    if ! pgrep -x "ollama" > /dev/null; then
        echo "Starting Ollama..."
        brew services start ollama 2>/dev/null || ollama serve &
        sleep 2
    fi

    # Start Whisper server
    if ! pgrep -f "whisper-http-server" > /dev/null; then
        echo "Starting Whisper STT server on port \$STT_PORT..."
        WHISPER_CMD="\$BIN_DIR/whisper-server" \\
        WHISPER_MODEL="\$MODELS_DIR/whisper/\$WHISPER_MODEL" \\
        STT_PORT=\$STT_PORT \\
        nohup python3 "\$BIN_DIR/whisper-http-server.py" > "\$LOGS_DIR/whisper.log" 2>&1 &
    fi

    # Start Piper server
    if ! pgrep -f "piper-http-server" > /dev/null; then
        echo "Starting Piper TTS server on port \$TTS_PORT..."
        PIPER_CMD="\$BIN_DIR/piper" \\
        PIPER_MODEL="\$MODELS_DIR/piper/\$PIPER_MODEL" \\
        TTS_PORT=\$TTS_PORT \\
        nohup python3 "\$BIN_DIR/piper-http-server.py" > "\$LOGS_DIR/piper.log" 2>&1 &
    fi

    # Start Gateway
    if ! pgrep -f "unamentis-gateway" > /dev/null; then
        echo "Starting API gateway on port \$GATEWAY_PORT..."
        OLLAMA_URL="http://localhost:11434" \\
        STT_URL="http://localhost:\$STT_PORT" \\
        TTS_URL="http://localhost:\$TTS_PORT" \\
        GATEWAY_PORT=\$GATEWAY_PORT \\
        LLM_MODEL="\$LLM_MODEL" \\
        nohup python3 "\$BIN_DIR/unamentis-gateway.py" > "\$LOGS_DIR/gateway.log" 2>&1 &
    fi

    sleep 2
    echo ""
    echo "Services started!"
    show_status
}

stop_services() {
    echo "Stopping UnaMentis services..."

    pkill -f "unamentis-gateway" 2>/dev/null
    pkill -f "piper-http-server" 2>/dev/null
    pkill -f "whisper-http-server" 2>/dev/null

    echo "Services stopped. (Ollama left running for other apps)"
}

show_status() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              UnaMentis Server Status                     ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    # Check Gateway
    printf "  Gateway (:\$GATEWAY_PORT)    "
    if curl -s "http://localhost:\$GATEWAY_PORT/health" > /dev/null 2>&1; then
        echo "✅ Running"
    else
        echo "❌ Not running"
    fi

    # Check Ollama
    printf "  Ollama LLM (:11434)    "
    if curl -s "http://localhost:11434/api/version" > /dev/null 2>&1; then
        echo "✅ Running"
    else
        echo "❌ Not running"
    fi

    # Check Whisper
    printf "  Whisper STT (:\$STT_PORT)   "
    if curl -s "http://localhost:\$STT_PORT/health" > /dev/null 2>&1; then
        echo "✅ Running"
    else
        echo "❌ Not running"
    fi

    # Check Piper
    printf "  Piper TTS (:\$TTS_PORT)     "
    if curl -s "http://localhost:\$TTS_PORT/health" > /dev/null 2>&1; then
        echo "✅ Running"
    else
        echo "❌ Not running"
    fi

    echo ""
    echo "Discovery URL: http://localhost:\$GATEWAY_PORT/"
    echo "Health Check:  http://localhost:\$GATEWAY_PORT/health"
    echo ""
}

case "\${1:-status}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 2
        start_services
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: unamentis-server [start|stop|status|restart]"
        exit 1
        ;;
esac
CONTROL

    chmod +x "$BIN_DIR/unamentis-server"
}

create_launchd_plist() {
    if [[ "$AUTOSTART" != "true" ]]; then
        return
    fi

    echo -e "${BLUE}Configuring auto-start...${NC}"

    PLIST_PATH="$HOME/Library/LaunchAgents/com.unamentis.server.plist"

    cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.unamentis.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN_DIR/unamentis-server</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$LOGS_DIR/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/launchd.err</string>
</dict>
</plist>
PLIST

    launchctl load "$PLIST_PATH" 2>/dev/null || true

    echo -e "${GREEN}✓ Auto-start configured${NC}"
}

write_config() {
    echo -e "${BLUE}Writing configuration...${NC}"

    cat > "$CONFIG_DIR/server.json" << CONFIG
{
    "version": "1.0.0",
    "services": {
        "gateway": {
            "port": $GATEWAY_PORT,
            "url": "http://localhost:$GATEWAY_PORT"
        },
        "llm": {
            "type": "ollama",
            "port": $OLLAMA_PORT,
            "url": "http://localhost:$OLLAMA_PORT",
            "model": "$LLM_MODEL"
        },
        "stt": {
            "type": "whisper",
            "port": $STT_PORT,
            "url": "http://localhost:$STT_PORT",
            "model": "ggml-$WHISPER_SIZE.bin"
        },
        "tts": {
            "type": "piper",
            "port": $TTS_PORT,
            "url": "http://localhost:$TTS_PORT",
            "model": "en_US-amy-medium.onnx"
        }
    },
    "directories": {
        "base": "$UNAMENTIS_DIR",
        "bin": "$BIN_DIR",
        "models": "$MODELS_DIR",
        "logs": "$LOGS_DIR"
    }
}
CONFIG
}

add_to_path() {
    # Add to shell profile if not already there
    SHELL_RC="$HOME/.zshrc"
    if [[ -f "$HOME/.bashrc" ]] && [[ ! -f "$HOME/.zshrc" ]]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    PATH_LINE="export PATH=\"\$PATH:$BIN_DIR\""

    if ! grep -q "unamentis-server" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# UnaMentis Server" >> "$SHELL_RC"
        echo "$PATH_LINE" >> "$SHELL_RC"
    fi

    export PATH="$PATH:$BIN_DIR"
}

uninstall() {
    echo -e "${YELLOW}Uninstalling UnaMentis Server...${NC}"

    # Stop services
    "$BIN_DIR/unamentis-server" stop 2>/dev/null || true

    # Remove launchd plist
    launchctl unload "$HOME/Library/LaunchAgents/com.unamentis.server.plist" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/com.unamentis.server.plist"

    # Remove directory
    rm -rf "$UNAMENTIS_DIR"

    echo -e "${GREEN}UnaMentis Server uninstalled.${NC}"
    echo "Note: Ollama was not removed. Run 'brew uninstall ollama' to remove it."
    exit 0
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          UnaMentis Server Setup Complete!                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Services configured:"
    echo "  • LLM:     Ollama with $LLM_MODEL"
    echo "  • STT:     whisper.cpp with $WHISPER_SIZE model"
    echo "  • TTS:     Piper with en_US-amy-medium voice"
    echo ""
    echo "Endpoints:"
    echo "  • Discovery: http://localhost:$GATEWAY_PORT/"
    echo "  • LLM:       http://localhost:$OLLAMA_PORT/v1/chat/completions"
    echo "  • STT:       http://localhost:$STT_PORT/v1/audio/transcriptions"
    echo "  • TTS:       http://localhost:$TTS_PORT/v1/audio/speech"
    echo ""
    echo "Commands:"
    echo "  • Start:   unamentis-server start"
    echo "  • Stop:    unamentis-server stop"
    echo "  • Status:  unamentis-server status"
    echo ""
    echo "Starting services now..."
    echo ""

    "$BIN_DIR/unamentis-server" start
}

# Main execution
main() {
    print_banner

    if [[ "$UNINSTALL" == "true" ]]; then
        uninstall
    fi

    check_macos
    check_homebrew
    create_directories

    install_ollama
    install_whisper
    install_piper

    create_whisper_server
    create_piper_server
    create_unified_server
    create_control_script
    create_launchd_plist
    write_config
    add_to_path

    print_summary
}

main
