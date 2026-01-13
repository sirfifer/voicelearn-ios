# Troubleshooting

Common issues and solutions for UnaMentis development.

## Build Issues

### Xcode Build Fails

**"Module not found"**
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Clean build folder
xcodebuild clean -scheme UnaMentis

# Rebuild
xcodebuild build -scheme UnaMentis ...
```

**"Signing issues"**
1. Open Xcode
2. Select UnaMentis target
3. Signing & Capabilities
4. Select your development team

**"Swift version mismatch"**
Ensure Xcode 16+ is installed:
```bash
xcodebuild -version
```

### SwiftLint Errors

```bash
# Auto-fix many issues
swiftformat .

# Check remaining
swiftlint lint

# Fix manually, then verify
./scripts/lint.sh
```

## Server Issues

### Management API Won't Start

**"Port already in use"**
```bash
# Find process using port 8766
lsof -i :8766

# Kill it
kill -9 <PID>

# Restart
python server.py
```

**"Module not found"**
```bash
cd server/management
source .venv/bin/activate
pip install -r requirements.txt
```

### Operations Console Won't Start

**"Port 3000 in use"**
```bash
lsof -i :3000
kill -9 <PID>
npm run dev
```

**"Node modules issues"**
```bash
rm -rf node_modules
npm install
```

## Simulator Issues

### Simulator Won't Boot

```bash
# List available simulators
xcrun simctl list devices

# Boot specific simulator
xcrun simctl boot "iPhone 16 Pro"

# If stuck, erase
xcrun simctl erase "iPhone 16 Pro"
```

### App Won't Install

```bash
# Uninstall existing app
xcrun simctl uninstall booted com.unamentis.UnaMentis

# Clean and rebuild
xcodebuild clean build ...
```

### MCP Server Not Connected

1. Restart Claude Code
2. Check MCP server status:
   ```bash
   claude mcp list
   ```
3. Verify Xcode command line tools:
   ```bash
   xcode-select -p
   ```

## Audio Issues

### No Microphone Input

1. Check simulator permissions
2. In iOS Settings > Privacy > Microphone
3. Ensure app has permission

### No Audio Output

```bash
# Check audio routes
xcrun simctl io booted enumerate

# Reset audio
killall -9 com.apple.audio.coreaudiod
```

## Testing Issues

### Tests Hang

```bash
# Kill stuck processes
killall xctest
killall Simulator

# Clean and retry
rm -rf ~/Library/Developer/Xcode/DerivedData
./scripts/test-quick.sh
```

### Coverage Below Threshold

1. Run coverage report:
   ```bash
   ./scripts/test-all.sh
   ```
2. Check `coverage/lcov-report/index.html`
3. Add tests for uncovered code

### Integration Tests Fail

1. Ensure services are running:
   ```bash
   /service status
   ```
2. Check log server:
   ```bash
   curl http://localhost:8765/health
   ```

## Log Server Issues

### Log Server Not Starting

```bash
# Check if running
lsof -i :8765

# Start if not
python3 scripts/log_server.py &
```

### No Logs Appearing

1. Check iOS app is configured:
   ```swift
   // RemoteLogHandler.swift
   let serverURL = "http://YOUR_IP:8765/api/logs"
   ```
2. Check network connectivity
3. Verify log level settings

## Git Issues

### Pre-commit Hook Fails

```bash
# Check what failed
./scripts/lint.sh
./scripts/test-quick.sh

# If hook bypass needed (emergencies only)
git commit --no-verify -m "message"

# Document bypass
./scripts/hook-audit.sh
```

### Merge Conflicts

```bash
# Pull latest
git fetch origin
git rebase origin/main

# Resolve conflicts manually
# Then continue
git rebase --continue
```

## Python Environment Issues

### Virtual Environment Problems

```bash
# Remove and recreate
rm -rf .venv
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Dependency Conflicts

```bash
# Upgrade pip
pip install --upgrade pip

# Install with fresh deps
pip install --force-reinstall -r requirements.txt
```

## Performance Issues

### High Latency

1. Check provider health:
   ```bash
   curl http://localhost:8766/api/servers
   ```
2. Run latency tests:
   ```bash
   python -m latency_harness.cli --suite quick_validation
   ```
3. Check thermal state in Debug UI

### Memory Leaks

1. Use Xcode Instruments > Leaks
2. Check for retain cycles in actors
3. Review async/await ownership

## Getting Help

If these don't help:

1. **Check logs**:
   ```bash
   open http://localhost:8765
   ```

2. **Search issues**:
   [GitHub Issues](https://github.com/UnaMentis/unamentis/issues)

3. **Ask for help**:
   [GitHub Discussions](https://github.com/UnaMentis/unamentis/discussions)

4. **Debug skill**:
   ```
   /debug-logs capture
   ```

## Related Pages

- [[Dev-Environment]] - Setup guide
- [[Testing]] - Testing guide
- [[Development]] - Development workflow
- [[Tools]] - Development tools

---

Back to [[Home]]
