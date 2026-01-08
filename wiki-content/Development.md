# Development Guide

This guide covers development workflows and best practices for UnaMentis.

## Development Workflow

### Branch Strategy

- `main` - Production-ready code
- `rea/main-dev` - Active development branch
- Feature branches from `main` or `rea/main-dev`

### Pull Request Process

1. Create a feature branch
2. Make changes and commit
3. Open a pull request
4. [[CodeRabbit]] automatically reviews
5. Address feedback
6. Human review and approval
7. Merge to target branch

## Code Quality

### Pre-Commit Checks

Always run before committing:

```bash
./scripts/lint.sh && ./scripts/test-quick.sh
```

### Linting

```bash
# All linting
./scripts/lint.sh

# Swift only
swiftlint lint

# Python only
ruff check server/
```

### Formatting

```bash
# All formatting
./scripts/format.sh
```

## Testing

### Quick Tests

```bash
./scripts/test-quick.sh
```

### Full Test Suite

```bash
./scripts/test-all.sh
```

### Health Check

```bash
./scripts/health-check.sh
```

## Debugging

### Log Server

Always have the log server running:

```bash
python3 scripts/log_server.py &
```

Access logs:
- Web: http://localhost:8765/
- JSON: `curl -s http://localhost:8765/logs`
- Clear: `curl -s -X POST http://localhost:8765/clear`

### iOS Debugging

1. Clear logs: `curl -s -X POST http://localhost:8765/clear`
2. Reproduce issue in simulator
3. Fetch logs: `curl -s http://localhost:8765/logs | python3 -m json.tool`

## Component Development

### iOS App

See [[Dev-Environment]] for Xcode setup.

Key directories:
- `UnaMentis/` - Main app code
- `UnaMentis/Services/` - Backend integrations
- `UnaMentis/Views/` - SwiftUI views

### Management API

```bash
cd server/management
source .venv/bin/activate
python main.py
```

Key files:
- `server/management/main.py` - Entry point
- `server/management/api/` - API endpoints

### Web Interface

```bash
cd server/web
npm run dev
```

Key directories:
- `server/web/src/app/` - Next.js pages
- `server/web/src/components/` - React components

## Related Documentation

- [[Getting-Started]] - Initial setup
- [[Testing]] - Detailed testing guide
- [[Tools]] - Development tools
- [[Architecture]] - System design

---

Back to [[Home]]
