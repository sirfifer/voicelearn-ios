# UnaMentis Prompts

This directory contains prompts for AI-assisted workflows.

## Technology Scouting

| File | Purpose | Frequency |
|------|---------|-----------|
| [daily-tech-scout.md](daily-tech-scout.md) | AI models & voice tech scouting (STT, TTS, LLM) | Weekly |
| [tech-scout-quick.md](tech-scout-quick.md) | Quick daily tech check + RSS feeds | Daily |
| [daily-code-quality-scout.md](daily-code-quality-scout.md) | Code quality tools & practices scouting | Weekly |
| [FINDINGS_TEMPLATE.md](FINDINGS_TEMPLATE.md) | Template for documenting findings | Per scout run |

### Workflow

1. **Daily (2-3 min):** Run the quick tech scout or check RSS feeds
2. **Weekly (15-20 min):** Run the full tech scout prompt (AI models, voice tech)
3. **Weekly (10-15 min):** Run the code quality scout prompt (dev tools, testing)
4. **After each run:** Create GitHub issues for actionable items

### Recommended Tools

- **Perplexity Pro** - Best for comprehensive web search
- **Claude with web search** - Good for analysis and recommendations
- **Feedly/Inoreader** - For RSS feed monitoring
- **GitHub Actions** - For automation (see below)

### Automation (Optional)

To automate daily scouting with Claude API:

```python
# scripts/tech_scout.py
import anthropic
from datetime import datetime

client = anthropic.Anthropic()

with open("prompts/daily-tech-scout.md") as f:
    prompt = f.read()

# Extract just the prompt section
# ... implementation details ...

message = client.messages.create(
    model="claude-sonnet-4-20250514",
    max_tokens=4096,
    messages=[{"role": "user", "content": prompt}]
)

# Save to findings/YYYY-MM-DD.md
# ... implementation details ...
```

### Categories Monitored

#### Tech Scout (AI Models & Voice Tech)

**AI Services:**
- **STT:** AssemblyAI, Deepgram, Groq, Whisper, Vosk, Sherpa-ONNX
- **TTS:** Deepgram Aura, ElevenLabs, Chatterbox, Piper
- **LLM:** Claude, GPT, Llama, Gemma, Phi, Qwen
- **VAD:** Silero, WebRTC VAD, turn-taking detection

**Platforms:**
- **iOS:** Swift, Core ML, MLX, AVFoundation
- **Android:** Kotlin, TensorFlow Lite, NNAPI, MediaPipe, Oboe
- **Server:** Python/aiohttp, Next.js/React, WebSockets

**Other:**
- **Educational:** OER sources, curriculum standards, AI tutoring research
- **Infrastructure:** WebRTC, LiveKit, caching, vector databases

#### Code Quality Scout (Dev Tools & Practices)

**Traditional Tooling:**
- **Static Analysis:** SwiftLint, Ruff, ESLint, ktlint, Semgrep
- **Testing:** XCTest, pytest, Vitest, property-based testing
- **Coverage:** xccov, pytest-cov, mutation testing (Muter, mutmut, Stryker)
- **Security:** Gitleaks, CodeQL, dependency scanning
- **CI/CD:** GitHub Actions optimization, caching, parallelization

**AI-Assisted Tooling:**
- **AI Review:** CodeRabbit, GitHub Copilot, specialized reviewers
- **AI Testing:** Test generation, fuzz testing, edge case discovery
- **AI Refactoring:** Tech debt detection, code smell analysis
- **AI Docs:** Documentation generation, API docs
- **AI Debug:** Log analysis, root cause detection
