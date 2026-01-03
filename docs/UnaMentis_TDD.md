
AI Powered Advanced Learning System






iOS TDD project setup package
Last message 1 month ago
iOS app TDD project setup and planning
Last message 1 month ago
iOS AI research app architecture and design
Last message 1 month ago
Real-time bidirectional voice AI for iOS
Last message 1 month ago
Building an AI voice tutoring platform
Last message 1 month ago
Memory
Only you
Purpose & context Richard is developing UnaMentis, an advanced iOS educational application designed for extended voice-based AI tutoring sessions lasting 60-90+ minutes. The app aims to deliver graduate-level lectures on complex topics through natural, bidirectional voice conversations where both user and AI can interrupt naturally without push-to-talk functionality. The project serves as both a practical educational tool and an exploration platform for voice AI technology, emphasizing best-of-breed performance while controlling costs through smart design choices. The architecture involves an iOS mobile client connecting via Model Context Protocol (MCP) to a learning management server that handles curriculum, progress tracking, and AI model proxying. Richard has substantial development resources including a MacBook Pro M4 Max with 128GB RAM for local model hosting and works primarily in VS Code, with plans to collaborate with Claude Code Sonnet 4.5 for implementation. Core requirements include comprehensive test coverage with no mock testing (all tests must use real implementations), maintaining a functional app throughout development for visual feedback, GitHub integration with both local and CI testing, and extensive documentation with inline comments. The system must support maximum flexibility with swappable LLM providers and extensive configuration options to enable experimentation with different combinations of quality, performance, and cost parameters. Current state Richard has completed comprehensive research on real-time bidirectional voice AI technologies, receiving detailed analysis from multiple AI research sources. A complete Technical Design Document has been created covering 13 sections including system architecture, core components, curriculum management, and a 12-week implementation roadmap. The project bootstrap package has been fully developed, including setup scripts, configuration files, development utilities, and documentation. The development environment is being established with a complete installer script containing all necessary project artifacts. Initial Xcode project setup is underway, with decisions made on using XCTest for testing framework alignment with the project's documentation and scripts. On the horizon Implementation will follow the established 12-week roadmap, beginning with core iOS project setup and basic voice pipeline implementation. Curriculum management system development is prioritized, including document processing capabilities and integration with online educational resources like OpenStax and MIT OpenCourseWare. The learning materials interface will feature three-tab navigation for hierarchical topics and progress tracking. Provider abstraction layers need to be implemented to support the modular architecture, along with extensive telemetry systems for observability and cost tracking. Session recording and transcript capabilities are planned, along with semantic search functionality for learning materials. Key learnings & principles Research revealed significant gaps between marketing claims and real-world performance in voice AI technologies, particularly with OpenAI's Realtime API showing measured latencies far exceeding advertised performance. AssemblyAI Universal-Streaming combined with Deepgram Aura-2 emerged as the most promising path for achieving sub-300ms latency targets. The "no mocks" testing philosophy is central to the development approach, emphasizing real service implementations and simple test doubles when necessary. Hybrid content generation strategy balances pre-generated detailed scripts with dynamic adaptation capabilities, supporting Socratic questioning as a core pedagogical feature. Cost scaling analysis showed 10-15x savings potential with custom stacks versus managed solutions at scale, informing the modular provider architecture design. Approach & patterns Development follows a comprehensive bootstrap approach with embedded installer scripts containing all project artifacts. The workflow emphasizes maintaining a functional app throughout development cycles, with extensive configuration options enabling experimentation across different technology combinations. The curriculum system uses modular content architecture where lectures can be pre-generated as detailed scripts while maintaining flexibility for dynamic adaptation and tangents. Progress tracking adapts by skipping or adding sections based on individual user needs. Testing strategy focuses on real implementations without mocking, supported by comprehensive CI/CD integration through GitHub Actions. Documentation standards require inline comments and multiple guide formats (README, QuickStart, detailed setup instructions). Tools & resources Primary development environment uses VS Code with potential Xcode integration for Claude Code compatibility. The project leverages XCTest framework, SwiftLint and SwiftFormat for code quality, and GitHub Actions for CI/CD. Technology stack research identified AssemblyAI Universal-Streaming for STT, Deepgram Aura-2 for TTS, and TEN VAD for speech detection. The system architecture supports iPhone 15 Pro+ hardware optimization with consideration for thermal limitations during sustained operation. Educational content integration targets OpenStax, MIT OpenCourseWare, and Wikipedia as primary knowledge sources, with semantic search capabilities for content discovery and navigation.

Last updated 1 month ago

Instructions
Add instructions to tailor Claude’s responses

Files
3% of project capacity used

UnaMentis_TDD.md
4,151 lines

md



IOS Voice APP Research: Claude Deep Research
593 lines

text



IOS Voice APP Research: ChatGPT
342 lines

text



UnaMentis_TDD.md
146.33 KB •4,151 lines
Formatting may be inconsistent from source
# Technical Design Document: UnaMentis iOS

**Real-Time Bidirectional Voice AI Platform for Extended Educational Conversations**

