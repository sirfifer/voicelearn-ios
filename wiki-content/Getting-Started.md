# Getting Started

This guide helps you set up your development environment for UnaMentis.

## Prerequisites

- **macOS** 14.0 or later
- **Xcode** 16.0 or later
- **Python** 3.11+
- **Node.js** 20+
- **Homebrew** for package management

## Quick Setup

### 1. Clone the Repository

```bash
git clone https://github.com/UnaMentis/unamentis.git
cd unamentis
```

### 2. iOS Development

```bash
# Open the Xcode project
open UnaMentis.xcodeproj

# Build and run on simulator
# Select iPhone 17 Pro simulator
# Press Cmd+R to run
```

### 3. Server Development

```bash
# Start the management API
cd server/management
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py

# Start the web interface (separate terminal)
cd server/web
npm install
npm run dev
```

### 4. Start the Log Server

The log server must be running for debugging:

```bash
python3 scripts/log_server.py &
```

## Verification

1. **Log Server**: Visit http://localhost:8765/
2. **Management API**: Visit http://localhost:8766/health
3. **Web Interface**: Visit http://localhost:3000

## Next Steps

- [[Development]] - Development workflows
- [[Testing]] - Running tests
- [[Tools]] - Development tools
- [[Architecture]] - System overview

## Getting Help

- Check the [Issues](https://github.com/UnaMentis/unamentis/issues)
- Read the [[Development]] guide
- Review [[CodeRabbit]] for code review help

---

Back to [[Home]]
