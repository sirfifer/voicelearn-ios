# MCP Servers

Model Context Protocol (MCP) integration for AI-assisted development.

## Overview

UnaMentis uses MCP servers to enable AI agents (Claude Code) to interact with iOS simulators and Xcode builds directly.

**Required MCP Servers:**
- `ios-simulator` - Simulator interaction
- `XcodeBuildMCP` - Xcode build operations

## Setup

### Verify Connection

```bash
claude mcp list
# Should show:
# ios-simulator: ✓ Connected
# XcodeBuildMCP: ✓ Connected
```

If not connected, restart Claude Code.

### Configuration

MCP servers are configured in Claude Code settings. The project includes defaults in `CLAUDE.md`.

## XcodeBuildMCP

Build and interact with iOS apps.

### Session Defaults

Set defaults before building:

```
mcp__XcodeBuildMCP__session-set-defaults({
  projectPath: "/path/to/UnaMentis.xcodeproj",
  scheme: "UnaMentis",
  simulatorName: "iPhone 16 Pro"
})
```

### Build Commands

| Tool | Purpose |
|------|---------|
| `build_sim` | Build for simulator |
| `build_run_sim` | Build and run on simulator |
| `install_app_sim` | Install app on simulator |
| `launch_app_sim` | Launch installed app |
| `test_sim` | Run tests on simulator |

### Example: Build and Run

```
mcp__XcodeBuildMCP__build_run_sim
```

### Example: Run Tests

```
mcp__XcodeBuildMCP__test_sim
```

### Log Capture

```
// Start capture
mcp__XcodeBuildMCP__start_sim_log_cap({
  bundleId: "com.unamentis.UnaMentis"
})

// ... interact with app ...

// Stop and get logs
mcp__XcodeBuildMCP__stop_sim_log_cap({
  logSessionId: "session_id"
})
```

## ios-simulator

Direct simulator interaction.

### Screenshot

```
mcp__ios-simulator__screenshot({
  output_path: "screenshot.png"
})
```

### UI Interaction

```
// Describe UI
mcp__ios-simulator__ui_describe_all

// Tap coordinates
mcp__ios-simulator__ui_tap({
  x: 200,
  y: 400
})

// Type text
mcp__ios-simulator__ui_type({
  text: "Hello World"
})

// Swipe
mcp__ios-simulator__ui_swipe({
  x_start: 200,
  y_start: 600,
  x_end: 200,
  y_end: 200
})
```

### App Management

```
// Launch app
mcp__ios-simulator__launch_app({
  bundle_id: "com.unamentis.UnaMentis"
})

// Install app
mcp__ios-simulator__install_app({
  app_path: "/path/to/UnaMentis.app"
})
```

## Round-Trip Debugging Workflow

Use MCP for autonomous debugging:

1. **Build**
   ```
   mcp__XcodeBuildMCP__build_sim
   ```

2. **Install and Launch**
   ```
   mcp__XcodeBuildMCP__launch_app_sim({
     bundleId: "com.unamentis.UnaMentis"
   })
   ```

3. **Capture Logs**
   ```
   mcp__XcodeBuildMCP__start_sim_log_cap({
     bundleId: "com.unamentis.UnaMentis"
   })
   ```

4. **Screenshot**
   ```
   mcp__ios-simulator__screenshot({
     output_path: "debug.png"
   })
   ```

5. **Interact**
   ```
   mcp__ios-simulator__ui_tap({ x: 200, y: 400 })
   ```

6. **Analyze Logs**
   ```
   mcp__XcodeBuildMCP__stop_sim_log_cap({
     logSessionId: "..."
   })
   ```

## Quick Setup Skill

Use the `/mcp-setup` skill for quick configuration:

```
/mcp-setup ios    # Configure for iOS app
/mcp-setup usm    # Configure for Server Manager
```

## Common Issues

### "Simulator not found"

Ensure the simulator is booted:
```bash
xcrun simctl list devices | grep Booted
```

### "Build failed"

Check session defaults are set correctly:
```
mcp__XcodeBuildMCP__session-show-defaults
```

### "MCP not connected"

Restart Claude Code session.

## Available Tools Reference

### XcodeBuildMCP

| Tool | Description |
|------|-------------|
| `session-set-defaults` | Set project/scheme/simulator |
| `session-show-defaults` | Show current defaults |
| `build_sim` | Build for simulator |
| `build_run_sim` | Build and run |
| `test_sim` | Run tests |
| `install_app_sim` | Install app |
| `launch_app_sim` | Launch app |
| `stop_app_sim` | Stop app |
| `start_sim_log_cap` | Start log capture |
| `stop_sim_log_cap` | Stop log capture |
| `screenshot` | Take screenshot |
| `describe_ui` | Get UI hierarchy |
| `tap` | Tap element |
| `type_text` | Type text |
| `swipe` | Swipe gesture |
| `gesture` | Preset gestures |

### ios-simulator

| Tool | Description |
|------|-------------|
| `screenshot` | Take screenshot |
| `ui_describe_all` | Describe all UI |
| `ui_describe_point` | Describe point |
| `ui_tap` | Tap coordinates |
| `ui_type` | Type text |
| `ui_swipe` | Swipe gesture |
| `launch_app` | Launch app |
| `install_app` | Install app |
| `record_video` | Start recording |
| `stop_recording` | Stop recording |

## Related Pages

- [[Dev-Environment]] - Setup guide
- [[iOS-Development]] - iOS development
- [[Testing]] - Running tests
- [[Tools]] - All development tools

---

Back to [[Tools]] | [[Home]]