**Version:** 1.0  
**Date:** November 8, 2025  
**Target Platform:** iOS 18.0+ (iPhone 16/17 Pro Max optimized)  
**Primary Language:** Swift 6.0

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Core Components](#3-core-components)
4. [Curriculum Management System](#4-curriculum-management-system)
5. [Learning Materials Interface](#5-learning-materials-interface)
6. [Provider Abstraction Layer](#6-provider-abstraction-layer)
7. [Advanced Configuration System](#7-advanced-configuration-system)
8. [Telemetry & Observability](#8-telemetry--observability)
9. [Data Models](#9-data-models)
10. [UI/UX Design](#10-uiux-design)
11. [Implementation Roadmap](#11-implementation-roadmap)
12. [Testing Strategy](#12-testing-strategy)
13. [Performance Targets](#13-performance-targets)

---

## 1. Executive Summary

### 1.1 Project Goals

UnaMentis is an iOS application for extended (60-90+ minute) voice-based educational conversations with AI. The system enables:

- **Natural bidirectional voice interaction** with sub-500ms target latency
- **Curriculum-driven learning** with structured topics, outlines, and materials
- **Flexible experimentation platform** with extensive configuration options
- **Comprehensive observability** for performance tuning and cost optimization
- **Maximum provider flexibility** for comparing STT, TTS, and LLM services

### 1.2 Core Principles

1. **Modular Architecture:** Every component swappable via protocol abstractions
2. **Observability First:** All operations tracked, timed, and costed
3. **Configuration Driven:** Every behavior tunable through advanced settings
4. **Learning Focused:** Curriculum management as first-class feature
5. **Performance Optimized:** Target <500ms E2E with graceful degradation

### 1.3 Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **Language** | Swift 6.0 | Modern concurrency, type safety, Claude Code expertise |
| **UI Framework** | SwiftUI | Declarative, reactive, rapid iteration |
| **Audio** | AVFoundation | Native iOS audio with voice processing |
| **Transport** | LiveKit Swift SDK | WebRTC with semantic turn detection |
| **ML** | Core ML | On-device VAD using Neural Engine |
| **Persistence** | Core Data + FileManager | Structured data + document storage |
| **Networking** | URLSession (async/await) | Native, efficient, streaming support |

### 1.4 Key Differentiators

- **Curriculum-native:** Built for structured learning, not just chat
- **Experimental platform:** Extensive tuning for finding optimal configurations
- **Cost-transparent:** Real-time cost tracking and optimization
- **Provider-agnostic:** Easy A/B testing of services
- **Session-focused:** 90-minute stability as core requirement

---

## 2. System Architecture

### 2.1 High-Level Architecture

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                          SwiftUI Presentation Layer                    â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” â”‚
â”‚  â”‚  Session UI  â”‚  â”‚ Curriculum   â”‚  â”‚  Config UI   â”‚  â”‚ Analytics â”‚ â”‚
â”‚  â”‚  - Live      â”‚  â”‚  Navigator   â”‚  â”‚  - Advanced  â”‚  â”‚ Dashboard â”‚ â”‚
â”‚  â”‚  - Transcriptâ”‚  â”‚  - Topics    â”‚  â”‚  - Presets   â”‚  â”‚ - Metrics â”‚ â”‚
â”‚  â”‚  - Controls  â”‚  â”‚  - Materials â”‚  â”‚  - Tuning    â”‚  â”‚ - Costs   â”‚ â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜ â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                                    â”‚
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                        Core Application Layer                          â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”          â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” â”‚
â”‚  â”‚  SessionManager    â”‚          â”‚  CurriculumEngine                â”‚ â”‚
â”‚  â”‚  - Orchestration   â”‚â—„â”€â”€â”€â”€â”€â”€â”€â”€â–ºâ”‚  - Topic tracking                â”‚ â”‚
â”‚  â”‚  - Turn taking     â”‚          â”‚  - Material loading              â”‚ â”‚
â”‚  â”‚  - State machine   â”‚          â”‚  - Progress management           â”‚ â”‚
â”‚  â”‚  - Interruptions   â”‚          â”‚  - Context generation            â”‚ â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜          â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜ â”‚
â”‚             â”‚                                     â”‚                    â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”   â”‚
â”‚  â”‚                    TelemetryEngine                              â”‚   â”‚
â”‚  â”‚  - Latency tracking  - Cost calculation  - Performance metrics â”‚   â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜   â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                                    â”‚
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                    Provider Abstraction Layer                          â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â” â”‚
â”‚  â”‚   STT    â”‚  â”‚   TTS    â”‚  â”‚   LLM    â”‚  â”‚   VAD    â”‚  â”‚ Online â”‚ â”‚
â”‚  â”‚ Service  â”‚  â”‚ Service  â”‚  â”‚ Service  â”‚  â”‚ Service  â”‚  â”‚Resourceâ”‚ â”‚
â”‚  â”‚ Protocol â”‚  â”‚ Protocol â”‚  â”‚ Protocol â”‚  â”‚ Protocol â”‚  â”‚Fetcher â”‚ â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”˜ â”‚
â”‚       â”‚             â”‚             â”‚             â”‚             â”‚       â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” â”‚
â”‚  â”‚  Concrete Implementations:                                       â”‚ â”‚
â”‚  â”‚  - AssemblyAI, Deepgram, Apple (STT)                            â”‚ â”‚
â”‚  â”‚  - Deepgram Aura-2, ElevenLabs, Apple (TTS)                     â”‚ â”‚
â”‚  â”‚  - OpenAI, Anthropic, Local MLX (LLM)                           â”‚ â”‚
â”‚  â”‚  - Silero, TEN, WebRTC (VAD)                                    â”‚ â”‚
â”‚  â”‚  - OpenStax, MIT OCW, Wikipedia (Resources)                     â”‚ â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜ â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                                    â”‚
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                     Audio & Transport Layer                            â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”   â”‚
â”‚  â”‚  AudioEngine        â”‚              â”‚  LiveKitTransport        â”‚   â”‚
â”‚  â”‚  - AVAudioEngine    â”‚â—„â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–ºâ”‚  - WebRTC room           â”‚   â”‚
â”‚  â”‚  - Voice processing â”‚              â”‚  - Audio streaming       â”‚   â”‚
â”‚  â”‚  - VAD integration  â”‚              â”‚  - DataChannel messages  â”‚   â”‚
â”‚  â”‚  - Thermal mgmt     â”‚              â”‚  - Adaptive quality      â”‚   â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜   â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                                    â”‚
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                    Persistence & Storage Layer                         â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”‚
â”‚  â”‚  SessionStore   â”‚  â”‚  CurriculumStore â”‚  â”‚  ConfigManager     â”‚  â”‚
â”‚  â”‚  - Core Data    â”‚  â”‚  - Core Data     â”‚  â”‚  - User defaults   â”‚  â”‚
â”‚  â”‚  - Transcripts  â”‚  â”‚  - File storage  â”‚  â”‚  - Advanced tuning â”‚  â”‚
â”‚  â”‚  - Recordings   â”‚  â”‚  - Documents     â”‚  â”‚  - Presets         â”‚  â”‚
â”‚  â”‚  - Metrics      â”‚  â”‚  - Progress      â”‚  â”‚  - Provider keys   â”‚  â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

### 2.2 Data Flow: Typical Conversation Turn

```
1. User speaks
   â””â”€â–º AudioEngine captures PCM buffer
       â””â”€â–º Silero VAD (Neural Engine) detects speech
           â””â”€â–º SessionManager transitions to .userSpeaking
               â””â”€â–º LiveKit streams audio to server
                   â””â”€â–º AssemblyAI STT (WebSocket)
                       â””â”€â–º Partial transcripts stream back
                           â””â”€â–º TelemetryEngine logs STT latency
                               â””â”€â–º On final transcript:
                                   â””â”€â–º CurriculumEngine adds context
                                       â””â”€â–º OpenAI LLM (SSE stream)
                                           â””â”€â–º Tokens stream back
                                               â””â”€â–º Sentence boundary detected
                                                   â””â”€â–º Deepgram Aura-2 TTS
                                                       â””â”€â–º Audio chunks stream
                                                           â””â”€â–º AudioEngine plays
                                                               â””â”€â–º TelemetryEngine logs E2E latency
                                                                   â””â”€â–º SessionStore persists turn

Total latency budget: STT (307ms) + LLM (180ms) + TTS (150ms) = ~637ms
Target: <500ms with optimization
```

---

## 3. Core Components

### 3.1 AudioEngine (iOS Audio Pipeline)

**Purpose:** Manages all iOS audio I/O with voice optimization and on-device VAD.

**Key Responsibilities:**
- Configure AVAudioSession for voice chat
- Enable hardware AEC/AGC/NS via voice processing
- Capture audio and run on-device VAD (Silero on Neural Engine)
- Stream audio to transport layer
- Play TTS audio with interruption support
- Monitor thermal state for adaptive quality

**Configuration Parameters (All Exposed in Settings):**

```swift
struct AudioEngineConfig: Codable {
    // Core audio settings
    var sampleRate: Double = 48000           // 16000, 24000, 48000
    var channels: UInt32 = 1                 // Mono recommended
    var bitDepth: AVAudioBitDepth = .float32
    
    // Voice processing
    var enableVoiceProcessing: Bool = true
    var enableEchoCancellation: Bool = true
    var enableNoiseSupression: Bool = true
    var enableAutomaticGainControl: Bool = true
    
    // VAD settings
    var vadProvider: VADProvider = .silero
    var vadThreshold: Float = 0.5            // 0.0 - 1.0
    var vadContextWindow: Int = 3            // frames
    var vadSmoothingWindow: Int = 5          // frames
    
    // Interruption handling
    var enableBargein: Bool = true
    var bargeInThreshold: Float = 0.7        // VAD confidence for interrupt
    var ttsClearOnInterrupt: Bool = true
    
    // Performance tuning
    var bufferSize: AVAudioFrameCount = 1024 // 256, 512, 1024, 2048
    var enableAdaptiveQuality: Bool = true
    var thermalThrottleThreshold: ProcessInfo.ThermalState = .serious
    
    // Monitoring
    var enableAudioLevelMonitoring: Bool = true
    var levelUpdateInterval: TimeInterval = 0.1
}
```

**Implementation:**

```swift
import AVFoundation
import CoreML

actor AudioEngine: ObservableObject {
    // MARK: - Properties
    
    private let engine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    private var vadService: VADService
    private let telemetry: TelemetryEngine
    
    private(set) var config: AudioEngineConfig
    private var isRunning = false
    
    // Publishers for audio data
    private let audioStreamSubject = PassthroughSubject<(AVAudioPCMBuffer, VADResult), Never>()
    var audioStream: AnyPublisher<(AVAudioPCMBuffer, VADResult), Never> {
        audioStreamSubject.eraseToAnyPublisher()
    }
    
    // Thermal monitoring
    private var thermalStateObserver: NSObjectProtocol?
    @Published private(set) var currentThermalState: ProcessInfo.ThermalState = .nominal
    
    // MARK: - Initialization
    
    init(config: AudioEngineConfig, vadService: VADService, telemetry: TelemetryEngine) {
        self.config = config
        self.vadService = vadService
        self.telemetry = telemetry
        
        setupThermalMonitoring()
    }
    
    // MARK: - Configuration
    
    func configure(config: AudioEngineConfig) async throws {
        self.config = config
        
        // Audio session configuration
        try session.setCategory(.playAndRecord, 
                                mode: .voiceChat,
                                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        try session.setPreferredSampleRate(config.sampleRate)
        try session.setPreferredIOBufferDuration(Double(config.bufferSize) / config.sampleRate)
        try session.setActive(true)
        
        // Voice processing configuration
        let inputNode = engine.inputNode
        if config.enableVoiceProcessing {
            try inputNode.setVoiceProcessingEnabled(true)
        }
        
        // Audio format
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: config.sampleRate,
            channels: config.channels,
            interleaved: false
        )!
        
        // Install tap with explicit format (prevents leaks)
        inputNode.removeTap(onBus: 0) // Remove existing tap if any
        inputNode.installTap(onBus: 0, bufferSize: config.bufferSize, format: format) { 
            [weak self] buffer, time in
            Task {
                await self?.processAudioBuffer(buffer, time: time)
            }
        }
        
        // VAD configuration
        await vadService.configure(
            threshold: config.vadThreshold,
            contextWindow: config.vadContextWindow
        )
        
        engine.prepare()
        
        telemetry.recordEvent(.audioEngineConfigured(config))
    }
    
    // MARK: - Lifecycle
    
    func start() async throws {
        guard !isRunning else { return }
        
        try engine.start()
        isRunning = true
        
        telemetry.recordEvent(.audioEngineStarted)
    }
    
    func stop() async {
        guard isRunning else { return }
        
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        isRunning = false
        
        telemetry.recordEvent(.audioEngineStopped)
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) async {
        let startTime = Date()
        
        // Check thermal state
        if config.enableAdaptiveQuality {
            await checkAndAdaptToThermalState()
        }
        
        // Run VAD (on Neural Engine if using Silero)
        let vadResult = await vadService.processBuffer(buffer)
        
        // Emit to transport layer
        audioStreamSubject.send((buffer, vadResult))
        
        // Telemetry
        let processingTime = Date().timeIntervalSince(startTime)
        telemetry.recordLatency(.audioProcessing, processingTime)
        
        if config.enableAudioLevelMonitoring {
            let level = calculateAudioLevel(buffer)
            telemetry.recordAudioLevel(level)
        }
    }
    
    // MARK: - Playback
    
    func playAudio(_ chunk: TTSAudioChunk) async throws {
        // Convert chunk to AVAudioPCMBuffer
        let buffer = try chunk.toAVAudioPCMBuffer()
        
        // Schedule on player node
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)
        
        playerNode.scheduleBuffer(buffer) {
            Task {
                await self.telemetry.recordEvent(.audioChunkPlayed)
            }
        }
        
        playerNode.play()
    }
    
    func stopPlayback() async {
        // Stop all player nodes
        for node in engine.attachedNodes {
            if let playerNode = node as? AVAudioPlayerNode {
                playerNode.stop()
            }
        }
        
        telemetry.recordEvent(.audioPlaybackStopped)
    }
    
    // MARK: - Thermal Management
    
    private func setupThermalMonitoring() {
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleThermalStateChange()
            }
        }
    }
    
    private func handleThermalStateChange() async {
        currentThermalState = ProcessInfo.processInfo.thermalState
        telemetry.recordEvent(.thermalStateChanged(currentThermalState))
    }
    
    private func checkAndAdaptToThermalState() async {
        guard currentThermalState >= config.thermalThrottleThreshold else { return }
        
        // Adaptive quality degradation
        var adaptedConfig = config
        
        switch currentThermalState {
        case .serious:
            adaptedConfig.sampleRate = 24000 // Reduce from 48kHz
            adaptedConfig.bufferSize = 2048   // Increase buffer
        case .critical:
            adaptedConfig.sampleRate = 16000 // Further reduce
            adaptedConfig.bufferSize = 4096
        default:
            return
        }
        
        telemetry.recordEvent(.adaptiveQualityEngaged(from: config, to: adaptedConfig))
        
        try? await configure(config: adaptedConfig)
    }
    
    // MARK: - Utilities
    
    private func calculateAudioLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        return sum / Float(frameLength)
    }
}
```

### 3.2 SessionManager (Orchestration)

**Purpose:** Orchestrates the conversation flow, manages state machine, coordinates all services.

**State Machine:**

```
         â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”
         â”‚  IDLE  â”‚
         â””â”€â”€â”€â”¬â”€â”€â”€â”€â”˜
             â”‚ VAD detects speech
             â–¼
      â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
      â”‚USER_SPEAKING â”‚â—„â”€â”€â”€â”€â”€â”
      â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”˜      â”‚
             â”‚ End of turn  â”‚ User continues
             â–¼              â”‚
   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”    â”‚
   â”‚PROCESSING_USER   â”‚    â”‚
   â”‚  - Add context   â”‚    â”‚
   â”‚  - Query LLM     â”‚    â”‚
   â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜    â”‚
          â”‚                â”‚
          â–¼                â”‚
   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”        â”‚
   â”‚ AI_THINKING  â”‚        â”‚
   â”‚ (LLM tokens) â”‚        â”‚
   â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”˜        â”‚
          â”‚ First sentence â”‚
          â–¼                â”‚
   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”        â”‚
   â”‚ AI_SPEAKING  â”‚â”€â”€â”€â”€â”€â”€â”€â”€â”˜ User interrupts
   â”‚  (TTS play)  â”‚
   â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”˜
          â”‚ Turn complete
          â–¼
       â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”
       â”‚  IDLE  â”‚
       â””â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

**Configuration Parameters:**

```swift
struct SessionConfig: Codable {
    // Core settings
    var sessionDuration: TimeInterval = 5400 // 90 minutes default
    var enableAutoSave: Bool = true
    var autoSaveInterval: TimeInterval = 300 // 5 minutes
    
    // Turn taking
    var enableSemanticTurnDetection: Bool = true
    var silenceThresholdMs: Int = 700        // ms before considering turn over
    var minTurnDuration: TimeInterval = 0.5  // Ignore very short utterances
    var maxTurnDuration: TimeInterval = 120  // Force turn end after 2 min
    
    // Interruption
    var enableInterruptions: Bool = true
    var interruptionVADThreshold: Float = 0.7
    var interruptionCooldown: TimeInterval = 0.5 // Prevent rapid interrupts
    
    // TTS streaming
    var sentenceBreakThreshold: Int = 1      // Sentences before TTS flush
    var enableEagerTTS: Bool = true          // Start TTS on partial sentence
    var ttsChunkingStrategy: TTSChunkStrategy = .sentenceBoundary
    
    // Context management
    var maxContextTokens: Int = 8000
    var enableContextCompression: Bool = true
    var keepRecentTurns: Int = 10            // Always keep last N turns
    
    // Recording
    var enableRecording: Bool = false
    var recordingFormat: RecordingFormat = .m4a
    var recordingQuality: AVAudioQuality = .high
    
    // Curriculum integration
    var enableCurriculumContext: Bool = true
    var maxCurriculumContextTokens: Int = 2000
}

enum TTSChunkStrategy: String, Codable {
    case sentenceBoundary  // Wait for . ! ?
    case clauseBoundary    // Also break on , ; :
    case fixedTokens       // Every N tokens
}

enum RecordingFormat: String, Codable {
    case m4a, wav, opus
}
```

**Implementation:**

```swift
import Combine

actor SessionManager: ObservableObject {
    // MARK: - State
    
    enum SessionState: Equatable {
        case idle
        case userSpeaking
        case processingUserUtterance
        case aiThinking
        case aiSpeaking
        case interrupted
        case paused
        case ended
    }
    
    @Published private(set) var state: SessionState = .idle
    @Published private(set) var currentSession: Session?
    
    // MARK: - Dependencies
    
    private let audioEngine: AudioEngine
    private var sttService: STTService
    private var ttsService: TTSService
    private var llmService: LLMService
    private let curriculumEngine: CurriculumEngine
    private let telemetry: TelemetryEngine
    private let sessionStore: SessionStore
    
    private var config: SessionConfig
    
    // MARK: - Session State
    
    private var currentUserTranscript = ""
    private var conversationHistory: [LLMMessage] = []
    private var activeTopic: Topic?
    
    private var sessionStartTime: Date?
    private var lastUserSpeechTime: Date?
    private var lastInterruptionTime: Date?
    
    // MARK: - Cancellables
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        audioEngine: AudioEngine,
        sttService: STTService,
        ttsService: TTSService,
        llmService: LLMService,
        curriculumEngine: CurriculumEngine,
        telemetry: TelemetryEngine,
        sessionStore: SessionStore,
        config: SessionConfig
    ) {
        self.audioEngine = audioEngine
        self.sttService = sttService
        self.ttsService = ttsService
        self.llmService = llmService
        self.curriculumEngine = curriculumEngine
        self.telemetry = telemetry
        self.sessionStore = sessionStore
        self.config = config
    }
    
    // MARK: - Session Control
    
    func startSession(topic: Topic?) async throws {
        guard state == .idle else {
            throw SessionError.alreadyActive
        }
        
        sessionStartTime = Date()
        activeTopic = topic
        
        // Initialize conversation with curriculum context
        if config.enableCurriculumContext, let topic = topic {
            let context = await curriculumEngine.generateContext(for: topic)
            conversationHistory.append(
                LLMMessage(role: .system, content: context)
            )
        }
        
        // Create session record
        currentSession = Session(
            id: UUID(),
            startTime: Date(),
            topic: topic?.title
        )
        
        // Start audio engine
        try await audioEngine.start()
        
        // Subscribe to audio stream
        subscribeToAudioStream()
        
        state = .idle
        telemetry.recordEvent(.sessionStarted(topic: topic?.title))
    }
    
    func pauseSession() async {
        guard state != .paused && state != .ended else { return }
        
        let previousState = state
        state = .paused
        
        await audioEngine.stop()
        
        telemetry.recordEvent(.sessionPaused(previousState: previousState))
    }
    
    func resumeSession() async throws {
        guard state == .paused else { return }
        
        try await audioEngine.start()
        state = .idle
        
        telemetry.recordEvent(.sessionResumed)
    }
    
    func endSession() async throws {
        guard state != .ended else { return }
        
        state = .ended
        
        // Stop all services
        await audioEngine.stop()
        try await sttService.stopStreaming()
        try await ttsService.flush()
        
        // Save session
        if let session = currentSession {
            session.endTime = Date()
            session.duration = Date().timeIntervalSince(session.startTime)
            session.transcriptData = try JSONEncoder().encode(conversationHistory)
            session.metricsData = try JSONEncoder().encode(telemetry.currentMetrics)
            
            try await sessionStore.saveSession(session)
        }
        
        telemetry.recordEvent(.sessionEnded)
        
        // Export metrics
        let export = await telemetry.exportSession()
        print("Session export: \(export)")
    }
    
    // MARK: - Audio Stream Processing
    
    private func subscribeToAudioStream() {
        audioEngine.audioStream
            .sink { [weak self] buffer, vadResult in
                Task {
                    await self?.handleAudioFrame(buffer, vadResult)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAudioFrame(
        _ buffer: AVAudioPCMBuffer,
        _ vadResult: VADResult
    ) async {
        switch state {
        case .idle, .aiSpeaking:
            if vadResult.isSpeech && vadResult.confidence >= config.interruptionVADThreshold {
                await handleUserStartedSpeaking()
            }
            
        case .userSpeaking:
            // Send to STT
            do {
                try await sttService.sendAudio(buffer)
            } catch {
                telemetry.recordError(.sttSendFailed(error))
            }
            
        case .processingUserUtterance, .aiThinking:
            // Ignore audio during processing
            break
            
        case .paused, .ended:
            break
            
        case .interrupted:
            // Already handling interruption
            break
        }
    }
    
    // MARK: - Turn Taking Logic
    
    private func handleUserStartedSpeaking() async {
        let previousState = state
        
        // Check interruption cooldown
        if config.enableInterruptions,
           let lastInterrupt = lastInterruptionTime,
           Date().timeIntervalSince(lastInterrupt) < config.interruptionCooldown {
            return
        }
        
        state = .userSpeaking
        lastUserSpeechTime = Date()
        
        telemetry.recordEvent(.userStartedSpeaking)
        
        // If AI was speaking, interrupt
        if previousState == .aiSpeaking {
            await handleInterruption()
        }
        
        // Start STT streaming
        Task {
            do {
                let sttStream = try await sttService.startStreaming(
                    audioFormat: await audioEngine.format
                )
                
                for await result in sttStream {
                    await handleSTTResult(result)
                }
            } catch {
                telemetry.recordError(.sttStreamFailed(error))
            }
        }
    }
    
    private func handleSTTResult(_ result: STTResult) async {
        currentUserTranscript = result.transcript
        
        telemetry.recordLatency(.sttEmission, result.latency)
        telemetry.recordEvent(.sttPartialReceived(
            transcript: result.transcript,
            isFinal: result.isFinal
        ))
        
        // Update UI with partial transcript
        await MainActor.run {
            // Publish to UI
        }
        
        if result.isEndOfUtterance || result.isFinal {
            await processUserUtterance(result.transcript)
        }
    }
    
    private func processUserUtterance(_ transcript: String) async {
        state = .processingUserUtterance
        
        let turnStartTime = Date()
        
        telemetry.recordEvent(.userFinishedSpeaking(transcript: transcript))
        
        // Stop STT
        try? await sttService.stopStreaming()
        
        // Add to conversation history
        conversationHistory.append(
            LLMMessage(role: .user, content: transcript)
        )
        
        // Manage context window
        if config.enableContextCompression {
            await compressContextIfNeeded()
        }
        
        // Generate curriculum context if enabled
        var messages = conversationHistory
        if config.enableCurriculumContext, let topic = activeTopic {
            let curriculumContext = await curriculumEngine.generateContextForQuery(
                query: transcript,
                topic: topic,
                maxTokens: config.maxCurriculumContextTokens
            )
            
            if !curriculumContext.isEmpty {
                // Insert curriculum context before user message
                messages.insert(
                    LLMMessage(role: .system, content: curriculumContext),
                    at: messages.count - 1
                )
            }
        }
        
        state = .aiThinking
        
        // Stream LLM response
        await streamLLMResponse(messages: messages, turnStartTime: turnStartTime)
    }
    
    private func streamLLMResponse(messages: [LLMMessage], turnStartTime: Date) async {
        do {
            let llmStream = try await llmService.streamCompletion(
                messages: messages,
                config: config.llmConfig
            )
            
            var fullResponse = ""
            var currentChunk = ""
            var sentenceCount = 0
            var firstTokenReceived = false
            
            for await token in llmStream {
                if !firstTokenReceived {
                    let latency = Date().timeIntervalSince(turnStartTime)
                    telemetry.recordLatency(.llmFirstToken, latency)
                    firstTokenReceived = true
                }
                
                fullResponse += token.content
                currentChunk += token.content
                
                // Check for sentence boundary
                if shouldSynthesizeChunk(currentChunk, strategy: config.ttsChunkingStrategy) {
                    sentenceCount += 1
                    
                    await synthesizeChunk(currentChunk)
                    currentChunk = ""
                    
                    // Periodic flush based on config
                    if sentenceCount >= config.sentenceBreakThreshold {
                        // Optional: flush TTS buffer for lower latency
                    }
                }
                
                if token.isDone {
                    // Synthesize remaining text
                    if !currentChunk.isEmpty {
                        await synthesizeChunk(currentChunk)
                    }
                    
                    // Add to conversation history
                    conversationHistory.append(
                        LLMMessage(role: .assistant, content: fullResponse)
                    )
                    
                    // Record full turn latency
                    let totalLatency = Date().timeIntervalSince(turnStartTime)
                    telemetry.recordLatency(.endToEndTurn, totalLatency)
                    
                    // Return to idle
                    state = .idle
                }
            }
            
        } catch {
            telemetry.recordError(.llmStreamFailed(error))
            state = .idle
        }
    }
    
    private func synthesizeChunk(_ text: String) async {
        if state != .aiSpeaking {
            state = .aiSpeaking
            telemetry.recordEvent(.aiStartedSpeaking)
        }
        
        let ttsStartTime = Date()
        
        do {
            let ttsStream = try await ttsService.synthesize(text: text)
            
            for await audioChunk in ttsStream {
                // Record TTFB
                if audioChunk.isFirst, let ttfb = audioChunk.timeToFirstByte {
                    telemetry.recordLatency(.ttsTTFB, ttfb)
                }
                
                // Play audio
                try await audioEngine.playAudio(audioChunk)
                
                // Check for interruption
                if state == .interrupted {
                    try await ttsService.flush()
                    break
                }
            }
            
            telemetry.recordEvent(.ttsChunkCompleted(
                text: text,
                duration: Date().timeIntervalSince(ttsStartTime)
            ))
            
        } catch {
            telemetry.recordError(.ttsStreamFailed(error))
        }
    }
    
    private func handleInterruption() async {
        guard config.enableInterruptions else { return }
        
        state = .interrupted
        lastInterruptionTime = Date()
        
        telemetry.recordEvent(.userInterrupted)
        
        // Flush TTS buffer
        if config.ttsClearOnInterrupt {
            try? await ttsService.flush()
        }
        
        // Stop audio playback
        await audioEngine.stopPlayback()
        
        // Transition to user speaking
        state = .userSpeaking
    }
    
    // MARK: - Context Management
    
    private func compressContextIfNeeded() async {
        // Estimate token count (rough approximation)
        let estimatedTokens = conversationHistory.reduce(0) { $0 + ($1.content.count / 4) }
        
        guard estimatedTokens > config.maxContextTokens else { return }
        
        // Keep system message and recent turns
        let systemMessages = conversationHistory.filter { $0.role == .system }
        let recentTurns = Array(conversationHistory.suffix(config.keepRecentTurns * 2))
        
        conversationHistory = systemMessages + recentTurns
        
        telemetry.recordEvent(.contextCompressed(
            from: estimatedTokens,
            to: conversationHistory.reduce(0) { $0 + ($1.content.count / 4) }
        ))
    }
    
    // MARK: - Utilities
    
    private func shouldSynthesizeChunk(_ text: String, strategy: TTSChunkStrategy) -> Bool {
        switch strategy {
        case .sentenceBoundary:
            return text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?")
        case .clauseBoundary:
            return text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?") ||
                   text.hasSuffix(",") || text.hasSuffix(";") || text.hasSuffix(":")
        case .fixedTokens:
            return text.split(separator: " ").count >= 20
        }
    }
}

enum SessionError: Error {
    case alreadyActive
    case notStarted
    case configurationError(String)
}
```

---

### 3.3 Todo System (Task Management)

**Purpose:** Central hub for tracking learning goals, progress, and resuming interrupted sessions.

**Key Responsibilities:**
- Manage user-defined learning targets and curriculum items
- Capture reinforcement requests during voice sessions via LLM tool calls
- Auto-create resume items when sessions are stopped mid-curriculum
- Suggest matching curricula for learning targets
- Handle drag-and-drop prioritization and archival

**Core Data Entity: TodoItem**

```swift
@objc(TodoItem)
class TodoItem: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var notes: String?
    @NSManaged var typeRaw: String           // curriculum, module, topic, learning_target, reinforcement, auto_resume
    @NSManaged var statusRaw: String         // pending, in_progress, completed, archived
    @NSManaged var priority: Int32           // For drag-drop ordering (lower = higher priority)
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var archivedAt: Date?

    // Curriculum references
    @NSManaged var curriculumId: UUID?
    @NSManaged var topicId: UUID?
    @NSManaged var granularity: String?      // curriculum, module, topic

    // Auto-resume context
    @NSManaged var resumeTopicId: UUID?
    @NSManaged var resumeSegmentIndex: Int32
    @NSManaged var resumeConversationContext: Data?  // JSON encoded last 10 messages

    // Learning target suggestions
    @NSManaged var suggestedCurriculumIds: [String]?

    // Source tracking
    @NSManaged var sourceRaw: String         // manual, voice, auto_resume, reinforcement
    @NSManaged var sourceSessionId: UUID?
}
```

**Business Logic Actors:**

```swift
// TodoManager - CRUD operations for todo items
actor TodoManager {
    func createItem(title: String, type: TodoItemType, source: TodoItemSource, notes: String?) throws -> TodoItem
    func createAutoResumeItem(title: String, topicId: UUID, segmentIndex: Int32, conversationContext: Data) throws -> TodoItem
    func createReinforcementItem(title: String, notes: String?, sessionId: UUID?) throws -> TodoItem
    func updatePriorities(_ items: [TodoItem]) throws
    func markCompleted(_ item: TodoItem) throws
    func archive(_ item: TodoItem) throws
}

// AutoResumeService - Detects and creates auto-resume items
actor AutoResumeService {
    func handleSessionStop(context: AutoResumeContext) async -> Bool
    func getConversationContext(for topicId: UUID) async -> [ResumeConversationMessage]?
    func getResumeSegmentIndex(for topicId: UUID) async -> Int32?
    func clearAutoResume(for topicId: UUID) async
}

// CurriculumSuggestionService - Suggests curricula for learning targets
actor CurriculumSuggestionService {
    func fetchSuggestions(for query: String) async throws -> [String]
    func updateTodoWithSuggestions(_ todoItem: TodoItem) async
}
```

**LLM Tool Call Infrastructure:**

The Todo system integrates with LLM responses via tool/function calling, enabling voice-triggered todo creation.

```swift
// Tool definitions sent to LLM
struct TodoTools {
    static let addTodo = LLMToolDefinition(
        name: "add_todo",
        description: "Add a new item to the user's to-do list for later study",
        inputSchema: ToolInputSchema(
            properties: [
                "title": ToolProperty(type: "string", description: "Brief title of the learning item"),
                "type": ToolProperty(type: "string", enum: ["learning_target", "reinforcement"]),
                "notes": ToolProperty(type: "string", description: "Additional context")
            ],
            required: ["title", "type"]
        )
    )

    static let markForReview = LLMToolDefinition(
        name: "mark_for_review",
        description: "Mark the current topic for future review",
        inputSchema: ToolInputSchema(
            properties: [
                "reason": ToolProperty(type: "string", description: "Why this needs review")
            ],
            required: []
        )
    )
}

// ToolCallProcessor - Routes tool calls to handlers
actor ToolCallProcessor {
    func process(_ toolCall: LLMToolCall) async -> LLMToolResult
    func processAll(_ toolCalls: [LLMToolCall]) async -> [LLMToolResult]
}

// TodoToolHandler - Handles todo-related tool calls
actor TodoToolHandler: ToolHandler {
    func handle(_ toolCall: LLMToolCall) async throws -> LLMToolResult
}
```

**Auto-Resume Detection Logic:**

When a session is stopped, the system evaluates whether to create an auto-resume item:

1. Session is a curriculum session (has topic reference)
2. Session lasted at least 2 minutes
3. Progress was made (segmentIndex > 0)
4. Topic is not completed (segmentIndex < totalSegments - 1)

If all conditions are met, an auto-resume TodoItem is created with:
- Topic reference and title
- Segment index for resumption point
- Last 10 conversation messages (JSON encoded) for context

**UI Components:**

- `TodoListView` - Main list with drag-and-drop reordering
- `TodoItemRow` - Individual item display with swipe actions
- `TodoItemDetailView` - Detail view with editing
- `AddTodoSheet` - Create new items with curriculum suggestions
- `TodoHelpSheet` - In-app help documentation

---

## 4. Curriculum Management System

### 4.1 Overview

The curriculum system is a first-class component that manages learning materials, topics, progress tracking, and context generation for LLM prompts.

### 4.2 Data Model

```swift
// MARK: - Core Entities

@objc(Curriculum)
class Curriculum: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var descriptionText: String?
    @NSManaged var source: String? // "user", "openstax", "mit_ocw", etc.
    @NSManaged var sourceURL: URL?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    
    @NSManaged var topics: NSSet? // Relationship to Topic
    @NSManaged var documents: NSSet? // Relationship to Document
}

@objc(Topic)
class Topic: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var descriptionText: String?
    @NSManaged var order: Int32
    @NSManaged var estimatedDuration: TimeInterval // minutes
    
    // Hierarchical structure
    @NSManaged var parentTopic: Topic?
    @NSManaged var subTopics: NSSet? // Relationship to Topic
    
    // Content
    @NSManaged var outlineText: String? // Markdown outline
    @NSManaged var referenceDocuments: NSSet? // Relationship to Document
    @NSManaged var keyPoints: [String]? // JSON array
    @NSManaged var learningObjectives: [String]? // JSON array
    
    // Progress tracking
    @NSManaged var progress: TopicProgress?
    @NSManaged var sessions: NSSet? // Relationship to Session
    
    // Relationships
    @NSManaged var curriculum: Curriculum
}

@objc(Document)
class Document: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var type: String // "pdf", "text", "markdown", "transcript"
    @NSManaged var fileURL: URL
    @NSManaged var uploadedAt: Date
    
    // Content
    @NSManaged var extractedText: String? // Full text extraction
    @NSManaged var summary: String? // LLM-generated summary
    @NSManaged var embeddings: Data? // Vector embeddings for semantic search
    
    // Metadata
    @NSManaged var pageCount: Int32
    @NSManaged var wordCount: Int32
    @NSManaged var language: String?
    
    // Relationships
    @NSManaged var topics: NSSet?
    @NSManaged var curriculum: Curriculum?
}

@objc(TopicProgress)
class TopicProgress: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var topic: Topic
    
    @NSManaged var status: String // "not_started", "in_progress", "completed"
    @NSManaged var startedAt: Date?
    @NSManaged var completedAt: Date?
    @NSManaged var totalTimeSpent: TimeInterval
    
    @NSManaged var masteryLevel: Float // 0.0 - 1.0
    @NSManaged var questionsAsked: Int32
    @NSManaged var conceptsCovered: [String]? // JSON array
    
    @NSManaged var notes: String? // User notes
}

// MARK: - Supporting Types

enum TopicStatus: String, Codable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed = "completed"
    case reviewing = "reviewing"
}

struct LearningObjective: Codable {
    let id: UUID
    let description: String
    let isMet: Bool
    let evidence: [String]? // Session transcripts where objective was addressed
}
```

### 4.3 CurriculumEngine

**Purpose:** Manages curriculum state, generates LLM context from materials, tracks progress.

```swift
actor CurriculumEngine: ObservableObject {
    // MARK: - Properties
    
    private let curriculumStore: CurriculumStore
    private let telemetry: TelemetryEngine
    private let embeddingService: EmbeddingService?
    
    @Published private(set) var activeCurriculum: Curriculum?
    @Published private(set) var currentTopic: Topic?
    
    // MARK: - Context Generation
    
    /// Generates system context for LLM based on topic and materials
    func generateContext(for topic: Topic) async -> String {
        var context = """
        You are an expert tutor conducting an extended voice-based educational session.
        
        CURRENT TOPIC: \(topic.title)
        """
        
        if let description = topic.descriptionText {
            context += "\n\nTOPIC DESCRIPTION:\n\(description)"
        }
        
        if let objectives = topic.learningObjectives, !objectives.isEmpty {
            context += "\n\nLEARNING OBJECTIVES:\n"
            objectives.forEach { context += "- \($0)\n" }
        }
        
        if let outline = topic.outlineText {
            context += "\n\nTOPIC OUTLINE:\n\(outline)"
        }
        
        // Add reference material excerpts
        if let documents = topic.referenceDocuments as? Set<Document> {
            for document in documents.prefix(3) { // Limit context
                if let summary = document.summary {
                    context += "\n\nREFERENCE: \(document.title)\n\(summary)"
                }
            }
        }
        
        context += """
        
        
        TEACHING APPROACH:
        - Use Socratic questioning to guide learning
        - Encourage critical thinking and exploration
        - Adapt explanations to student's demonstrated understanding
        - Use concrete examples and analogies
        - Check for understanding regularly
        - This is a voice conversation, so be conversational and natural
        - Keep individual responses concise but comprehensive
        - Be prepared for interruptions and clarification questions
        """
        
        return context
    }
    
    /// Generates dynamic context for a specific user query within a topic
    func generateContextForQuery(
        query: String,
        topic: Topic,
        maxTokens: Int = 2000
    ) async -> String {
        // If embeddings available, do semantic search
        if let embeddingService = embeddingService,
           let documents = topic.referenceDocuments as? Set<Document> {
            
            let relevantChunks = await semanticSearchDocuments(
                query: query,
                documents: Array(documents),
                maxTokens: maxTokens
            )
            
            if !relevantChunks.isEmpty {
                var context = "RELEVANT REFERENCE MATERIAL:\n\n"
                relevantChunks.forEach { chunk in
                    context += "\(chunk.text)\n\n"
                }
                return context
            }
        }
        
        // Fallback: keyword matching in outlines/summaries
        return ""
    }
    
    /// Semantic search across documents using embeddings
    private func semanticSearchDocuments(
        query: String,
        documents: [Document],
        maxTokens: Int
    ) async -> [DocumentChunk] {
        guard let embeddingService = embeddingService else { return [] }
        
        // Generate query embedding
        let queryEmbedding = await embeddingService.embed(text: query)
        
        // Compare with document embeddings
        var rankedChunks: [(chunk: DocumentChunk, similarity: Float)] = []
        
        for document in documents {
            guard let embeddingsData = document.embeddings,
                  let chunks = try? JSONDecoder().decode([DocumentChunk].self, from: embeddingsData) else {
                continue
            }
            
            for chunk in chunks {
                let similarity = cosineSimilarity(queryEmbedding, chunk.embedding)
                rankedChunks.append((chunk, similarity))
            }
        }
        
        // Sort by similarity and take top chunks within token budget
        rankedChunks.sort { $0.similarity > $1.similarity }
        
        var selectedChunks: [DocumentChunk] = []
        var tokenCount = 0
        
        for (chunk, _) in rankedChunks {
            let chunkTokens = chunk.text.count / 4 // Rough estimate
            if tokenCount + chunkTokens <= maxTokens {
                selectedChunks.append(chunk)
                tokenCount += chunkTokens
            } else {
                break
            }
        }
        
        return selectedChunks
    }
    
    // MARK: - Progress Tracking
    
    func startTopic(_ topic: Topic) async throws {
        guard let progress = topic.progress else {
            // Create new progress
            let progress = TopicProgress(context: curriculumStore.viewContext)
            progress.id = UUID()
            progress.topic = topic
            progress.status = TopicStatus.inProgress.rawValue
            progress.startedAt = Date()
            progress.totalTimeSpent = 0
            progress.masteryLevel = 0
            
            try curriculumStore.save()
            return
        }
        
        progress.status = TopicStatus.inProgress.rawValue
        if progress.startedAt == nil {
            progress.startedAt = Date()
        }
        
        try curriculumStore.save()
        
        currentTopic = topic
        telemetry.recordEvent(.topicStarted(topic: topic.title))
    }
    
    func updateProgress(
        topic: Topic,
        timeSpent: TimeInterval,
        conceptsCovered: [String]
    ) async throws {
        guard let progress = topic.progress else { return }
        
        progress.totalTimeSpent += timeSpent
        
        var existingConcepts = progress.conceptsCovered ?? []
        existingConcepts.append(contentsOf: conceptsCovered)
        progress.conceptsCovered = Array(Set(existingConcepts)) // Deduplicate
        
        try curriculumStore.save()
    }
    
    func completeTopic(_ topic: Topic, masteryLevel: Float = 0.8) async throws {
        guard let progress = topic.progress else { return }
        
        progress.status = TopicStatus.completed.rawValue
        progress.completedAt = Date()
        progress.masteryLevel = masteryLevel
        
        try curriculumStore.save()
        
        telemetry.recordEvent(.topicCompleted(
            topic: topic.title,
            timeSpent: progress.totalTimeSpent,
            mastery: masteryLevel
        ))
    }
}

// MARK: - Supporting Types

struct DocumentChunk: Codable {
    let id: UUID
    let documentId: UUID
    let text: String
    let embedding: [Float]
    let pageNumber: Int?
    let chunkIndex: Int
}

// Cosine similarity helper
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count else { return 0 }
    
    let dotProduct = zip(a, b).reduce(0) { $0 + ($1.0 * $1.1) }
    let magnitudeA = sqrt(a.reduce(0) { $0 + ($1 * $1) })
    let magnitudeB = sqrt(b.reduce(0) { $0 + ($1 * $1) })
    
    return dotProduct / (magnitudeA * magnitudeB)
}
```

### 4.4 Document Processing

**Purpose:** Extract text, generate summaries, create embeddings for semantic search.

```swift
actor DocumentProcessor {
    private let llmService: LLMService
    private let embeddingService: EmbeddingService
    
    func processDocument(_ document: Document) async throws {
        // Extract text based on type
        let extractedText = try await extractText(from: document)
        document.extractedText = extractedText
        
        // Generate summary
        let summary = try await generateSummary(text: extractedText)
        document.summary = summary
        
        // Create embeddings for semantic search
        let chunks = chunkText(extractedText, maxChunkSize: 500)
        let embeddedChunks = try await createEmbeddings(chunks: chunks, documentId: document.id)
        document.embeddings = try JSONEncoder().encode(embeddedChunks)
        
        // Update metadata
        document.wordCount = Int32(extractedText.split(separator: " ").count)
    }
    
    private func extractText(from document: Document) async throws -> String {
        switch document.type {
        case "pdf":
            return try await extractPDFText(url: document.fileURL)
        case "text", "markdown":
            return try String(contentsOf: document.fileURL, encoding: .utf8)
        case "transcript":
            // Parse transcript JSON
            let data = try Data(contentsOf: document.fileURL)
            let transcript = try JSONDecoder().decode([Turn].self, from: data)
            return transcript.map { "\($0.speaker): \($0.transcript)" }.joined(separator: "\n")
        default:
            throw DocumentError.unsupportedType
        }
    }
    
    private func extractPDFText(url: URL) async throws -> String {
        // Use PDFKit to extract text
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.pdfLoadFailed
        }
        
        var text = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex),
                  let pageText = page.string else {
                continue
            }
            text += pageText + "\n\n"
        }
        
        return text
    }
    
    private func generateSummary(text: String) async throws -> String {
        let prompt = """
        Summarize the following educational material in 3-5 paragraphs. Focus on:
        - Main concepts and topics covered
        - Key learning points
        - Important examples or case studies
        
        Material:
        \(text.prefix(8000))
        """
        
        let messages = [LLMMessage(role: .user, content: prompt)]
        let stream = try await llmService.streamCompletion(messages: messages, config: .default)
        
        var summary = ""
        for await token in stream {
            summary += token.content
        }
        
        return summary
    }
    
    private func chunkText(_ text: String, maxChunkSize: Int) -> [(text: String, index: Int)] {
        let words = text.split(separator: " ")
        var chunks: [(String, Int)] = []
        var currentChunk: [Substring] = []
        var chunkIndex = 0
        
        for word in words {
            currentChunk.append(word)
            
            if currentChunk.joined(separator: " ").count >= maxChunkSize {
                chunks.append((currentChunk.joined(separator: " "), chunkIndex))
                chunkIndex += 1
                currentChunk = []
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append((currentChunk.joined(separator: " "), chunkIndex))
        }
        
        return chunks
    }
    
    private func createEmbeddings(
        chunks: [(text: String, index: Int)],
        documentId: UUID
    ) async throws -> [DocumentChunk] {
        var embeddedChunks: [DocumentChunk] = []
        
        for chunk in chunks {
            let embedding = await embeddingService.embed(text: chunk.text)
            
            embeddedChunks.append(DocumentChunk(
                id: UUID(),
                documentId: documentId,
                text: chunk.text,
                embedding: embedding,
                pageNumber: nil,
                chunkIndex: chunk.index
            ))
        }
        
        return embeddedChunks
    }
}

enum DocumentError: Error {
    case unsupportedType
    case pdfLoadFailed
    case extractionFailed
}
```

### 4.5 Online Resource Integration

**Purpose:** Fetch educational materials from online sources (OpenStax, MIT OCW, Wikipedia, etc.)

```swift
protocol OnlineResourceProvider {
    func search(query: String) async throws -> [ResourceResult]
    func fetchContent(resourceId: String) async throws -> ResourceContent
}

struct ResourceResult {
    let id: String
    let title: String
    let description: String
    let url: URL
    let source: String // "openstax", "mit_ocw", "wikipedia", etc.
    let type: String // "textbook", "course", "article", "video"
}

struct ResourceContent {
    let id: String
    let title: String
    let text: String
    let outline: String?
    let sections: [ResourceSection]
}

struct ResourceSection {
    let title: String
    let content: String
    let subsections: [ResourceSection]
}

// MARK: - OpenStax Provider

actor OpenStaxProvider: OnlineResourceProvider {
    private let baseURL = "https://openstax.org/api/v2"
    
    func search(query: String) async throws -> [ResourceResult] {
        // OpenStax has a relatively small catalog, return all books
        let books = try await fetchAllBooks()
        
        // Filter by query
        return books.filter { book in
            book.title.localizedCaseInsensitiveContains(query) ||
            book.description.localizedCaseInsensitiveContains(query)
        }
    }
    
    func fetchContent(resourceId: String) async throws -> ResourceContent {
        // Fetch book details
        let url = URL(string: "\(baseURL)/books/\(resourceId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let book = try JSONDecoder().decode(OpenStaxBook.self, from: data)
        
        // Fetch table of contents
        let tocURL = URL(string: book.contentURL)!
        let (tocData, _) = try await URLSession.shared.data(from: tocURL)
        let toc = try JSONDecoder().decode(OpenStaxTOC.self, from: tocData)
        
        return ResourceContent(
            id: resourceId,
            title: book.title,
            text: "", // Full text requires parsing HTML chapters
            outline: generateOutline(from: toc),
            sections: parseSections(from: toc)
        )
    }
    
    private func fetchAllBooks() async throws -> [ResourceResult] {
        let url = URL(string: "\(baseURL)/books")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OpenStaxBooksResponse.self, from: data)
        
        return response.books.map { book in
            ResourceResult(
                id: String(book.id),
                title: book.title,
                description: book.description,
                url: URL(string: "https://openstax.org/books/\(book.slug)")!,
                source: "openstax",
                type: "textbook"
            )
        }
    }
    
    private func generateOutline(from toc: OpenStaxTOC) -> String {
        var outline = ""
        for (index, chapter) in toc.chapters.enumerated() {
            outline += "\(index + 1). \(chapter.title)\n"
            for (subIndex, section) in chapter.sections.enumerated() {
                outline += "   \(index + 1).\(subIndex + 1) \(section.title)\n"
            }
        }
        return outline
    }
    
    private func parseSections(from toc: OpenStaxTOC) -> [ResourceSection] {
        toc.chapters.map { chapter in
            ResourceSection(
                title: chapter.title,
                content: "", // Would need to fetch chapter HTML
                subsections: chapter.sections.map { section in
                    ResourceSection(
                        title: section.title,
                        content: "",
                        subsections: []
                    )
                }
            )
        }
    }
}

// MARK: - OpenStax API Models

struct OpenStaxBooksResponse: Codable {
    let books: [OpenStaxBook]
}

struct OpenStaxBook: Codable {
    let id: Int
    let title: String
    let description: String
    let slug: String
    let contentURL: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, slug
        case contentURL = "table_of_contents"
    }
}

struct OpenStaxTOC: Codable {
    let chapters: [OpenStaxChapter]
}

struct OpenStaxChapter: Codable {
    let title: String
    let sections: [OpenStaxSection]
}

struct OpenStaxSection: Codable {
    let title: String
    let id: String
}

// MARK: - Wikipedia Provider (for quick reference)

actor WikipediaProvider: OnlineResourceProvider {
    private let baseURL = "https://en.wikipedia.org/w/api.php"
    
    func search(query: String) async throws -> [ResourceResult] {
        let urlString = "\(baseURL)?action=opensearch&search=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&limit=10&format=json"
        let url = URL(string: urlString)!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([[String]].self, from: data)
        
        guard response.count >= 4 else { return [] }
        
        let titles = response[1]
        let descriptions = response[2]
        let urls = response[3]
        
        return zip(titles, zip(descriptions, urls)).map { title, descAndUrl in
            ResourceResult(
                id: title,
                title: title,
                description: descAndUrl.0,
                url: URL(string: descAndUrl.1)!,
                source: "wikipedia",
                type: "article"
            )
        }
    }
    
    func fetchContent(resourceId: String) async throws -> ResourceContent {
        let urlString = "\(baseURL)?action=query&prop=extracts&exintro&explaintext&titles=\(resourceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&format=json"
        let url = URL(string: urlString)!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        // Parse Wikipedia API response
        
        // Simplified implementation
        return ResourceContent(
            id: resourceId,
            title: resourceId,
            text: "", // Parse from API
            outline: nil,
            sections: []
        )
    }
}

// MARK: - Resource Manager

actor OnlineResourceManager {
    private var providers: [String: OnlineResourceProvider] = [:]
    
    init() {
        providers["openstax"] = OpenStaxProvider()
        providers["wikipedia"] = WikipediaProvider()
        // Add more providers: MIT OCW, Khan Academy, etc.
    }
    
    func searchAll(query: String) async throws -> [ResourceResult] {
        var allResults: [ResourceResult] = []
        
        for provider in providers.values {
            let results = try await provider.search(query: query)
            allResults.append(contentsOf: results)
        }
        
        return allResults
    }
    
    func importResource(_ result: ResourceResult, to curriculum: Curriculum) async throws -> Topic {
        guard let provider = providers[result.source] else {
            throw ResourceError.providerNotFound
        }
        
        let content = try await provider.fetchContent(resourceId: result.id)
        
        // Create topic from resource
        let topic = Topic(context: curriculum.managedObjectContext!)
        topic.id = UUID()
        topic.title = content.title
        topic.descriptionText = result.description
        topic.outlineText = content.outline
        topic.curriculum = curriculum
        
        // Create document
        let document = Document(context: curriculum.managedObjectContext!)
        document.id = UUID()
        document.title = content.title
        document.type = "imported"
        document.extractedText = content.text
        document.uploadedAt = Date()
        
        return topic
    }
}

enum ResourceError: Error {
    case providerNotFound
    case fetchFailed
}
```

---

## 5. Learning Materials Interface

### 5.1 UI Structure

```
Curriculum Tab
â”œâ”€â”€ My Curricula
â”‚   â”œâ”€â”€ [List of user curricula]
â”‚   â””â”€â”€ + Create New Curriculum
â”‚
â”œâ”€â”€ Browse Online Resources
â”‚   â”œâ”€â”€ Search Bar
â”‚   â”œâ”€â”€ Provider Filter (OpenStax, Wikipedia, MIT OCW, etc.)
â”‚   â””â”€â”€ Results List
â”‚       â””â”€â”€ [Tap to import]
â”‚
â””â”€â”€ Import Materials
    â”œâ”€â”€ Files (PDF, Text, Markdown)
    â”œâ”€â”€ Transcripts (from previous sessions)
    â””â”€â”€ Manual Topic Entry
```

### 5.2 SwiftUI Views

```swift
// MARK: - Main Curriculum View

struct CurriculumView: View {
    @StateObject private var viewModel: CurriculumViewModel
    @State private var selectedTab: CurriculumTab = .myCurricula
    
    enum CurriculumTab {
        case myCurricula
        case browseOnline
        case importMaterials
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Section", selection: $selectedTab) {
                    Text("My Curricula").tag(CurriculumTab.myCurricula)
                    Text("Browse Online").tag(CurriculumTab.browseOnline)
                    Text("Import").tag(CurriculumTab.importMaterials)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                switch selectedTab {
                case .myCurricula:
                    MyCurriculaView(viewModel: viewModel)
                case .browseOnline:
                    BrowseOnlineResourcesView(viewModel: viewModel)
                case .importMaterials:
                    ImportMaterialsView(viewModel: viewModel)
                }
            }
            .navigationTitle("Learning Materials")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.createNewCurriculum() }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

// MARK: - My Curricula View

struct MyCurriculaView: View {
    @ObservedObject var viewModel: CurriculumViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.curricula) { curriculum in
                NavigationLink(destination: CurriculumDetailView(curriculum: curriculum)) {
                    CurriculumRow(curriculum: curriculum)
                }
            }
            .onDelete(perform: viewModel.deleteCurricula)
        }
        .overlay {
            if viewModel.curricula.isEmpty {
                ContentUnavailableView(
                    "No Curricula",
                    systemImage: "book.closed",
                    description: Text("Create a curriculum or import materials to get started")
                )
            }
        }
    }
}

