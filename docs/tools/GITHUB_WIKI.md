# GitHub Wiki Setup and Usage

This document explains how to set up, configure, and maintain the UnaMentis GitHub Wiki.

## Table of Contents

- [Overview](#overview)
- [Initial Setup](#initial-setup)
- [Wiki Structure](#wiki-structure)
- [Working with the Wiki](#working-with-the-wiki)
- [Wiki Pages Reference](#wiki-pages-reference)
- [Best Practices](#best-practices)

## Overview

GitHub Wikis provide a place for project documentation that lives alongside your code. Unlike README files, wikis support multiple pages with navigation, making them ideal for comprehensive documentation.

### Key Characteristics

- **Separate Git Repository**: The wiki is its own git repo (`unamentis.wiki.git`)
- **Markdown-Based**: All pages are markdown files
- **Version Controlled**: Full git history for all changes
- **Searchable**: GitHub provides search across wiki content
- **No API**: Must be initialized via web interface, then can be managed via git

## Initial Setup

The GitHub Wiki must be initialized manually before it can be edited programmatically.

### Step 1: Initialize via Web Interface

1. Go to [github.com/UnaMentis/unamentis](https://github.com/UnaMentis/unamentis)
2. Click the **Wiki** tab
3. Click **Create the first page**
4. Title: `Home` (this is required)
5. Add initial content (see [Home Page Template](#home-page-template) below)
6. Click **Save Page**

### Step 2: Clone the Wiki Repository

Once initialized, the wiki can be cloned locally:

```bash
# Clone the wiki repo
git clone https://github.com/UnaMentis/unamentis.wiki.git

# Navigate to wiki
cd unamentis.wiki
```

### Step 3: Set Up Local Development

```bash
# Add origin if not set
git remote add origin https://github.com/UnaMentis/unamentis.wiki.git

# Create branch for changes
git checkout -b update-docs

# Make changes...
# Commit and push
git add .
git commit -m "Update wiki documentation"
git push origin update-docs

# Or push directly to main
git push origin main
```

## Wiki Structure

### Planned Page Hierarchy

```
Home.md                          # Landing page
├── Getting-Started.md           # Quick start guide
├── Development.md               # Development overview
│   ├── Dev-Environment.md       # Environment setup
│   ├── iOS-Development.md       # iOS-specific guide
│   ├── Server-Development.md    # Server-specific guide
│   └── Testing.md               # Testing guide
├── Tools.md                     # Development tools
│   ├── CodeRabbit.md           # AI code review
│   ├── GitHub-Actions.md       # CI/CD
│   └── MCP-Servers.md          # MCP integration
├── Architecture.md              # System architecture
│   ├── iOS-Architecture.md     # iOS app architecture
│   ├── Server-Architecture.md  # Server architecture
│   └── Voice-Pipeline.md       # Voice processing
├── API-Reference.md             # API documentation
│   ├── Management-API.md       # Backend API
│   └── Web-API.md              # Web frontend API
└── Contributing.md              # Contribution guidelines
```

### File Naming Conventions

- Use hyphens for spaces: `Getting-Started.md`
- Use title case: `iOS-Development.md`
- Keep names concise but descriptive
- The filename becomes the page URL

## Working with the Wiki

### Adding a New Page

**Via Web Interface:**
1. Go to the wiki
2. Click **New Page**
3. Enter title and content
4. Save

**Via Git:**
```bash
cd unamentis.wiki
echo "# New Page Title" > New-Page.md
git add New-Page.md
git commit -m "Add new page"
git push
```

### Editing Existing Pages

**Via Web Interface:**
1. Navigate to the page
2. Click **Edit**
3. Make changes
4. Save

**Via Git:**
```bash
cd unamentis.wiki
# Edit the markdown file
vim Existing-Page.md
git add Existing-Page.md
git commit -m "Update existing page"
git push
```

### Creating Sidebar Navigation

Create a file named `_Sidebar.md` for custom navigation:

```markdown
# UnaMentis Wiki

**Getting Started**
* [[Home]]
* [[Getting Started]]

**Development**
* [[Development]]
* [[Dev Environment]]
* [[Testing]]

**Tools**
* [[CodeRabbit]]
* [[GitHub Actions]]

**Architecture**
* [[Architecture]]
* [[Voice Pipeline]]

**Reference**
* [[API Reference]]
* [[Contributing]]
```

### Creating Footer

Create `_Footer.md` for page footer:

```markdown
---
[UnaMentis](https://github.com/UnaMentis/unamentis) |
[Issues](https://github.com/UnaMentis/unamentis/issues) |
[Discussions](https://github.com/UnaMentis/unamentis/discussions)
```

## Wiki Pages Reference

### Home Page Template

Use this as the initial Home.md content:

```markdown
# UnaMentis Wiki

Welcome to the UnaMentis documentation wiki.

## About UnaMentis

UnaMentis is an iOS voice AI tutoring app built with Swift 6.0/SwiftUI, enabling
60-90+ minute voice-based learning sessions with sub-500ms latency.

## Quick Links

- [[Getting Started]] - Set up your development environment
- [[Development]] - Development guides and workflows
- [[Tools]] - Development tools (CodeRabbit, CI/CD, etc.)
- [[Architecture]] - System design and architecture
- [[API Reference]] - API documentation
- [[Contributing]] - How to contribute

## Repository Links

- [Main Repository](https://github.com/UnaMentis/unamentis)
- [Issues](https://github.com/UnaMentis/unamentis/issues)
- [Pull Requests](https://github.com/UnaMentis/unamentis/pulls)

## Getting Help

- Check the [[Getting Started]] guide
- Search existing [Issues](https://github.com/UnaMentis/unamentis/issues)
- Start a [Discussion](https://github.com/UnaMentis/unamentis/discussions)
```

### CodeRabbit Wiki Page

The CodeRabbit documentation should be copied to the wiki as `CodeRabbit.md`.
See [docs/tools/CODERABBIT.md](../tools/CODERABBIT.md) for the full content.

## Best Practices

### Content Guidelines

1. **Keep Pages Focused**: One topic per page
2. **Use Consistent Formatting**: Follow markdown conventions
3. **Add Navigation**: Use `[[Page Name]]` links liberally
4. **Include Examples**: Code examples and screenshots help
5. **Keep Updated**: Review and update regularly

### Maintenance Workflow

1. **Sync with Docs**: Keep wiki in sync with `/docs` folder
2. **Review Changes**: Review wiki changes in PRs when possible
3. **Track Issues**: Use GitHub issues for wiki improvement requests
4. **Assign Ownership**: Designate wiki maintainers

### When to Use Wiki vs Docs Folder

| Use Wiki For | Use /docs Folder For |
|--------------|---------------------|
| User-facing documentation | Developer documentation |
| Tutorials and guides | Technical specifications |
| FAQ and troubleshooting | Architecture decisions |
| Getting started content | API reference |
| External contributor docs | Internal team docs |

### Migration from /docs

To migrate documentation from the `/docs` folder to the wiki:

1. Clone the wiki repository
2. Copy relevant markdown files
3. Update internal links to use `[[Page Name]]` syntax
4. Add to sidebar navigation
5. Commit and push

## Automation Possibilities

While the wiki cannot be initialized programmatically, once created it can be:

1. **Updated via CI/CD**: GitHub Actions can push to the wiki repo
2. **Synced from /docs**: Script can copy docs to wiki on release
3. **Validated**: Links and formatting can be checked automatically

### Example GitHub Action for Wiki Sync

```yaml
name: Sync Docs to Wiki

on:
  push:
    branches: [main]
    paths: ['docs/**']

jobs:
  sync-wiki:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Clone wiki
        run: git clone https://github.com/UnaMentis/unamentis.wiki.git wiki

      - name: Copy docs
        run: |
          cp docs/tools/CODERABBIT.md wiki/CodeRabbit.md
          # Add more file copies as needed

      - name: Push to wiki
        run: |
          cd wiki
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git diff --staged --quiet || git commit -m "Sync from docs"
          git push
```

---

*Last updated: January 2025*
