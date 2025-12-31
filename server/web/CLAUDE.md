# UnaMentis Server

Next.js/React web application providing a unified interface for system management and curriculum content.

**URL:** http://localhost:3000

## Purpose

The UnaMentis Server is the main web interface for managing UnaMentis deployments, from single home/school setups to large enterprise installations.

### System Management
- System health monitoring (CPU, memory, thermal, battery)
- Service status (Ollama, VibeVoice, Piper, etc.)
- Power/idle management profiles
- Logs, metrics, and performance data
- Client connection monitoring

### Content Management
- Curriculum browsing and management
- Curriculum Studio for viewing/editing UMCF content
- Import source configuration and job monitoring
- Plugin management for content sources

## Tech Stack

- **Next.js 16.1.0** with App Router
- **React 19.2.3**
- **TypeScript 5**
- **Tailwind CSS 4** for styling
- **Lucide React** for icons
- **clsx** + **tailwind-merge** for class utilities

## Project Structure

```
src/
├── app/           # Next.js App Router pages
│   └── api/       # API routes (proxy to Management API)
├── components/    # React components
│   ├── curriculum/  # Curriculum Studio components
│   ├── dashboard/   # Dashboard panels
│   └── ui/          # Reusable UI components
├── lib/           # Utilities and API client
└── types/         # TypeScript type definitions
public/            # Static assets
```

## npm Scripts

```bash
npm run dev     # Start development server (auto-reloads)
npm run build   # Production build
npm run start   # Start production server
npm run lint    # Run ESLint
```

## Conventions

- Use TypeScript for all new files
- Use functional components with hooks
- Use Tailwind CSS for styling (no separate CSS files)
- Use Lucide React for icons
- Follow Next.js App Router patterns

## Development

The Next.js dev server auto-reloads on file changes, so manual restart is rarely needed. If you need to force restart:

```bash
cd server/web && npm run dev
```

## Architecture

The UnaMentis Server (port 3000) acts as a frontend that proxies requests to the Management API (port 8766) for curriculum and configuration data. This separation allows the backend to be replaced or scaled independently.
