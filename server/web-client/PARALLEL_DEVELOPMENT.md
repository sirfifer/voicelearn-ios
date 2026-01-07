# Parallel Development Guide

This guide enables safe parallel development using multiple Claude Code instances.

## Current Status

| Phase | Status | Notes |
|-------|--------|-------|
| **Project Setup** | Complete | package.json, configs, docs created |
| **Pre-work** | Complete | Types, directory structure, initial components |
| **Track 1: API/Auth** | Complete | API client, auth hooks, login/register forms |
| **Track 2: Voice Pipeline** | Complete | Providers, audio utilities, session management |
| **Track 3: UI Components** | Complete | UI primitives, visual renderers, curriculum components |
| **Integration** | Complete | App layout, pages, API routes |
| **Help System** | Complete | Tooltips, onboarding tour, help modal, keyboard shortcuts |
| **Testing & Polish** | Complete | Unit tests (214 passing), build passing |

**Last Updated**: 2026-01-06

## How It Works

Each Claude Code instance runs in complete isolation with its own context. This allows multiple instances to work simultaneously on different parts of the codebase without conflicts, as long as each instance owns exclusive directories.

## Execution Flow

```
Pre-work (1 instance, ~30 min)
    │
    ▼
┌─────────────────────────────────────────────────┐
│  PARALLEL PHASE (3 instances simultaneously)    │
├─────────────────────────────────────────────────┤
│  Track 1        Track 2         Track 3         │
│  API/Auth       Voice Pipeline  UI Components   │
│  (~2 hours)     (~3 hours)      (~2 hours)      │
└─────────────────────────────────────────────────┘
    │
    ▼
Integration (1 instance, ~1 hour)
    │
    ▼
Testing & Polish
```

---

## Pre-Work (Must Complete First)

**Run this BEFORE starting parallel tracks.**

One instance must complete project initialization:

```
□ Run: npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir
□ Install dependencies from package.json
□ Create complete TypeScript types in src/types/
□ Set up remaining configs (next.config.ts already exists)
□ Create empty directory structure for all tracks
```

### Pre-work Prompt

Copy this prompt into a Claude Code instance:

```
You are completing Pre-work for the UnaMentis web client parallel development.

LOCATION: /Users/ramerman/dev/unamentis/server/web-client/

TASKS:
1. Initialize Next.js project (if not already done):
   npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir

2. Install all dependencies from package.json (npm install)

3. Create TypeScript types in src/types/:
   - src/types/api.ts - API request/response types
   - src/types/session.ts - Session state types
   - src/types/curriculum.ts - UMCF curriculum types
   - src/types/providers.ts - STT/TTS/LLM provider types
   - src/types/auth.ts - Authentication types
   - src/types/index.ts - Re-export all types

4. Create empty directory structure:
   - src/lib/api/
   - src/lib/providers/
   - src/lib/audio/
   - src/lib/session/
   - src/components/ui/
   - src/components/auth/
   - src/components/session/
   - src/components/visual/
   - src/components/curriculum/

REFERENCE DOCS:
- WEB_CLIENT_TDD.md - TypeScript interfaces section
- docs/API_REFERENCE.md - API types
- docs/UMCF_SPECIFICATION.md - Curriculum types

When complete, all parallel tracks can start simultaneously.
```

---

## Directory Ownership Summary

| Directory | Track | Status |
|-----------|-------|--------|
| `src/types/` | Pre-work | Shared (read-only after pre-work) |
| `src/lib/api/` | Track 1 | Exclusive |
| `src/components/auth/` | Track 1 | Exclusive |
| `src/lib/providers/` | Track 2 | Exclusive |
| `src/lib/audio/` | Track 2 | Exclusive |
| `src/lib/session/` | Track 2 | Exclusive |
| `src/components/ui/` | Track 3 | Exclusive |
| `src/components/session/` | Track 3 | Exclusive |
| `src/components/visual/` | Track 3 | Exclusive |
| `src/components/curriculum/` | Track 3 | Exclusive |
| `src/app/` | Integration | Exclusive |
| `src/components/help/` | Help System | Exclusive |
| `src/lib/help/` | Help System | Exclusive |

---

## Track 1: API Client & Authentication

**Owner directories**:
- `src/lib/api/` (exclusive)
- `src/components/auth/` (exclusive)

**Deliverables**:
- [ ] API client with fetch wrapper and error handling
- [ ] Token manager (memory storage, refresh before expiry)
- [ ] Auth hooks (useAuth, useUser)
- [ ] SWR hooks for data fetching (useCurricula, useSession)
- [ ] Login form component
- [ ] Registration form component
- [ ] Auth context provider

**Reference docs**:
- `docs/API_REFERENCE.md` - All endpoint schemas
- `docs/AUTHENTICATION.md` - Token flow, device registration

### Track 1 Prompt

Copy this prompt into a Claude Code instance:

```
You are implementing Track 1: API Client & Authentication for the UnaMentis web client.

LOCATION: /Users/ramerman/dev/unamentis/server/web-client/

YOUR DIRECTORIES (you own these exclusively):
- src/lib/api/
- src/components/auth/

REFERENCE DOCS TO READ FIRST:
- docs/API_REFERENCE.md (complete server API)
- docs/AUTHENTICATION.md (JWT token flows)

TYPES ARE DEFINED IN:
- src/types/ (READ ONLY - do not modify)

YOUR DELIVERABLES:
1. src/lib/api/client.ts - Base fetch wrapper with auth headers
2. src/lib/api/auth.ts - Login, register, refresh, logout functions
3. src/lib/api/token-manager.ts - In-memory token storage, auto-refresh
4. src/lib/api/hooks.ts - SWR hooks: useCurricula, useSession, etc.
5. src/lib/api/index.ts - Public exports
6. src/components/auth/LoginForm.tsx
7. src/components/auth/RegisterForm.tsx
8. src/components/auth/AuthProvider.tsx - Context for auth state

SAFETY RULES:
- Do NOT create or modify files outside your directories
- Do NOT touch src/types/ - types are already defined
- Do NOT create files in src/app/ - that's another track
- Export everything needed from src/lib/api/index.ts

The Management API runs on port 8766. All auth endpoints proxy there.
```

---

## Track 2: Voice Pipeline & Providers

**Owner directories**:
- `src/lib/providers/` (exclusive)
- `src/lib/audio/` (exclusive)
- `src/lib/session/` (exclusive)

**Deliverables**:
- [x] Provider interfaces (STT, TTS, LLM)
- [x] OpenAI Realtime provider (WebRTC)
- [x] Deepgram STT provider (WebSocket)
- [x] ElevenLabs TTS provider (streaming)
- [x] Provider manager (runtime switching)
- [x] Web Audio utilities (AudioContext, worklets)
- [x] XState session state machine
- [x] useSession hook for React

**Reference docs**:
- `docs/PROVIDER_GUIDE.md` - All provider APIs
- `docs/WEBSOCKET_PROTOCOL.md` - WebRTC and WebSocket flows
- `WEB_CLIENT_TDD.md` - Session state machine specification

### Track 2 Prompt

Copy this prompt into a Claude Code instance:

```
You are implementing Track 2: Voice Pipeline & Providers for the UnaMentis web client.

LOCATION: /Users/ramerman/dev/unamentis/server/web-client/

YOUR DIRECTORIES (you own these exclusively):
- src/lib/providers/
- src/lib/audio/
- src/lib/session/

REFERENCE DOCS TO READ FIRST:
- docs/PROVIDER_GUIDE.md (all voice provider APIs)
- docs/WEBSOCKET_PROTOCOL.md (WebRTC, WebSocket protocols)
- WEB_CLIENT_TDD.md (session state machine in Section 5)

TYPES ARE DEFINED IN:
- src/types/ (READ ONLY - do not modify)

YOUR DELIVERABLES:
1. src/lib/providers/types.ts - Provider interfaces (re-export from types)
2. src/lib/providers/openai-realtime.ts - WebRTC implementation
3. src/lib/providers/deepgram-stt.ts - WebSocket STT
4. src/lib/providers/elevenlabs-tts.ts - Streaming TTS
5. src/lib/providers/manager.ts - Provider switching
6. src/lib/providers/index.ts - Public exports
7. src/lib/audio/context.ts - AudioContext management
8. src/lib/audio/worklets.ts - Audio processing worklets
9. src/lib/audio/vad.ts - Voice activity detection
10. src/lib/session/machine.ts - XState session state machine
11. src/lib/session/hooks.ts - useSession React hook
12. src/lib/session/index.ts - Public exports

SESSION STATES (from iOS):
idle → userSpeaking → processingUserUtterance → aiThinking → aiSpeaking → interrupted → paused

SAFETY RULES:
- Do NOT create or modify files outside your directories
- Do NOT touch src/types/
- Do NOT create UI components - that's Track 3
- Export everything from index.ts files
```

---

## Track 3: UI Components

**Owner directories**:
- `src/components/ui/` (exclusive)
- `src/components/session/` (exclusive)
- `src/components/visual/` (exclusive)
- `src/components/curriculum/` (exclusive)

**Deliverables**:
- [ ] Base UI components (Button, Dialog, Tabs, Toast)
- [ ] Transcript component (streaming text)
- [ ] Session controls (start, stop, pause)
- [ ] Voice waveform visualizer
- [ ] Visual panel container
- [ ] Formula renderer (KaTeX)
- [ ] Map renderer (Leaflet)
- [ ] Diagram renderer (Mermaid)
- [ ] Chart renderer (Chart.js)
- [ ] Curriculum browser
- [ ] Topic selector

**Reference docs**:
- `WEB_CLIENT_TDD.md` - Layout specifications, component hierarchy
- `docs/UMCF_SPECIFICATION.md` - Visual asset types and formats

