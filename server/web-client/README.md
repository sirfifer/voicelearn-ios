# UnaMentis Web Client

Voice AI tutoring platform for the web, providing 60-90+ minute learning sessions with sub-500ms latency.

## Overview

This is the web client for UnaMentis, designed to match the iOS app's capabilities while leveraging the full real estate of desktop browsers and supporting mobile devices with modern browsers.

### Key Features

- **Voice-First Learning**: Real-time voice conversations with AI tutors
- **Multi-Provider Architecture**: OpenAI Realtime (WebRTC), Deepgram, ElevenLabs, Anthropic, self-hosted
- **Rich Media Display**: Formulas (KaTeX), maps (Leaflet), diagrams (Mermaid), charts (Chart.js), images
- **Responsive Design**: Desktop split-pane layout, mobile bottom sheet
- **Curriculum Integration**: UMCF format with full visual asset support
- **Cost Tracking**: Per-provider cost monitoring for optimization

## Getting Started

### Prerequisites

- Node.js 20.0.0 or higher
- pnpm 9.15.0 (recommended) or npm
- UnaMentis Management API running on port 8766

### Installation

```bash
# Clone the repository (if not already done)
cd /path/to/unamentis/server/web-client

# Install dependencies
pnpm install
# or
npm install

# Set up environment variables
cp .env.example .env.local
# Edit .env.local with your configuration
```

### Running the Development Server

```bash
# Start the development server
pnpm dev
# or
npm run dev

# Open http://localhost:3000 in your browser
```

### Building for Production

```bash
# Create production build
pnpm build
# or
npm run build

# Start production server
pnpm start
# or
npm run start
```

## Project Structure

```
web-client/
├── src/
│   ├── app/                    # Next.js App Router pages
│   │   ├── layout.tsx          # Root layout with providers
│   │   ├── page.tsx            # Home/dashboard page
│   │   ├── session/            # Voice tutoring session
│   │   ├── curriculum/         # Curriculum browsing
│   │   ├── settings/           # User settings
│   │   ├── login/              # Authentication
│   │   ├── register/           # User registration
│   │   └── api/                # API route handlers
│   │
│   ├── components/
│   │   ├── ui/                 # Reusable UI primitives (Button, Dialog, etc.)
│   │   ├── auth/               # Authentication components (LoginForm, etc.)
│   │   ├── session/            # Voice session UI (Transcript, Controls)
│   │   ├── visual/             # Visual renderers (Formula, Map, Chart)
│   │   ├── curriculum/         # Curriculum browser components
│   │   └── help/               # Help system components
│   │
│   ├── lib/
│   │   ├── api/                # API client and hooks
│   │   │   ├── client.ts       # Base fetch wrapper
│   │   │   ├── auth.ts         # Authentication functions
│   │   │   ├── token-manager.ts # Token storage and refresh
│   │   │   └── hooks.ts        # SWR data fetching hooks
│   │   │
│   │   ├── providers/          # Voice provider abstractions
│   │   │   ├── openai-realtime.ts  # WebRTC implementation
│   │   │   ├── deepgram-stt.ts     # WebSocket STT
│   │   │   ├── elevenlabs-tts.ts   # Streaming TTS
│   │   │   └── manager.ts          # Provider switching
│   │   │
│   │   ├── audio/              # Web Audio utilities
│   │   │   ├── context.ts      # AudioContext management
│   │   │   ├── worklets.ts     # Audio processing worklets
│   │   │   └── vad.ts          # Voice activity detection
│   │   │
│   │   ├── session/            # Session state management
│   │   │   ├── machine.ts      # XState session state machine
│   │   │   └── hooks.ts        # useSession React hook
│   │   │
│   │   └── help/               # Help content and utilities
│   │       └── content.ts      # Centralized help text
│   │
│   └── types/                  # TypeScript type definitions
│       ├── api.ts              # API request/response types
│       ├── session.ts          # Session state types
│       ├── curriculum.ts       # UMCF curriculum types
│       ├── providers.ts        # STT/TTS/LLM provider types
│       ├── auth.ts             # Authentication types
│       └── index.ts            # Re-export all types
│
├── docs/                       # Reference documentation
│   ├── API_REFERENCE.md        # Server API (70+ endpoints)
│   ├── UMCF_SPECIFICATION.md   # Curriculum format spec
│   ├── AUTHENTICATION.md       # Auth flows and token handling
│   ├── PROVIDER_GUIDE.md       # Voice provider integration
│   └── WEBSOCKET_PROTOCOL.md   # Real-time protocols
│
├── public/                     # Static assets
│
├── .env.example                # Environment variable template
├── .env.local                  # Local environment (git-ignored)
├── next.config.ts              # Next.js configuration
├── tailwind.config.ts          # Tailwind CSS configuration
├── tsconfig.json               # TypeScript configuration
├── package.json                # Dependencies and scripts
├── WEB_CLIENT_TDD.md           # Technical design document
├── BOOTSTRAP.md                # Implementation guide
├── PARALLEL_DEVELOPMENT.md     # Multi-instance development guide
└── CLAUDE.md                   # AI development instructions
```

## Available Scripts

