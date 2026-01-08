# UnaMentis Wiki

Welcome to the UnaMentis documentation wiki.

## About UnaMentis

UnaMentis is an iOS voice AI tutoring app built with Swift 6.0/SwiftUI, enabling 60-90+ minute voice-based learning sessions with sub-500ms latency. The project is developed with 100% AI assistance.

## Quick Links

- [[Getting-Started]] - Set up your development environment
- [[Development]] - Development guides and workflows
- [[Tools]] - Development tools (CodeRabbit, CI/CD, etc.)
- [[Architecture]] - System design and architecture
- [[Contributing]] - How to contribute

## Key Features

- **Voice-First Learning**: Natural conversation-based tutoring
- **Sub-500ms Latency**: Real-time voice interaction
- **Multi-Provider Support**: Multiple STT, TTS, and LLM backends
- **Curriculum Framework**: UMCF format for structured learning
- **Session Stability**: 90+ minute sessions without degradation

## Repository Links

- [Main Repository](https://github.com/UnaMentis/unamentis)
- [Issues](https://github.com/UnaMentis/unamentis/issues)
- [Pull Requests](https://github.com/UnaMentis/unamentis/pulls)
- [Discussions](https://github.com/UnaMentis/unamentis/discussions)

## Getting Help

- Check the [[Getting-Started]] guide
- Search existing [Issues](https://github.com/UnaMentis/unamentis/issues)
- Review the [[Tools]] documentation
- Start a [Discussion](https://github.com/UnaMentis/unamentis/discussions)

## Project Components

| Component | Description |
|-----------|-------------|
| iOS App | Swift/SwiftUI voice tutoring client |
| Management API | Python/aiohttp backend (port 8766) |
| Web Interface | Next.js/React frontend (port 3000) |
| Curriculum | UMCF format learning content |
| Latency Harness | Performance testing infrastructure |