struct CurriculumRow: View {
    let curriculum: Curriculum
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(curriculum.title)
                .font(.headline)
            
            if let description = curriculum.descriptionText {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("\(curriculum.topics?.count ?? 0) topics", systemImage: "list.bullet")
                Spacer()
                if let source = curriculum.source {
                    Text(source.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Curriculum Detail View

struct CurriculumDetailView: View {
    @ObservedObject var curriculum: Curriculum
    @State private var selectedTopic: Topic?
    @State private var showingTopicEditor = false
    
    var body: some View {
        List {
            Section("Overview") {
                if let description = curriculum.descriptionText {
                    Text(description)
                }
                
                if let url = curriculum.sourceURL {
                    Link(destination: url) {
                        Label("View Source", systemImage: "link")
                    }
                }
            }
            
            Section("Topics") {
                ForEach(topicHierarchy(for: curriculum)) { topic in
                    TopicRow(topic: topic, level: 0)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTopic = topic
                        }
                }
            }
            
            Section("Documents") {
                ForEach(curriculum.documents?.allObjects as? [Document] ?? []) { document in
                    DocumentRow(document: document)
                }
            }
        }
        .navigationTitle(curriculum.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Topic") {
                    showingTopicEditor = true
                }
            }
        }
        .sheet(item: $selectedTopic) { topic in
            TopicDetailView(topic: topic)
        }
        .sheet(isPresented: $showingTopicEditor) {
            TopicEditorView(curriculum: curriculum)
        }
    }
    
    private func topicHierarchy(for curriculum: Curriculum) -> [Topic] {
        let topics = curriculum.topics?.allObjects as? [Topic] ?? []
        return topics.filter { $0.parentTopic == nil }.sorted { $0.order < $1.order }
    }
}

struct TopicRow: View {
    let topic: Topic
    let level: Int
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<level, id: \.self) { _ in
                    Text("  ")
                }
                
