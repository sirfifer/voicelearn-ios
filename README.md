# VoiceLearn iOS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Real-time bidirectional voice AI platform for extended educational conversations**

## Why VoiceLearn?

One of my earliest experiences re-engaging with AI earlier this year was with ChatGPT's Advanced Voice Mode. Pretty quickly, I fell in love with the capability of having seamless, hands-free conversations with AI. Initially these were about bouncing off ideas and exploring things, but it evolved into the ultimate way of learning. I could give advanced topics to the AI and it would deliver detailed lectures on demand.

That capability was completely killed when ChatGPT 5.0 came out. No other models or tools have matched ChatGPT's seamless user experience. It got better with 5.1, but it's been hit or miss. Lately it's been useless again.

I realized I can't rely on off-the-shelf tools to meet this need. There's a lot of more advanced things I can bring to this purpose. I really think this is ultimately a universal need: a personalized tutor that can work with you over long stretches of time, develop an understanding of your learning progress and learning style, and evolve into a true personal tutor over time.

## Overview

VoiceLearn is an iOS application that enables 60-90+ minute voice-based learning sessions with AI tutoring. Built for iPhone 16/17 Pro Max with emphasis on:

- Sub-500ms end-to-end latency
- Natural interruption handling (no push-to-talk)
- Curriculum-driven learning with progress tracking
- Comprehensive observability and cost tracking
- Modular architecture with swappable providers

## Provider Flexibility

VoiceLearn is designed to be provider-agnostic. The system supports pluggable providers for every component of the voice AI pipeline:

- **STT (Speech-to-Text)**: AssemblyAI, Deepgram, or any compatible provider
- **TTS (Text-to-Speech)**: ElevenLabs, Deepgram Aura, or alternatives
- **LLM**: OpenAI, Anthropic, or locally-hosted models
- **Embeddings**: OpenAI or compatible embedding services
- **VAD**: Silero, TEN, or other voice activity detection

The right model depends on the task, the moment, and the cost. The architecture prioritizes flexibility so you can:

- Swap providers without code changes
- Use different models for different tasks (fast/cheap for simple responses, powerful for complex explanations)
- Run locally-hosted models when privacy or cost matters
- A/B test provider combinations to find optimal setups

## Quick Start

```bash
# 1. Create Xcode project (manual - see docs/QUICKSTART.md)

# 2. Set up environment
./scripts/setup-local-env.sh

# 3. Configure API keys
cp .env.example .env
# Edit .env and add your keys

# 4. Run tests
./scripts/test-quick.sh
```

See [Quick Start Guide](docs/QUICKSTART.md) for complete setup.

## Documentation

- [Quick Start Guide](docs/QUICKSTART.md) - START HERE
- [Setup Guide](docs/SETUP.md)
- [Testing Guide](docs/TESTING.md)
- [Contributing](docs/CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Changelog](CHANGELOG.md)

## Development

```bash
# Quick tests
./scripts/test-quick.sh

# All tests
./scripts/test-all.sh

# Format code
./scripts/format.sh

# Lint code
./scripts/lint.sh

# Health check
./scripts/health-check.sh
```

## Architecture

```
VoiceLearn/
├── Core/           # Core business logic
│   ├── Audio/      # Audio engine, VAD
│   ├── Session/    # Session management
│   ├── Curriculum/ # Learning materials
│   └── Telemetry/  # Metrics
├── Services/       # Provider integrations
│   ├── STT/        # Speech-to-text
│   ├── TTS/        # Text-to-speech
│   └── LLM/        # Language models
└── UI/             # SwiftUI views
```

## Technology Stack

- **Language**: Swift 6.0
- **UI**: SwiftUI
- **Audio**: AVFoundation
- **Transport**: LiveKit WebRTC
- **ML**: Core ML (Silero VAD)
- **Persistence**: Core Data
- **Testing**: XCTest (no mocks, real implementations)

## Project Vision

### Open Source Core

The fundamental core of VoiceLearn will always remain open source. This ensures the greatest possible audience can collaborate on and utilize this work. The open source commitment includes:

- Core voice pipeline and session management
- Curriculum system and progress tracking
- All provider integrations
- Cross-platform support (planned)

### Future Directions

- **Cross-platform**: Expand beyond iOS to Android, web, and desktop
- **Server component**: Enable cloud-hosted sessions and curriculum management
- **Plugin architecture**: Extensible system for value-added capabilities

### Enterprise Features (Future)

A separate commercial layer may offer enterprise-specific capabilities:

- Single sign-on (SSO) integration
- Advanced reporting and analytics
- Permission controls and user management
- Corporate curriculum publishing and management
- Priority support

These features would build on top of the open source core without restricting it.

## Contributing

Contributions are welcome! Please read our [Contributing Guide](docs/CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md) before submitting PRs.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

Copyright (c) 2025 Richard Amerman