### Track 3 Prompt

Copy this prompt into a Claude Code instance:

```
You are implementing Track 3: UI Components for the UnaMentis web client.

LOCATION: /Users/ramerman/dev/unamentis/server/web-client/

YOUR DIRECTORIES (you own these exclusively):
- src/components/ui/
- src/components/session/
- src/components/visual/
- src/components/curriculum/

REFERENCE DOCS TO READ FIRST:
- WEB_CLIENT_TDD.md (layouts, component hierarchy)
- docs/UMCF_SPECIFICATION.md (visual asset formats)

TYPES ARE DEFINED IN:
- src/types/ (READ ONLY - do not modify)

YOUR DELIVERABLES:

Base UI (src/components/ui/):
1. Button.tsx, Dialog.tsx, Tabs.tsx, Toast.tsx
2. Card.tsx, Input.tsx, Label.tsx
3. index.ts - exports

Session UI (src/components/session/):
4. Transcript.tsx - Streaming conversation display
5. SessionControls.tsx - Start/stop/pause buttons
6. VoiceWaveform.tsx - Audio visualizer
7. SessionHeader.tsx - Status, timer
8. index.ts - exports

Visual Renderers (src/components/visual/):
9. VisualPanel.tsx - Container for assets
10. FormulaRenderer.tsx - KaTeX integration
11. MapRenderer.tsx - Leaflet integration
12. DiagramRenderer.tsx - Mermaid integration
13. ChartRenderer.tsx - Chart.js integration
14. ImageRenderer.tsx - Image display
15. index.ts - exports

Curriculum (src/components/curriculum/):
16. CurriculumBrowser.tsx - Browse available curricula
17. TopicSelector.tsx - Select topic to study
18. CurriculumCard.tsx - Curriculum preview card
19. index.ts - exports

DESIGN PATTERNS:
- Components receive data via props (don't import from src/lib/)
- Use TypeScript types from src/types/
- Use Tailwind CSS for styling
- Support both desktop and mobile layouts

SAFETY RULES:
- Do NOT create files outside your directories
- Do NOT create files in src/lib/ - that's other tracks
- Do NOT create files in src/app/ - that's integration
- Components should be "dumb" - receive props, render UI
```

---

## Integration Phase (After Tracks 1-3)

**Owner directories**:
- `src/app/` (exclusive)
- Root config files

**Deliverables**:
- [ ] App layout with responsive design
- [ ] Home page
- [ ] Session page (wire up all components)
- [ ] Curriculum page
- [ ] Settings page
- [ ] Auth pages (login, register)
- [ ] API routes (proxy to Management API)

### Integration Prompt

Copy this prompt into a Claude Code instance after Tracks 1-3 complete:

```
You are implementing the Integration Phase for the UnaMentis web client.

LOCATION: /Users/ramerman/dev/unamentis/server/web-client/

Tracks 1-3 have been completed. You now need to wire everything together.

YOUR DIRECTORIES:
- src/app/ (exclusive)

IMPORTS AVAILABLE:
- src/lib/api/ - API client, auth, hooks
- src/lib/providers/ - Voice providers
- src/lib/session/ - Session state machine
- src/components/ - All UI components

YOUR DELIVERABLES:
1. src/app/layout.tsx - Root layout with providers
2. src/app/page.tsx - Home/dashboard
3. src/app/session/page.tsx - Voice tutoring session
4. src/app/curriculum/page.tsx - Browse curricula
5. src/app/settings/page.tsx - User settings
6. src/app/login/page.tsx - Login form
7. src/app/register/page.tsx - Registration form
8. src/app/api/auth/[...path]/route.ts - Proxy to 8766
9. src/app/api/curricula/[...path]/route.ts - Proxy to 8766
10. src/app/api/session/[...path]/route.ts - Proxy to 8766

Wire up:
- AuthProvider wrapping the app
- Session state machine in session page
- Transcript + VisualPanel in session page
- CurriculumBrowser in curriculum page
```

---

## Safety Rules Summary

To prevent conflicts between parallel instances:

1. **Never modify files outside your owned directories**
2. **Treat src/types/ as read-only** (defined in pre-work)
3. **Export everything from index.ts files** for integration
4. **Components should accept props**, not import directly from lib
5. **Don't create files in src/app/** until integration phase

## Verification Checklist

After all tracks complete:

```bash
# Should compile without errors
npm run build

# Should show no lint errors
npm run lint

# Check all exports are in place
grep -r "export" src/lib/*/index.ts
grep -r "export" src/components/*/index.ts
```

## Troubleshooting

**Import errors after integration**:
- Check that all tracks created their index.ts export files
- Verify types are exported from src/types/index.ts

**Type mismatches**:
- All tracks should use types from src/types/
- Don't redefine types in individual tracks

**Missing dependencies**:
- Run `npm install` to ensure all packages from package.json are installed