                Image(systemName: topic.subTopics?.count ?? 0 > 0 ? "folder.fill" : "doc.text.fill")
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(.body)
                    
                    if let duration = topic.estimatedDuration, duration > 0 {
                        Text("\(Int(duration)) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let progress = topic.progress {
                TopicProgressIndicator(progress: progress)
            }
        }
        
        // Recursive subtopics
        ForEach((topic.subTopics?.allObjects as? [Topic] ?? []).sorted { $0.order < $1.order }) { subtopic in
            TopicRow(topic: subtopic, level: level + 1)
        }
    }
}

struct TopicProgressIndicator: View {
    let progress: TopicProgress
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
            
            if progress.status == TopicStatus.completed.rawValue {
                Text("\(Int(progress.masteryLevel * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var statusIcon: String {
        switch TopicStatus(rawValue: progress.status) {
        case .notStarted:
            return "circle"
        case .inProgress:
            return "circle.lefthalf.filled"
        case .completed:
            return "checkmark.circle.fill"
        case .reviewing:
            return "arrow.clockwise.circle.fill"
        case .none:
            return "circle"
        }
    }
    
    private var statusColor: Color {
        switch TopicStatus(rawValue: progress.status) {
        case .notStarted:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .reviewing:
            return .orange
        case .none:
            return .gray
        }
    }
}

// MARK: - Topic Detail View

struct TopicDetailView: View {
    @ObservedObject var topic: Topic
    @Environment(\.dismiss) private var dismiss
    @State private var showingSessionStart = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Description") {
                    if let description = topic.descriptionText {
                        Text(description)
                    }
                }
                