| Script | Description |
|--------|-------------|
| `pnpm dev` | Start development server with hot reload |
| `pnpm build` | Create production build |
| `pnpm start` | Start production server |
| `pnpm lint` | Run ESLint for code quality |
| `pnpm lint:fix` | Fix auto-fixable lint issues |
| `pnpm format` | Format code with Prettier |
| `pnpm format:check` | Check code formatting |
| `pnpm typecheck` | Run TypeScript type checking |
| `pnpm test` | Run unit tests with Vitest |
| `pnpm test:ui` | Run tests with Vitest UI |
| `pnpm test:coverage` | Run tests with coverage report |
| `pnpm test:e2e` | Run end-to-end tests with Playwright |
| `pnpm test:e2e:ui` | Run E2E tests with Playwright UI |

## Environment Variables

Copy `.env.example` to `.env.local` and configure:

### Required

| Variable | Description | Default |
|----------|-------------|---------|
| `NEXT_PUBLIC_API_URL` | Management API URL | `http://localhost:8766` |
| `NEXT_PUBLIC_WS_URL` | WebSocket URL for real-time updates | `ws://localhost:8766` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `NEXT_PUBLIC_DEBUG` | Enable debug logging | `false` |
| `NEXT_PUBLIC_MOCK_PROVIDERS` | Use mock providers for development | `false` |
| `DEEPGRAM_API_KEY` | Deepgram STT/TTS fallback | - |
| `ELEVENLABS_API_KEY` | ElevenLabs TTS fallback | - |
| `ANTHROPIC_API_KEY` | Anthropic LLM fallback | - |

**Note**: OpenAI API keys are not stored client-side. The Management API provides ephemeral tokens for WebRTC connections.

## Development Workflow

### 1. Start Required Services

```bash
# Start the Management API (in another terminal)
cd ../management
python server.py

# Start the web client
cd ../web-client
pnpm dev
```

### 2. Development with Hot Reload

The development server supports hot module replacement. Changes to files in `src/` will automatically refresh the browser.

### 3. Code Quality

Before committing:

```bash
# Run all checks
pnpm lint && pnpm typecheck && pnpm test
```

### 4. Parallel Development

This project supports parallel development with multiple Claude Code instances. See `PARALLEL_DEVELOPMENT.md` for:
- Directory ownership per track
- Complete prompts for each parallel instance
- Safety boundaries to prevent conflicts

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Next.js 15+ with App Router |
| UI | React 19, TypeScript 5 |
| Styling | Tailwind CSS 4 |
| State | Zustand, XState, React Context |
| Data Fetching | SWR |
| Voice | OpenAI Realtime API (WebRTC), Web Audio API |
| Math Rendering | KaTeX |
| Maps | Leaflet / React Leaflet |
| Diagrams | Mermaid |
| Charts | Chart.js / React-Chartjs-2 |
| Testing | Vitest, Playwright, Testing Library |

## Server Integration

The web client connects to the UnaMentis Management API:

- **Management API**: `http://localhost:8766` (Python/aiohttp)
- **Authentication**: JWT with refresh tokens
- **Real-time**: WebSocket for logs/metrics

All API requests are proxied through Next.js API routes to avoid CORS issues and to keep API keys server-side.

## Browser Support

| Browser | Minimum Version | Notes |
|---------|-----------------|-------|
| Chrome | 90+ | Recommended, full WebRTC support |
| Safari | 15+ | Good WebRTC support |
| Firefox | 100+ | Limited WebRTC support |
| Edge | 90+ | Full support (Chromium-based) |

## Performance Targets

| Metric | Target |
|--------|--------|
| Voice Latency | <500ms median, <1000ms P99 |
| Session Duration | 90+ minutes stable |
| Memory Growth | <100MB over 90 minutes |
| First Contentful Paint | <1.5s |
| Time to Interactive | <3s |

## Documentation

| Document | Purpose |
|----------|---------|
| [WEB_CLIENT_TDD.md](./WEB_CLIENT_TDD.md) | Complete technical design |
| [BOOTSTRAP.md](./BOOTSTRAP.md) | Phased implementation guide |
| [PARALLEL_DEVELOPMENT.md](./PARALLEL_DEVELOPMENT.md) | Multi-instance development |
| [docs/API_REFERENCE.md](./docs/API_REFERENCE.md) | Server API documentation |
| [docs/UMCF_SPECIFICATION.md](./docs/UMCF_SPECIFICATION.md) | Curriculum format spec |
| [docs/PROVIDER_GUIDE.md](./docs/PROVIDER_GUIDE.md) | Voice provider integration |
| [docs/AUTHENTICATION.md](./docs/AUTHENTICATION.md) | Auth flows and tokens |
| [docs/WEBSOCKET_PROTOCOL.md](./docs/WEBSOCKET_PROTOCOL.md) | Real-time protocols |

## Troubleshooting

### Common Issues

**"Cannot connect to Management API"**
- Ensure the Management API is running on port 8766
- Check `NEXT_PUBLIC_API_URL` in `.env.local`

**"WebRTC connection failed"**
- Check browser compatibility (Chrome recommended)
- Ensure microphone permissions are granted
- Verify the Management API can generate ephemeral tokens

**"TypeScript errors after pulling updates"**
- Run `pnpm install` to update dependencies
- Run `pnpm typecheck` to see detailed errors

**"Tests failing"**
- Ensure all dependencies are installed: `pnpm install`
- Check for environment variables in `.env.test` if applicable

## License

Proprietary - UnaMentis
