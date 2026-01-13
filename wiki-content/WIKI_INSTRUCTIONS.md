# UnaMentis Wiki Content Package

This folder contains ready-to-publish content for the UnaMentis GitHub Wiki.

**Last Updated**: January 12, 2026

## How to Use This Content

### Option 1: Clone and Push (Recommended)

```bash
# Clone the wiki repository
git clone https://github.com/UnaMentis/unamentis.wiki.git
cd unamentis.wiki

# Copy all wiki content
cp /path/to/unamentis/wiki-content/*.md .

# Commit and push
git add .
git commit -m "Update wiki documentation - January 2026"
git push
```

### Option 2: Direct Upload to GitHub Wiki

1. Go to [github.com/UnaMentis/unamentis/wiki](https://github.com/UnaMentis/unamentis/wiki)
2. If the wiki doesn't exist, click "Create the first page" and create "Home"
3. For each `.md` file in this folder:
   - Click "New Page"
   - Name it according to the file name (without `.md`)
   - Copy the content
   - Save

### Option 3: Use GitHub Actions (Automated)

See the sync workflow example in `docs/tools/GITHUB_WIKI.md`.

## File Inventory

### Core Pages (Required)

| File | Purpose | Status |
|------|---------|--------|
| `_Sidebar.md` | Navigation menu | Exists |
| `_Footer.md` | Page footer | Exists |
| `Home.md` | Landing page | Exists |
| `Getting-Started.md` | Quick start | Exists |

### Development Guides

| File | Purpose | Status |
|------|---------|--------|
| `Development.md` | Development workflows | Exists |
| `Dev-Environment.md` | Complete setup guide | NEW |
| `iOS-Development.md` | iOS-specific guide | NEW |
| `Server-Development.md` | Server components | NEW |
| `Testing.md` | Testing philosophy | NEW |
| `Contributing.md` | Contribution guide | Exists |

### Architecture & Reference

| File | Purpose | Status |
|------|---------|--------|
| `Architecture.md` | System overview | Exists |
| `Voice-Pipeline.md` | Voice processing | NEW |
| `API-Reference.md` | API documentation | NEW |

### Tools

| File | Purpose | Status |
|------|---------|--------|
| `Tools.md` | Tools overview | Exists |
| `CodeRabbit.md` | AI code review | Exists |
| `MCP-Servers.md` | MCP integration | NEW |
| `GitHub-Actions.md` | CI/CD workflows | NEW |

### Support

| File | Purpose | Status |
|------|---------|--------|
| `Troubleshooting.md` | Common issues | NEW |

### Production & Security

| File | Purpose | Status |
|------|---------|--------|
| `App-Store-Compliance.md` | App Store submission | NEW |
| `Security-Scaling.md` | Security & scaling roadmap | NEW |
| `Specialized-Modules.md` | Learning modules (SAT, Knowledge Bowl) | NEW |

## Page Dependencies

```
Home
├── Getting-Started (quick start)
│   └── Dev-Environment (detailed setup)
├── Development (workflows)
│   ├── iOS-Development
│   ├── Server-Development
│   └── Testing
├── Architecture (system design)
│   ├── Voice-Pipeline
│   └── Specialized-Modules
├── Production (deployment)
│   ├── App-Store-Compliance
│   └── Security-Scaling
├── Tools
│   ├── CodeRabbit
│   ├── MCP-Servers
│   └── GitHub-Actions
├── API-Reference
├── Contributing
└── Troubleshooting
```

## Maintenance Guidelines

### When to Update

- After significant feature additions
- When API endpoints change
- When setup procedures change
- When new tools are adopted
- Quarterly review (minimum)

### How to Keep in Sync

The wiki should complement, not duplicate, the `/docs` folder:

| Source Documentation | Wiki Page |
|---------------------|-----------|
| `docs/setup/DEV_ENVIRONMENT.md` | Dev-Environment |
| `docs/ios/IOS_STYLE_GUIDE.md` | iOS-Development |
| `docs/testing/TESTING.md` | Testing |
| `docs/tools/CODERABBIT.md` | CodeRabbit |
| `docs/CONTRIBUTING.md` | Contributing |
| `docs/architecture/PROJECT_OVERVIEW.md` | Architecture |

### Link Syntax

- Internal wiki links: `[[Page Name]]`
- Repository links: `[text](https://github.com/UnaMentis/unamentis/...)`
- Anchor links within page: `[Section](#section-name)`

## New Pages Added (January 2026)

The following pages were added to provide comprehensive wiki coverage:

1. **Dev-Environment.md** - Detailed environment setup (macOS, Xcode, Python, Node.js)
2. **iOS-Development.md** - iOS coding standards, architecture, and best practices
3. **Server-Development.md** - Management API and Operations Console development
4. **Voice-Pipeline.md** - Voice processing architecture deep-dive
5. **Testing.md** - Testing philosophy (Real Over Mock), test commands
6. **MCP-Servers.md** - MCP integration for AI-assisted development
7. **GitHub-Actions.md** - CI/CD workflows and quality gates
8. **API-Reference.md** - Management API endpoints
9. **Troubleshooting.md** - Common issues and solutions
10. **App-Store-Compliance.md** - App Store submission guide and checklists
11. **Security-Scaling.md** - Security architecture and scaling roadmap
12. **Specialized-Modules.md** - SAT Prep, Knowledge Bowl learning modules