                if let objectives = topic.learningObjectives, !objectives.isEmpty {
                    Section("Learning Objectives") {
                        ForEach(objectives, id: \.self) { objective in
                            Label(objective, systemImage: "target")
                        }
                    }
                }
                
                if let outline = topic.outlineText {
                    Section("Outline") {
                        Text(outline)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                if let documents = topic.referenceDocuments as? Set<Document>, !documents.isEmpty {
                    Section("Reference Materials") {
                        ForEach(Array(documents)) { document in
                            DocumentRow(document: document)
                        }
                    }
                }
                
                if let progress = topic.progress {
                    Section("Progress") {
                        TopicProgressDetailView(progress: progress)
                    }
                }
            }
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Start Session") {
                        showingSessionStart = true
                    }
                }
            }
            .sheet(isPresented: $showingSessionStart) {
                SessionStartView(topic: topic)
            }
        }
    }
}

struct TopicProgressDetailView: View {
    let progress: TopicProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                Spacer()
                Text(TopicStatus(rawValue: progress.status)?.rawValue.capitalized ?? "Unknown")
                    .fontWeight(.semibold)
            }
            
            if let startedAt = progress.startedAt {
                HStack {
                    Text("Started:")
                    Spacer()
                    Text(startedAt, style: .date)
                }
            }
            
            HStack {
                Text("Time Spent:")
                Spacer()
                Text(formatDuration(progress.totalTimeSpent))
            }
            
            if progress.status == TopicStatus.completed.rawValue {
                HStack {
                    Text("Mastery:")
                    Spacer()
                    HStack(spacing: 4) {
                        ProgressView(value: Double(progress.masteryLevel))
                            .frame(width: 100)
                        Text("\(Int(progress.masteryLevel * 100))%")
                    }
                }
            }
            
            if let concepts = progress.conceptsCovered, !concepts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Concepts Covered:")
                        .fontWeight(.medium)
                    ForEach(concepts, id: \.self) { concept in
                        Text("â€¢ \(concept)")
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Browse Online Resources

struct BrowseOnlineResourcesView: View {
    @ObservedObject var viewModel: CurriculumViewModel
    @State private var searchQuery = ""
    @State private var selectedProvider: String = "all"
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search educational resources", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            await viewModel.searchOnlineResources(query: searchQuery)
                        }
                    }
                
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Provider Filter
            Picker("Provider", selection: $selectedProvider) {
                Text("All").tag("all")
                Text("OpenStax").tag("openstax")
                Text("Wikipedia").tag("wikipedia")
                Text("MIT OCW").tag("mit_ocw")
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Results
            List(viewModel.filteredOnlineResources(provider: selectedProvider)) { result in
                OnlineResourceRow(result: result) {
                    Task {
                        await viewModel.importResource(result)
                    }
                }
            }
            .overlay {
                if viewModel.onlineResources.isEmpty && !searchQuery.isEmpty {
                    ContentUnavailableView.search
                } else if viewModel.onlineResources.isEmpty {
                    ContentUnavailableView(
                        "Search Resources",
                        systemImage: "magnifyingglass",
                        description: Text("Search for educational materials from online sources")
                    )
                }
            }
        }
    }
}

