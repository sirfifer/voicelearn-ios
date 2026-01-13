# Developer Environment Setup

Complete guide to setting up your UnaMentis development environment.

## Prerequisites

- **macOS 14.5+** (Sonoma or later)
- **Apple Silicon Mac** (M1/M2/M3/M4) recommended
- **16GB+ RAM**
- **50GB+ free disk space**

## 1. Core Tools

### Xcode

```bash
# Install Xcode 16.x from Mac App Store
# Then install command line tools:
xcode-select --install

# Verify
xcodebuild -version
```

After installing:
1. Open Xcode and accept license
2. Install iOS 18 simulator (Settings > Platforms)

### Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (Apple Silicon)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Swift Tools

```bash
brew install swiftlint swiftformat xcbeautify

# Verify
swiftlint version
swiftformat --version
```

### Node.js

```bash
brew install node@20

# Verify
node --version  # Should be 20.x+
```

### Python

```bash
brew install python@3.12

# Verify
python3 --version  # Should be 3.12.x

# Install dependencies
pip3 install aiohttp aiofiles
```

## 2. Editor Setup

### VS Code / Cursor

Recommended extensions:
- **Claude Code** (Anthropic)
- **Swift** (Swift Server Work Group)
- **SwiftLint**
- **GitLens**
- **Prettier**

### Xcode Settings

Enable these in Xcode:
- Editor > Show Minimap
- Text Editing > Line Numbers
- Text Editing > Code folding ribbon

## 3. Project Setup

```bash
# Clone repository
git clone https://github.com/UnaMentis/unamentis.git
cd unamentis

# Set up local environment
./scripts/setup-local-env.sh

# Install git hooks
./scripts/install-hooks.sh
```

## 4. MCP Servers (for AI Development)

If using Claude Code, configure MCP servers:

```bash
# Verify MCP servers
claude mcp list
# Should show: ios-simulator, XcodeBuildMCP
```

See [[MCP-Servers]] for detailed setup.

## 5. Server Dependencies

### Management API

```bash
cd server/management
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Operations Console

```bash
cd server/web
npm install
```

### Web Client

```bash
cd server/web-client
pnpm install  # or npm install
```

## 6. Verification

Run the health check:

```bash
./scripts/health-check.sh
```

Start all services:
```bash
# Terminal 1: Management API
cd server/management && python server.py

# Terminal 2: Operations Console
cd server/web && npm run dev

# Terminal 3: iOS Simulator
open UnaMentis.xcodeproj
# Press Cmd+R to run
```

Verify endpoints:
- Management API: http://localhost:8766/health
- Operations Console: http://localhost:3000
- Log Server: http://localhost:8765

## Common Issues

### Xcode Build Fails

```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### Python venv Issues

```bash
# Recreate virtual environment
rm -rf .venv
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Node.js Version Mismatch

```bash
# Use nvm for version management
brew install nvm
nvm install 20
nvm use 20
```

## Next Steps

- [[Getting-Started]] - Quick start guide
- [[iOS-Development]] - iOS coding guide
- [[Server-Development]] - Server development
- [[Testing]] - Running tests

---

Back to [[Home]]
