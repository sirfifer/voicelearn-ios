# Server Development Guide

Guide for developing UnaMentis server components.

## Overview

UnaMentis has two main server components:

| Component | Port | Technology | Purpose |
|-----------|------|------------|---------|
| **Management API** | 8766 | Python/aiohttp | Backend API, curriculum, TTS caching |
| **Operations Console** | 3000 | Next.js/React | System monitoring, content management |

## Management API (Port 8766)

### Purpose

The Management API handles:
- Curriculum CRUD operations
- Import job orchestration
- TTS caching (cross-user)
- Session management
- FOV context management
- Authentication

### Setup

```bash
cd server/management

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run server
python server.py
```

### Project Structure

```
server/management/
├── server.py              # Main entry point
├── auth.py                # Authentication
├── import_api.py          # Import endpoints
├── reprocess_api.py       # Reprocessing endpoints
├── tts_api.py             # TTS endpoints
├── deployment_api.py      # Deployment scheduling
├── fov_context_api.py     # FOV context endpoints
├── tts_cache/
│   ├── cache.py           # Global TTS cache
│   ├── resource_pool.py   # Priority-based generation
│   └── prefetcher.py      # Background prefetching
├── fov_context/
│   ├── session.py         # UserSession management
│   └── models.py          # Context models
└── tests/                 # Test suite
```

### Key Features

**TTS Caching System**
- Global cross-user cache (same text + voice = shared audio)
- Priority-based generation (LIVE > PREFETCH > SCHEDULED)
- Disk persistence with async I/O

**Session Management**
- Per-user voice config
- Playback state tracking
- Cross-device resume

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/curriculum` | GET/POST | Curriculum operations |
| `/api/tts` | POST | TTS generation |
| `/api/tts/cache/stats` | GET | Cache statistics |
| `/api/sessions` | GET/POST | Session management |
| `/api/deployments` | GET/POST | Scheduled deployments |

See [[API-Reference]] for complete endpoint documentation.

### Running Tests

```bash
cd server/management
python -m pytest tests/ -v

# With coverage
python -m pytest tests/ --cov=. --cov-report=html
```

## Operations Console (Port 3000)

### Purpose

The Operations Console provides:
- System health monitoring
- Service status dashboard
- Performance metrics
- Curriculum Studio
- Plugin management
- Log viewer

### Setup

```bash
cd server/web

# Install dependencies
npm install

# Development server
npm run dev

# Production build
npm run build
npm start
```

### Project Structure

```
server/web/
├── src/
│   ├── app/               # Next.js App Router pages
│   │   ├── page.tsx       # Dashboard
│   │   ├── metrics/       # Metrics page
│   │   ├── logs/          # Logs viewer
│   │   └── api/           # API routes (proxy)
│   ├── components/
│   │   ├── dashboard/     # Dashboard components
│   │   ├── curriculum/    # Curriculum Studio
│   │   └── ui/            # Reusable components
│   └── lib/
│       ├── api-client.ts  # API client
│       └── mock-data.ts   # Development mocks
└── tests/                 # Test suite
```

### Development Modes

**Standalone (Mock)**
```bash
# Uses mock data, no backend required
NEXT_PUBLIC_USE_MOCK=true npm run dev
```

**Connected**
```bash
# Connects to Management API
NEXT_PUBLIC_USE_MOCK=false npm run dev
```

### Running Tests

```bash
cd server/web

# Lint
npm run lint

# Type check
npm run typecheck

# Tests
npm test
```

## Web Client (Port 3001)

### Purpose

Browser-based voice tutoring with:
- Real-time voice via WebRTC
- Curriculum browser
- Visual asset display
- Responsive design

### Setup

```bash
cd server/web-client
pnpm install
pnpm dev
```

See `server/web-client/README.md` for detailed documentation.

## Development Workflow

### Starting All Services

```bash
# Terminal 1: Management API
cd server/management
source .venv/bin/activate
python server.py

# Terminal 2: Operations Console
cd server/web
npm run dev

# Terminal 3: Web Client (optional)
cd server/web-client
pnpm dev
```

### Using USM Service Manager

If USM (UnaMentis Service Manager) is installed:

```bash
/service status              # Check all services
/service start-all           # Start all services
/service restart management-api  # Restart specific service
```

### Code Quality

**Python (Management API)**
```bash
# Lint
ruff check server/management/

# Format
ruff format server/management/
```

**TypeScript (Operations Console)**
```bash
cd server/web
npm run lint
npm run lint:fix
```

## Debugging

### Log Server

```bash
# Start log server
python3 scripts/log_server.py &

# View at http://localhost:8765
```

### Management API Logs

```bash
# Run with debug logging
LOG_LEVEL=DEBUG python server.py
```

### Operations Console

```bash
# Enable debug mode
NEXT_PUBLIC_DEBUG=true npm run dev
```

## Related Pages

- [[Dev-Environment]] - Setup guide
- [[API-Reference]] - API documentation
- [[Architecture]] - System design
- [[Testing]] - Testing guide

---

Back to [[Home]]