struct OnlineResourceRow: View {
    let result: ResourceResult
    let onImport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.title)
                    .font(.headline)
                
                Spacer()
                
                Button(action: onImport) {
                    Label("Import", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
            }
            
            Text(result.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            HStack {
                Text(result.source.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                
                Text(result.type.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Link(destination: result.url) {
                    Image(systemName: "arrow.up.forward.square")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Import Materials

struct ImportMaterialsView: View {
    @ObservedObject var viewModel: CurriculumViewModel
    @State private var showingFilePicker = false
    @State private var showingManualEntry = false
    
    var body: some View {
        List {
            Section("Import Files") {
                Button(action: { showingFilePicker = true }) {
                    Label("Select Files (PDF, Text, Markdown)", systemImage: "doc.badge.plus")
                }
                
                Button(action: { viewModel.importFromTranscripts() }) {
                    Label("Import from Session Transcripts", systemImage: "bubble.left.and.bubble.right")
                }
            }
            
            Section("Manual Entry") {
                Button(action: { showingManualEntry = true }) {
                    Label("Create Topic Manually", systemImage: "square.and.pencil")
                }
            }
            
            if !viewModel.recentImports.isEmpty {
                Section("Recently Imported") {
                    ForEach(viewModel.recentImports) { document in
                        DocumentRow(document: document)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .plainText, .text],
            allowsMultipleSelection: true
        ) { result in
            Task {
                await viewModel.importFiles(result)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualTopicEntryView(viewModel: viewModel)
        }
    }
}

struct DocumentRow: View {
    let document: Document
    
    var body: some View {
        HStack {
            Image(systemName: iconForDocumentType(document.type))
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.body)
                
                HStack {
                    Text(document.type.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if document.wordCount > 0 {
                        Text("â€¢")
                            .foregroundStyle(.secondary)
                        Text("\(document.wordCount) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                // Open document
            }) {
                Image(systemName: "doc.text.magnifyingglass")
            }
        }
    }
    
    private func iconForDocumentType(_ type: String) -> String {
        switch type {
        case "pdf":
            return "doc.fill"
        case "text", "markdown":
            return "doc.text.fill"
        case "transcript":
            return "text.bubble.fill"
        default:
            return "doc"
        }
    }
}

// MARK: - Manual Topic Entry

struct ManualTopicEntryView: View {
    @ObservedObject var viewModel: CurriculumViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var outline = ""
    @State private var objectives: [String] = [""]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Topic Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Learning Objectives") {
                    ForEach(objectives.indices, id: \.self) { index in
                        HStack {
                            TextField("Objective \(index + 1)", text: $objectives[index])
                            
                            Button(action: { objectives.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    Button(action: { objectives.append("") }) {
                        Label("Add Objective", systemImage: "plus.circle")
                    }
                }
                
                Section("Outline (Optional)") {
                    TextEditor(text: $outline)
                        .frame(minHeight: 200)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle("New Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.createManualTopic(
                                title: title,
                                description: description,
                                outline: outline,
                                objectives: objectives.filter { !$0.isEmpty }
                            )
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
```

---

## 6. Provider Abstraction Layer

*(Protocols defined earlier in Section 3. Here are additional concrete implementations)*

### 6.1 Additional STT Implementations

```swift
// MARK: - Deepgram Nova-3 STT

actor DeepgramSTT: STTService {
    private var websocket: URLSessionWebSocketTask?
    private let apiKey: String
    private var streamContinuation: AsyncStream<STTResult>.Continuation?
    
    private var latencyMetrics = STTMetrics(
        medianLatency: 0,
        p99Latency: 0,
        wordEmissionRate: 0
    )
    
    var costPerHour: Decimal { 0.0043 * 60 } // $0.0043/min
    
    func startStreaming(audioFormat: AVAudioFormat) async throws -> AsyncStream<STTResult> {
        // Deepgram WebSocket connection
        var request = URLRequest(url: URL(string: "wss://api.deepgram.com/v1/listen")!)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        
        websocket = URLSession.shared.webSocketTask(with: request)
        websocket?.resume()
        
        return AsyncStream { continuation in
            self.streamContinuation = continuation
            
            Task {
                await self.receiveMessages()
            }
        }
    }
    
    func sendAudio(_ buffer: AVAudioPCMBuffer) async throws {
        guard let websocket = websocket else { return }
        
        // Convert to required format
        let audioData = buffer.toData()
        let message = URLSessionWebSocketTask.Message.data(audioData)
        
        try await websocket.send(message)
    }
    
    func stopStreaming() async throws {
        websocket?.cancel(with: .goingAway, reason: nil)
        streamContinuation?.finish()
    }
    
    private func receiveMessages() async {
        while let websocket = websocket {
            do {
                let message = try await websocket.receive()
                
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let response = try? JSONDecoder().decode(DeepgramResponse.self, from: data) {
                        await handleResponse(response)
                    }
                case .data:
                    break
                @unknown default:
                    break
                }
            } catch {
                streamContinuation?.finish()
                break
            }
        }
    }
    
    private func handleResponse(_ response: DeepgramResponse) async {
        guard let channel = response.channel.alternatives.first else { return }
        
        let result = STTResult(
            transcript: channel.transcript,
            isFinal: response.isFinal,
            isEndOfUtterance: response.speechFinal,
            confidence: channel.confidence,
            timestamp: Date().timeIntervalSince1970,
            latency: response.duration
        )
        
        streamContinuation?.yield(result)
    }
}

struct DeepgramResponse: Codable {
    let duration: TimeInterval
    let isFinal: Bool
    let speechFinal: Bool
    let channel: DeepgramChannel
    
    enum CodingKeys: String, CodingKey {
        case duration
        case isFinal = "is_final"
        case speechFinal = "speech_final"
        case channel
    }
}

struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]
}

struct DeepgramAlternative: Codable {
    let transcript: String
    let confidence: Float
}

// MARK: - Apple Speech STT (On-Device)

actor AppleSTT: STTService {
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var streamContinuation: AsyncStream<STTResult>.Continuation?
    
    private var latencyMetrics = STTMetrics(
        medianLatency: 0,
        p99Latency: 0,
        wordEmissionRate: 0
    )
    
    var costPerHour: Decimal { 0 } // Free on-device
    
    func startStreaming(audioFormat: AVAudioFormat) async throws -> AsyncStream<STTResult> {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.requiresOnDeviceRecognition = true
        request?.shouldReportPartialResults = true
        
        return AsyncStream { continuation in
            self.streamContinuation = continuation
            
            guard let recognizer = self.recognizer,
                  let request = self.request else {
                continuation.finish()
                return
            }
            
            self.task = recognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    let sttResult = STTResult(
                        transcript: result.bestTranscription.formattedString,
                        isFinal: result.isFinal,
                        isEndOfUtterance: result.isFinal,
                        confidence: 0.8, // Apple doesn't provide confidence
                        timestamp: Date().timeIntervalSince1970,
                        latency: 0.2 // Typical on-device latency
                    )
                    
                    continuation.yield(sttResult)
                }
                
                if error != nil || result?.isFinal == true {
                    continuation.finish()
                }
            }
        }
    }
    
    func sendAudio(_ buffer: AVAudioPCMBuffer) async throws {
        request?.append(buffer)
    }
    
    func stopStreaming() async throws {
        request?.endAudio()
        task?.cancel()
        streamContinuation?.finish()
    }
}
```

### 6.2 Additional TTS Implementations

```swift
// MARK: - ElevenLabs Flash TTS

actor ElevenLabsTTS: TTSService {
    private var websocket: URLSessionWebSocketTask?
    private let apiKey: String
    private var streamContinuation: AsyncStream<TTSAudioChunk>.Continuation?
    
    private var latencyMetrics = TTSMetrics(
        medianTTFB: 0.135, // 135ms from docs
        p99TTFB: 0.200
    )
    
    var costPerCharacter: Decimal { 0.0003 } // Example rate
    
    func synthesize(text: String) async throws -> AsyncStream<TTSAudioChunk> {
        // ElevenLabs WebSocket streaming
        var request = URLRequest(url: URL(string: "wss://api.elevenlabs.io/v1/text-to-speech/stream")!)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        websocket = URLSession.shared.webSocketTask(with: request)
        websocket?.resume()
        
        // Send text
        let payload: [String: Any] = [
            "text": text,
            "model_id": "eleven_flash_v2_5",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await websocket?.send(.data(data))
        
        return AsyncStream { continuation in
            self.streamContinuation = continuation
            
            Task {
                await self.receiveAudio()
            }
        }
    }
    
    func flush() async throws {
        websocket?.cancel(with: .goingAway, reason: nil)
        streamContinuation?.finish()
    }
    
    private func receiveAudio() async {
        var chunkIndex = 0
        var isFirstChunk = true
        let startTime = Date()
        
        while let websocket = websocket {
            do {
                let message = try await websocket.receive()
                
                switch message {
                case .data(let audioData):
                    let chunk = TTSAudioChunk(
                        audioData: audioData,
                        format: .opus, // ElevenLabs uses Opus
                        sequenceNumber: chunkIndex,
                        isFirst: isFirstChunk,
                        isLast: false,
                        timeToFirstByte: isFirstChunk ? Date().timeIntervalSince(startTime) : nil
                    )
                    
                    streamContinuation?.yield(chunk)
                    
                    isFirstChunk = false
                    chunkIndex += 1
                    
                case .string(let text):
                    // Check for end marker
                    if text.contains("done") {
                        streamContinuation?.finish()
                        return
                    }
                    
                @unknown default:
                    break
                }
            } catch {
                streamContinuation?.finish()
                break
            }
        }
    }
}

// MARK: - Apple TTS (On-Device)

actor AppleTTS: TTSService {
    private let synthesizer = AVSpeechSynthesizer()
    private var streamContinuation: AsyncStream<TTSAudioChunk>.Continuation?
    
    private var latencyMetrics = TTSMetrics(
        medianTTFB: 0.050, // Immediate
        p99TTFB: 0.100
    )
    
    var costPerCharacter: Decimal { 0 } // Free on-device
    
    func synthesize(text: String) async throws -> AsyncStream<TTSAudioChunk> {
        return AsyncStream { continuation in
            self.streamContinuation = continuation
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            
            // Note: AVSpeechSynthesizer doesn't provide streaming audio data
            // This is a limitation - we'd need to chunk sentences and speak them
            // Or use a different approach for true streaming
            
            self.synthesizer.speak(utterance)
            
            // Simulate immediate availability
            // In practice, AVSpeechSynthesizer handles playback directly
            continuation.finish()
        }
    }
    
    func flush() async throws {
        synthesizer.stopSpeaking(at: .immediate)
        streamContinuation?.finish()
    }
}
```

### 6.3 Additional LLM Implementations

```swift
// MARK: - Anthropic Claude LLM

actor AnthropicLLM: LLMService {
    private let apiKey: String
    private let httpClient: URLSession
    
    private var latencyMetrics = LLMMetrics(
        medianFirstToken: 0.200,
        p99FirstToken: 0.500,
        tokensPerSecond: 50
    )
    
    var costPerToken: (input: Decimal, output: Decimal) {
        // Claude Sonnet 4 pricing
        (input: Decimal(3.00) / 1_000_000, output: Decimal(15.00) / 1_000_000)
    }
    
    func streamCompletion(
        messages: [LLMMessage],
        config: LLMConfig
    ) async throws -> AsyncStream<LLMToken> {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        
        let payload: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "stream": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        return AsyncStream { continuation in
            Task {
                do {
                    let (bytes, _) = try await httpClient.bytes(for: request)
                    var tokenIndex = 0
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = line.dropFirst(6)
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            if let data = jsonString.data(using: .utf8),
                               let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data) {
                                
                                if let delta = event.delta?.text {
                                    let token = LLMToken(
                                        content: delta,
                                        isDone: event.type == "message_stop",
                                        stopReason: event.stopReason.map { StopReason(rawValue: $0) ?? .endTurn },
                                        timestamp: Date().timeIntervalSince1970,
                                        tokenIndex: tokenIndex
                                    )
                                    
                                    continuation.yield(token)
                                    tokenIndex += 1
                                }
                            }
                        }
                    }
                } catch {
                    continuation.finish()
                }
            }
        }
    }
}

struct AnthropicStreamEvent: Codable {
    let type: String
    let delta: AnthropicDelta?
    let stopReason: String?
    
    enum CodingKeys: String, CodingKey {
        case type, delta
        case stopReason = "stop_reason"
    }
}

struct AnthropicDelta: Codable {
    let text: String?
}

// MARK: - Local MLX LLM (On-Device)

actor LocalMLXLLM: LLMService {
    private var model: MLXModel?
    
    private var latencyMetrics = LLMMetrics(
        medianFirstToken: 0.500, // Slower on device
        p99FirstToken: 1.000,
        tokensPerSecond: 15 // Limited by A17 Pro
    )
    
    var costPerToken: (input: Decimal, output: Decimal) {
        (input: 0, output: 0) // Free on-device
    }
    
    func streamCompletion(
        messages: [LLMMessage],
        config: LLMConfig
    ) async throws -> AsyncStream<LLMToken> {
        // Load model if needed
        if model == nil {
            model = try await loadMLXModel(config.model)
        }
        
        guard let model = model else {
            throw LLMError.modelNotLoaded
        }
        
        return AsyncStream { continuation in
            Task {
                // Generate tokens
                let prompt = formatMessagesAsPrompt(messages)
                let tokens = try await model.generate(prompt: prompt, maxTokens: config.maxTokens)
                
                for (index, token) in tokens.enumerated() {
                    let llmToken = LLMToken(
                        content: token,
                        isDone: index == tokens.count - 1,
                        stopReason: index == tokens.count - 1 ? .endTurn : nil,
                        timestamp: Date().timeIntervalSince1970,
                        tokenIndex: index
                    )
                    
                    continuation.yield(llmToken)
                    
                    // Yield control to avoid blocking
                    await Task.yield()
                }
                
                continuation.finish()
            }
        }
    }
    
    private func loadMLXModel(_ modelName: String) async throws -> MLXModel {
        // Load quantized model from app bundle
        // This would use MLX Swift bindings
        fatalError("MLX implementation needed")
    }
    
    private func formatMessagesAsPrompt(_ messages: [LLMMessage]) -> String {
        // Format messages for local model
        messages.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
    }
}

enum LLMError: Error {
    case modelNotLoaded
    case generationFailed
}
```

---

## 7. Advanced Configuration System

### 7.1 Configuration Structure

```swift
struct AppConfiguration: Codable {
    // MARK: - Provider Selection
    
    var providers: ProviderConfiguration = .default
    
    // MARK: - Audio Configuration
    
    var audio: AudioEngineConfig = .default
    
    // MARK: - Session Configuration
    
    var session: SessionConfig = .default
    
    // MARK: - Curriculum Configuration
    
    var curriculum: CurriculumConfiguration = .default
    
    // MARK: - Telemetry Configuration
    
    var telemetry: TelemetryConfiguration = .default
    
    // MARK: - Presets
    
    static let balanced = AppConfiguration()
    
    static let lowLatency = AppConfiguration(
        providers: ProviderConfiguration(
            stt: .assemblyAI,
            tts: .deepgramAura2,
            llm: .openAI
        ),
        audio: AudioEngineConfig(
            sampleRate: 16000,
            bufferSize: 512,
            vadThreshold: 0.6
        ),
        session: SessionConfig(
            sentenceBreakThreshold: 1,
            enableEagerTTS: true
        )
    )
    
    static let highQuality = AppConfiguration(
        providers: ProviderConfiguration(
            stt: .assemblyAI,
            tts: .elevenLabsFlash,
            llm: .anthropicClaude
        ),
        audio: AudioEngineConfig(
            sampleRate: 48000,
            bufferSize: 2048
        )
    )
    
    static let costOptimized = AppConfiguration(
        providers: ProviderConfiguration(
            stt: .deepgramNova3,
            tts: .deepgramAura2,
            llm: .openAI // Use 4o-mini
        ),
        session: SessionConfig(
            maxContextTokens: 4000,
            enableContextCompression: true
        )
    )
    
    static let privacyFirst = AppConfiguration(
        providers: ProviderConfiguration(
            stt: .appleSpeech,
            tts: .appleTTS,
            llm: .localMLX,
            vad: .silero
        ),
        audio: AudioEngineConfig(
            enableVoiceProcessing: true
        )
    )
}

struct ProviderConfiguration: Codable {
    var stt: STTProvider = .assemblyAI
    var tts: TTSProvider = .deepgramAura2
    var llm: LLMProvider = .openAI
    var vad: VADProvider = .silero
    var transport: TransportProvider = .liveKit
    
    // API Keys
    var assemblyAIKey: String = ""
    var deepgramKey: String = ""
    var openAIKey: String = ""
    var anthropicKey: String = ""
    var elevenLabsKey: String = ""
    var liveKitURL: String = ""
    var liveKitToken: String = ""
    
    static let `default` = ProviderConfiguration()
}

enum STTProvider: String, Codable, CaseIterable {
    case assemblyAI = "AssemblyAI Universal-Streaming"
    case deepgramNova3 = "Deepgram Nova-3"
    case openAIWhisper = "OpenAI Whisper"
    case appleSpeech = "Apple Speech (On-Device)"
}

enum TTSProvider: String, Codable, CaseIterable {
    case deepgramAura2 = "Deepgram Aura-2"
    case elevenLabsFlash = "ElevenLabs Flash"
    case elevenLabsTurbo = "ElevenLabs Turbo"
    case playHT = "PlayHT"
    case appleTTS = "Apple TTS (On-Device)"
}

enum LLMProvider: String, Codable, CaseIterable {
    case openAI = "OpenAI GPT-4o"
    case openAI4oMini = "OpenAI GPT-4o-mini"
    case anthropicClaude = "Anthropic Claude Sonnet 4"
    case localMLX = "Local MLX (On-Device)"
}

enum VADProvider: String, Codable, CaseIterable {
    case silero = "Silero VAD (Neural Engine)"
    case tenVAD = "TEN VAD"
    case webrtcVAD = "WebRTC VAD"
}

enum TransportProvider: String, Codable, CaseIterable {
    case liveKit = "LiveKit"
    case daily = "Daily"
    case webrtc = "Raw WebRTC"
}

struct CurriculumConfiguration: Codable {
    var enableOnlineResources: Bool = true
    var enableAutoSummarization: Bool = true
    var enableEmbeddings: Bool = false // Requires OpenAI API
    var maxDocumentSize: Int = 10_000_000 // 10MB
    var supportedFormats: [String] = ["pdf", "txt", "md"]
}

struct TelemetryConfiguration: Codable {
    var enableDetailedLogging: Bool = true
    var logLevel: LogLevel = .info
    var enableCostTracking: Bool = true
    var enableLatencyTracking: Bool = true
    var enablePerformanceMonitoring: Bool = true
    var exportFormat: ExportFormat = .json
    
    enum LogLevel: String, Codable {
        case debug, info, warning, error
    }
    
    enum ExportFormat: String, Codable {
        case json, csv
    }
}
```

### 7.2 Configuration UI

```swift
struct ConfigurationView: View {
    @StateObject private var configManager: ConfigurationManager
    @State private var selectedPreset: ConfigPreset = .balanced
    @State private var showingAdvanced = false
    
    enum ConfigPreset: String, CaseIterable {
        case balanced = "Balanced"
        case lowLatency = "Low Latency"
        case highQuality = "High Quality"
        case costOptimized = "Cost Optimized"
        case privacyFirst = "Privacy First"
        case custom = "Custom"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Presets") {
                    Picker("Configuration Preset", selection: $selectedPreset) {
                        ForEach(ConfigPreset.allCases, id: \.self) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .onChange(of: selectedPreset) { _, newValue in
                        loadPreset(newValue)
                    }
                    
                    if selectedPreset != .custom {
                        Text(presetDescription(selectedPreset))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Provider Selection") {
                    NavigationLink("Speech-to-Text") {
                        ProviderPickerView(
                            title: "STT Provider",
                            selection: $configManager.config.providers.stt,
                            options: STTProvider.allCases
                        )
                    }
                    
                    NavigationLink("Text-to-Speech") {
                        ProviderPickerView(
                            title: "TTS Provider",
                            selection: $configManager.config.providers.tts,
                            options: TTSProvider.allCases
                        )
                    }
                    
                    NavigationLink("Language Model") {
                        ProviderPickerView(
                            title: "LLM Provider",
                            selection: $configManager.config.providers.llm,
                            options: LLMProvider.allCases
                        )
                    }
                    
                    NavigationLink("Voice Activity Detection") {
                        ProviderPickerView(
                            title: "VAD Provider",
                            selection: $configManager.config.providers.vad,
                            options: VADProvider.allCases
                        )
                    }
                }
                
                Section("API Keys") {
                    NavigationLink("Manage API Keys") {
                        APIKeysView(config: $configManager.config.providers)
                    }
                }
                
                Section {
                    Toggle("Advanced Settings", isOn: $showingAdvanced)
                }
                
                if showingAdvanced {
                    Section("Audio Settings") {
                        NavigationLink("Audio Configuration") {
                            AudioConfigView(config: $configManager.config.audio)
                        }
                    }
                    
                    Section("Session Settings") {
                        NavigationLink("Session Configuration") {
                            SessionConfigView(config: $configManager.config.session)
                        }
                    }
                    
                    Section("Curriculum Settings") {
                        NavigationLink("Curriculum Configuration") {
                            CurriculumConfigView(config: $configManager.config.curriculum)
                        }
                    }
                    
                    Section("Telemetry Settings") {
                        NavigationLink("Telemetry Configuration") {
                            TelemetryConfigView(config: $configManager.config.telemetry)
                        }
                    }
                }
                
                Section {
                    Button("Reset to Defaults") {
                        configManager.resetToDefaults()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Configuration")
        }
    }
    
    private func loadPreset(_ preset: ConfigPreset) {
        switch preset {
        case .balanced:
            configManager.config = .balanced
        case .lowLatency:
            configManager.config = .lowLatency
        case .highQuality:
            configManager.config = .highQuality
        case .costOptimized:
            configManager.config = .costOptimized
        case .privacyFirst:
            configManager.config = .privacyFirst
        case .custom:
            break
        }
    }
    
    private func presetDescription(_ preset: ConfigPreset) -> String {
        switch preset {
        case .balanced:
            return "Best overall performance and cost balance. AssemblyAI STT + Deepgram Aura-2 TTS + OpenAI GPT-4o."
        case .lowLatency:
            return "Optimized for <500ms response. Lower sample rate, smaller buffers, eager TTS."
        case .highQuality:
            return "Best audio quality for long listening sessions. 48kHz, ElevenLabs Flash, Claude Sonnet 4."
        case .costOptimized:
            return "Minimize costs while maintaining quality. Deepgram Nova-3 + Aura-2 + 4o-mini, context compression."
        case .privacyFirst:
            return "All processing on-device where possible. Apple STT/TTS, local MLX LLM."
        case .custom:
            return "Custom configuration with manual tuning."
        }
    }
}

struct AudioConfigView: View {
    @Binding var config: AudioEngineConfig
    
    var body: some View {
        Form {
            Section("Core Audio Settings") {
                Picker("Sample Rate", selection: $config.sampleRate) {
                    Text("16 kHz (Efficient)").tag(16000.0)
                    Text("24 kHz (Balanced)").tag(24000.0)
                    Text("48 kHz (High Quality)").tag(48000.0)
                }
                
                Picker("Buffer Size", selection: $config.bufferSize) {
                    Text("256 (Ultra Low Latency)").tag(AVAudioFrameCount(256))
                    Text("512 (Low Latency)").tag(AVAudioFrameCount(512))
                    Text("1024 (Balanced)").tag(AVAudioFrameCount(1024))
                    Text("2048 (Stable)").tag(AVAudioFrameCount(2048))
                }
            }
            
            Section("Voice Processing") {
                Toggle("Enable Voice Processing", isOn: $config.enableVoiceProcessing)
                Toggle("Echo Cancellation", isOn: $config.enableEchoCancellation)
                    .disabled(!config.enableVoiceProcessing)
                Toggle("Noise Suppression", isOn: $config.enableNoiseSupression)
                    .disabled(!config.enableVoiceProcessing)
                Toggle("Automatic Gain Control", isOn: $config.enableAutomaticGainControl)
                    .disabled(!config.enableVoiceProcessing)
            }
            
            Section("VAD Settings") {
                Slider(
                    value: $config.vadThreshold,
                    in: 0...1,
                    step: 0.05
                ) {
                    Text("VAD Threshold: \(config.vadThreshold, specifier: "%.2f")")
                }
                
                Stepper(
                    "Context Window: \(config.vadContextWindow) frames",
                    value: $config.vadContextWindow,
                    in: 1...10
                )
                
                Stepper(
                    "Smoothing: \(config.vadSmoothingWindow) frames",
                    value: $config.vadSmoothingWindow,
                    in: 1...20
                )
            }
            
            Section("Interruption Handling") {
                Toggle("Enable Barge-in", isOn: $config.enableBargein)
                
                Slider(
                    value: $config.bargeInThreshold,
                    in: 0...1,
                    step: 0.05
                ) {
                    Text("Barge-in Threshold: \(config.bargeInThreshold, specifier: "%.2f")")
                }
                .disabled(!config.enableBargein)
                
                Toggle("Clear TTS on Interrupt", isOn: $config.ttsClearOnInterrupt)
                    .disabled(!config.enableBargein)
            }
            
            Section("Performance") {
                Toggle("Adaptive Quality", isOn: $config.enableAdaptiveQuality)
                
                Picker("Thermal Throttle Threshold", selection: $config.thermalThrottleThreshold) {
                    Text("Nominal").tag(ProcessInfo.ThermalState.nominal)
                    Text("Fair").tag(ProcessInfo.ThermalState.fair)
                    Text("Serious").tag(ProcessInfo.ThermalState.serious)
                    Text("Critical").tag(ProcessInfo.ThermalState.critical)
                }
                .disabled(!config.enableAdaptiveQuality)
            }
        }
        .navigationTitle("Audio Configuration")
    }
}

struct SessionConfigView: View {
    @Binding var config: SessionConfig
    
    var body: some View {
        Form {
            Section("Session Duration") {
                Picker("Max Duration", selection: $config.sessionDuration) {
                    Text("30 min").tag(TimeInterval(1800))
                    Text("60 min").tag(TimeInterval(3600))
                    Text("90 min").tag(TimeInterval(5400))
                    Text("120 min").tag(TimeInterval(7200))
                }
            }
            
            Section("Turn Taking") {
                Toggle("Semantic Turn Detection", isOn: $config.enableSemanticTurnDetection)
                
                Stepper(
                    "Silence Threshold: \(config.silenceThresholdMs)ms",
                    value: $config.silenceThresholdMs,
                    in: 300...2000,
                    step: 100
                )
                
                Slider(
                    value: $config.minTurnDuration,
                    in: 0.1...2.0,
                    step: 0.1
                ) {
                    Text("Min Turn: \(config.minTurnDuration, specifier: "%.1f")s")
                }
                
                Slider(
                    value: $config.maxTurnDuration,
                    in: 30...300,
                    step: 10
                ) {
                    Text("Max Turn: \(Int(config.maxTurnDuration))s")
                }
            }
            
            Section("Interruptions") {
                Toggle("Enable Interruptions", isOn: $config.enableInterruptions)
                
                Slider(
                    value: $config.interruptionVADThreshold,
                    in: 0...1,
                    step: 0.05
                ) {
                    Text("VAD Threshold: \(config.interruptionVADThreshold, specifier: "%.2f")")
                }
                .disabled(!config.enableInterruptions)
                
                Slider(
                    value: $config.interruptionCooldown,
                    in: 0...2.0,
                    step: 0.1
                ) {
                    Text("Cooldown: \(config.interruptionCooldown, specifier: "%.1f")s")
                }
                .disabled(!config.enableInterruptions)
            }
            
            Section("TTS Streaming") {
                Stepper(
                    "Sentence Break: \(config.sentenceBreakThreshold)",
                    value: $config.sentenceBreakThreshold,
                    in: 1...5
                )
                
                Toggle("Eager TTS", isOn: $config.enableEagerTTS)
                
                Picker("Chunking Strategy", selection: $config.ttsChunkingStrategy) {
                    Text("Sentence Boundary").tag(TTSChunkStrategy.sentenceBoundary)
                    Text("Clause Boundary").tag(TTSChunkStrategy.clauseBoundary)
                    Text("Fixed Tokens").tag(TTSChunkStrategy.fixedTokens)
                }
            }
            
            Section("Context Management") {
                Stepper(
                    "Max Tokens: \(config.maxContextTokens)",
                    value: $config.maxContextTokens,
                    in: 2000...16000,
                    step: 1000
                )
                
                Toggle("Context Compression", isOn: $config.enableContextCompression)
                
                Stepper(
                    "Keep Recent Turns: \(config.keepRecentTurns)",
                    value: $config.keepRecentTurns,
                    in: 5...20
                )
                .disabled(!config.enableContextCompression)
            }
            
            Section("Recording") {
                Toggle("Enable Recording", isOn: $config.enableRecording)
                
                Picker("Format", selection: $config.recordingFormat) {
                    Text("M4A").tag(RecordingFormat.m4a)
                    Text("WAV").tag(RecordingFormat.wav)
                    Text("Opus").tag(RecordingFormat.opus)
                }
                .disabled(!config.enableRecording)
                
                Picker("Quality", selection: $config.recordingQuality) {
                    Text("Low").tag(AVAudioQuality.low)
                    Text("Medium").tag(AVAudioQuality.medium)
                    Text("High").tag(AVAudioQuality.high)
                }
                .disabled(!config.enableRecording)
            }
            
            Section("Curriculum") {
                Toggle("Curriculum Context", isOn: $config.enableCurriculumContext)
                
                Stepper(
                    "Max Curriculum Tokens: \(config.maxCurriculumContextTokens)",
                    value: $config.maxCurriculumContextTokens,
                    in: 500...4000,
                    step: 500
                )
                .disabled(!config.enableCurriculumContext)
            }
        }
        .navigationTitle("Session Configuration")
    }
}

// Similar views for CurriculumConfigView and TelemetryConfigView...
```

---

## 8. Telemetry & Observability

*(Core implementation covered in Section 3. Here are UI components)*

### 8.1 Real-Time Telemetry Dashboard

```swift
struct TelemetryDashboardView: View {
    @ObservedObject var telemetry: TelemetryEngine
    @State private var selectedMetric: MetricType = .latency
    
    enum MetricType {
        case latency, cost, quality, session
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Quick Stats
                    QuickStatsView(metrics: telemetry.currentMetrics)
                    
                    // Metric Type Picker
                    Picker("Metric", selection: $selectedMetric) {
                        Text("Latency").tag(MetricType.latency)
                        Text("Cost").tag(MetricType.cost)
                        Text("Quality").tag(MetricType.quality)
                        Text("Session").tag(MetricType.session)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Metric Detail
                    switch selectedMetric {
                    case .latency:
                        LatencyMetricsView(metrics: telemetry.currentMetrics)
                    case .cost:
                        CostMetricsView(metrics: telemetry.currentMetrics)
                    case .quality:
                        QualityMetricsView(metrics: telemetry.currentMetrics)
                    case .session:
                        SessionMetricsView(metrics: telemetry.currentMetrics)
                    }
                }
                .padding()
            }
            .navigationTitle("Telemetry")
        }
    }
}

struct QuickStatsView: View {
    let metrics: TelemetryEngine.SessionMetrics
    
    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "E2E Latency",
                value: "\(Int(metrics.e2eLatencies.last ?? 0 * 1000))ms",
                color: latencyColor(metrics.e2eLatencies.last ?? 0)
            )
            
            StatCard(
                title: "Session Cost",
                value: "$\(metrics.totalCost, specifier: "%.2f")",
                color: .blue
            )
            
            StatCard(
                title: "Duration",
                value: formatDuration(metrics.duration),
                color: .green
            )
        }
    }
    
    private func latencyColor(_ latency: TimeInterval) -> Color {
        switch latency {
        case ..<0.3: return .green
        case 0.3..<0.6: return .yellow
        default: return .red
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LatencyMetricsView: View {
    let metrics: TelemetryEngine.SessionMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Latency Breakdown")
                .font(.headline)
            
            LatencyChart(
                sttLatencies: metrics.sttLatencies,
                llmLatencies: metrics.llmLatencies,
                ttsLatencies: metrics.ttsLatencies
            )
            .frame(height: 200)
            
            VStack(spacing: 12) {
                LatencyRow(
                    label: "STT",
                    median: metrics.sttLatencies.median,
                    p99: metrics.sttLatencies.percentile(99)
                )
                
                LatencyRow(
                    label: "LLM",
                    median: metrics.llmLatencies.median,
                    p99: metrics.llmLatencies.percentile(99)
                )
                
                LatencyRow(
                    label: "TTS",
                    median: metrics.ttsLatencies.median,
                    p99: metrics.ttsLatencies.percentile(99)
                )
                
                LatencyRow(
                    label: "E2E",
                    median: metrics.e2eLatencies.median,
                    p99: metrics.e2eLatencies.percentile(99),
                    highlight: true
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LatencyRow: View {
    let label: String
    let median: TimeInterval
    let p99: TimeInterval
    let highlight: Bool
    
    init(label: String, median: TimeInterval, p99: TimeInterval, highlight: Bool = false) {
        self.label = label
        self.median = median
        self.p99 = p99
        self.highlight = highlight
    }
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(highlight ? .bold : .regular)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("P50: \(Int(median * 1000))ms")
                    .font(.caption)
                Text("P99: \(Int(p99 * 1000))ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CostMetricsView: View {
    let metrics: TelemetryEngine.SessionMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Breakdown")
                .font(.headline)
            
            CostPieChart(
                sttCost: metrics.sttCost,
                ttsCost: metrics.ttsCost,
                llmCost: metrics.llmCost
            )
            .frame(height: 200)
            
            VStack(spacing: 12) {
                CostRow(label: "STT", cost: metrics.sttCost)
                CostRow(label: "TTS", cost: metrics.ttsCost)
                CostRow(label: "LLM", cost: metrics.llmCost)
                
                Divider()
                
                CostRow(label: "Total", cost: metrics.totalCost, highlight: true)
                
                HStack {
                    Text("Rate")
                    Spacer()
                    Text("$\(metrics.costPerHour, specifier: "%.2f")/hour")
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CostRow: View {
    let label: String
    let cost: Decimal
    let highlight: Bool
    
    init(label: String, cost: Decimal, highlight: Bool = false) {
        self.label = label
        self.cost = cost
        self.highlight = highlight
    }
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(highlight ? .bold : .regular)
            
            Spacer()
            
            Text("$\(cost as NSDecimalNumber, specifier: "%.4f")")
                .fontWeight(highlight ? .bold : .regular)
        }
    }
}

// Additional metric views: QualityMetricsView, SessionMetricsView...
```

---

## 9. Data Models

*(Core Data entities defined in Section 4. Here are additional supporting models)*

```swift
// MARK: - LLM Message Types

struct LLMMessage: Codable {
    let role: Role
    let content: String
    
    enum Role: String, Codable {
        case system
        case user
        case assistant
    }
}

enum StopReason: String, Codable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
}

// MARK: - Audio Types

struct TTSAudioChunk {
    let audioData: Data
    let format: AudioFormat
    let sequenceNumber: Int
    let isFirst: Bool
    let isLast: Bool
    let timeToFirstByte: TimeInterval?
    
    enum AudioFormat {
        case pcm
        case opus
        case mp3
    }
    
    func toAVAudioPCMBuffer() throws -> AVAudioPCMBuffer {
        // Convert audioData to AVAudioPCMBuffer based on format
        // Implementation depends on format
        fatalError("Implementation needed")
    }
}

// MARK: - Session Export

struct SessionExport: Codable {
    let sessionId: UUID
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let topic: String?
    
    let configuration: ConfigurationSnapshot
    let metrics: MetricsSnapshot
    let transcript: [TranscriptEntry]
    
    let recordingURL: URL?
}

struct ConfigurationSnapshot: Codable {
    let sttProvider: String
    let ttsProvider: String
    let llmProvider: String
    let audioConfig: AudioEngineConfig
    let sessionConfig: SessionConfig
}

struct MetricsSnapshot: Codable {
    let latencies: LatencyMetrics
    let costs: CostMetrics
    let quality: QualityMetrics
}

struct LatencyMetrics: Codable {
    let sttMedianMs: Int
    let sttP99Ms: Int
    let llmMedianMs: Int
    let llmP99Ms: Int
    let ttsMedianMs: Int
    let ttsP99Ms: Int
    let e2eMedianMs: Int
    let e2eP99Ms: Int
}

struct CostMetrics: Codable {
    let sttTotal: Decimal
    let ttsTotal: Decimal
    let llmInputTokens: Int
    let llmOutputTokens: Int
    let llmTotal: Decimal
    let totalSession: Decimal
}

struct QualityMetrics: Codable {
    let turnsTotal: Int
    let interruptions: Int
    let interruptionSuccessRate: Float
    let thermalThrottleEvents: Int
    let networkDegradations: Int
}

struct TranscriptEntry: Codable {
    let timestamp: Date
    let speaker: String
    let text: String
    let latencyMs: Int?
}

// MARK: - Extensions

extension Array where Element == TimeInterval {
    var median: TimeInterval {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ?
            (sorted[mid] + sorted[mid - 1]) / 2 :
            sorted[mid]
    }
    
    func percentile(_ p: Int) -> TimeInterval {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let index = Int(Double(sorted.count) * Double(p) / 100.0)
        return sorted[min(index, sorted.count - 1)]
    }
}

extension AVAudioPCMBuffer {
    func toData() -> Data {
        let audioBuffer = self.audioBufferList.pointee.mBuffers
        return Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }
}
```

---

## 10. UI/UX Design

*(Primary views covered in Section 5. Here's the main app structure)*

```swift
@main
struct UnaMentisApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        TabView {
            SessionView()
                .tabItem {
                    Label("Session", systemImage: "waveform")
                }
            
            CurriculumView()
                .tabItem {
                    Label("Curriculum", systemImage: "book")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            
            TelemetryDashboardView(telemetry: appState.telemetry)
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }
            
            ConfigurationView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

class AppState: ObservableObject {
    @Published var sessionManager: SessionManager
    @Published var curriculumEngine: CurriculumEngine
    @Published var telemetry: TelemetryEngine
    @Published var configManager: ConfigurationManager
    
    init() {
        // Initialize all managers
        // This would be more complex in practice with dependency injection
    }
}
```

---

## 11. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)

**Week 1: Core Audio & VAD**
- [ ] Set up Xcode project with SPM dependencies
- [ ] Implement AudioEngine with voice processing
- [ ] Integrate Silero VAD for Neural Engine
- [ ] Basic telemetry logging
- [ ] Test: Clean audio capture, VAD triggering

**Week 2: Provider Protocols & First Implementations**
- [ ] Define all provider protocols (STT, TTS, LLM, VAD)
- [ ] Implement AssemblyAI STT
- [ ] Implement Deepgram Aura-2 TTS
- [ ] Implement OpenAI LLM
- [ ] Provider factory pattern
- [ ] Test: Full STT â†’ LLM â†’ TTS pipeline

### Phase 2: Orchestration (Weeks 3-4)

**Week 3: SessionManager & Transport**
- [ ] Implement SessionManager state machine
- [ ] Integrate LiveKit transport
- [ ] Turn-taking logic
- [ ] Interruption handling
- [ ] Test: Complete conversation flows, interruptions

**Week 4: Curriculum System (Part 1)**
- [ ] Core Data models for Curriculum/Topic/Document
- [ ] CurriculumEngine basics
- [ ] Context generation for LLM
- [ ] Progress tracking
- [ ] Test: Context injection, progress updates

### Phase 3: UI & Configuration (Weeks 5-6)

**Week 5: Main UI Views**
- [ ] SessionView with live transcript
- [ ] CurriculumView with topic navigation
- [ ] HistoryView with session list
- [ ] Basic configuration UI
- [ ] Test: UI responsiveness, state updates

**Week 6: Advanced Configuration**
- [ ] Complete ConfigurationView
- [ ] All advanced settings panels
- [ ] Preset system
- [ ] API key management
- [ ] Test: Configuration persistence, preset switching

### Phase 4: Curriculum Features (Weeks 7-8)

**Week 7: Document Processing**
- [ ] PDF text extraction
- [ ] Document summarization
- [ ] File import UI
- [ ] Transcript import
- [ ] Test: Various document types

**Week 8: Online Resources**
- [ ] OpenStax provider
- [ ] Wikipedia provider
- [ ] Resource search UI
- [ ] Import from online sources
- [ ] Test: Search, import, topic creation

### Phase 5: Observability & Polish (Weeks 9-10)

**Week 9: Telemetry Dashboard**
- [ ] Real-time metrics display
- [ ] Latency charts
- [ ] Cost tracking UI
- [ ] Session export functionality
- [ ] Test: Metrics accuracy, export formats

**Week 10: Additional Providers**
- [ ] Deepgram STT implementation
- [ ] ElevenLabs TTS implementation
- [ ] Apple STT/TTS (on-device)
- [ ] Provider comparison testing
- [ ] Test: Provider switching, cost comparison

### Phase 6: Optimization & Testing (Weeks 11-12)

**Week 11: Performance Optimization**
- [ ] 90-minute session stability testing
- [ ] Memory leak detection and fixes
- [ ] Thermal management validation
- [ ] Network resilience testing
- [ ] Test: Extended sessions, poor network

**Week 12: Polish & Release Prep**
- [ ] Bug fixes from testing
- [ ] UI polish and animations
- [ ] Onboarding flow
- [ ] Documentation
- [ ] Test: Complete user flows

---

## 12. Testing Strategy

### Unit Tests

```swift
// Example test structure
class SessionManagerTests: XCTestCase {
    var sessionManager: SessionManager!
    var mockSTT: MockSTTService!
    var mockTTS: MockTTSService!
    var mockLLM: MockLLMService!
    
    override func setUp() async throws {
        mockSTT = MockSTTService()
        mockTTS = MockTTSService()
        mockLLM = MockLLMService()
        
        sessionManager = SessionManager(
            sttService: mockSTT,
            ttsService: mockTTS,
            llmService: mockLLM,
            // ...
        )
    }
    
    func testStartSession() async throws {
        try await sessionManager.startSession(topic: nil)
        XCTAssertEqual(sessionManager.state, .idle)
    }
    
    func testUserSpeaking() async throws {
        try await sessionManager.startSession(topic: nil)
        
        // Simulate VAD detection
        await sessionManager.handleUserStartedSpeaking()
        XCTAssertEqual(sessionManager.state, .userSpeaking)
    }
    
    func testInterruption() async throws {
        // Test interruption flow
    }
}
```

### Integration Tests

- Full STT â†’ LLM â†’ TTS pipeline
- Provider switching
- Curriculum context injection
- Session persistence
- Cost calculation accuracy

### Performance Tests

- Latency measurement (target <500ms E2E)
- Memory usage over 90-minute session
- Thermal behavior monitoring
- Network resilience (using Network Link Conditioner)

### UI Tests

```swift
class SessionViewUITests: XCTestCase {
    func testStartSession() throws {
        let app = XCUIApplication()
        app.launch()
        
        app.tabBars.buttons["Session"].tap()
        app.buttons["Start Session"].tap()
        
        // Verify UI state
        XCTAssertTrue(app.staticTexts["Listening"].exists)
    }
}
```

---

## 13. Performance Targets

### Latency Targets

| Component | Target (Median) | Acceptable (P99) |
|-----------|----------------|------------------|
| **STT** | <300ms | <1000ms |
| **LLM First Token** | <200ms | <500ms |
| **TTS TTFB** | <200ms | <400ms |
| **E2E Turn** | <500ms | <1000ms |

### Stability Targets

- **90-min Sessions:** 100% completion rate without crashes
- **Memory Growth:** <50MB over 90 minutes
- **Thermal Throttle:** <3 events per 90-min session
- **Interruption Success:** >90% successful interruptions

### Cost Targets

- **Balanced Preset:** <$3/hour per user
- **Cost-Optimized:** <$1.50/hour per user
- **At Scale (1000 hrs/mo):** 10x savings vs OpenAI Realtime

---

## Next Steps

### Immediate Actions (This Week)

1. **Set up Xcode project**
   - Create new iOS app project
   - Add SPM dependencies (LiveKit, Swift Log)
   - Set up Core Data schema

2. **Implement AudioEngine**
   - Basic AVAudioEngine setup
   - Voice processing configuration
   - VAD integration skeleton

3. **Define Provider Protocols**
   - STTService, TTSService, LLMService protocols
   - Provider factory pattern
   - Mock implementations for testing

4. **Create Basic UI Shell**
   - Tab structure
   - SessionView skeleton
   - CurriculumView skeleton

### First Sprint Goals (2 Weeks)

- Complete AudioEngine with Silero VAD
- Implement AssemblyAI STT
- Implement Deepgram Aura-2 TTS
- Basic SessionManager orchestration
- Console-based telemetry logging

### Success Criteria for MVP

âœ… Sub-600ms E2E latency on iPhone 16/17 Pro Max  
âœ… Successful interruption handling (>90% success rate)  
âœ… 90-minute session completion without crashes  
âœ… Cost <$3/hour for balanced preset  
âœ… Full transcript capture and export  
âœ… At least 3 provider options for STT, TTS, LLM  
âœ… Advanced configuration UI with all settings exposed  
âœ… Curriculum import from files and online sources  

---

**End of Technical Design Document**

This TDD provides a complete blueprint for building UnaMentis. Every component is designed to be:

- **Modular:** Swappable providers via protocols
- **Observable:** Comprehensive telemetry throughout
- **Configurable:** Every behavior tunable via settings
- **Learning-focused:** Curriculum management as core feature
- **Production-ready:** Targets real-world performance and stability

Ready to start building with Claude Code Sonnet 4.5! ðŸš€ 