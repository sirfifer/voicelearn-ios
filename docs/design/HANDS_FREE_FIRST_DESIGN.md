# Hands-Free First Design

**Version:** 1.0
**Last Updated:** January 2026
**Status:** Mandatory for Voice-Centric Activities

This document defines the "Hands-Free First" design principle for UnaMentis. All voice-centric activities (oral practice, learning sessions, quiz modes) must adhere to these guidelines.

---

## Table of Contents

1. [Core Philosophy](#1-core-philosophy)
2. [Two-Tier Voice Interaction Model](#2-two-tier-voice-interaction-model)
3. [Activity-Mode Voice-First (Tier 1)](#3-activity-mode-voice-first-tier-1)
4. [App-Wide Voice Navigation (Tier 2)](#4-app-wide-voice-navigation-tier-2)
5. [Unified Command Vocabulary](#5-unified-command-vocabulary)
6. [Accessibility Compliance](#6-accessibility-compliance)
7. [Audio Feedback Design](#7-audio-feedback-design)
8. [Performance Requirements](#8-performance-requirements)
9. [Testing Checklist](#9-testing-checklist)

---

## 1. Core Philosophy

**Hands-Free First** means voice is the PRIMARY interaction mode within activities, not an accessibility add-on or secondary option.

### Key Principles

1. **Prioritization, Not Exclusivity**
   - Voice is primary; visual UI remains fully functional
   - Buttons are helpful, not required
   - Users choose their preferred interaction style

2. **Context-Specific Activation**
   - Entering a voice-centric activity automatically enables voice-first mode
   - No toggle or setting needed for activity mode
   - Natural transition from visual navigation to voice interaction

3. **Natural Language Where Possible**
   - Accept variations: "ready", "I'm ready", "let's go"
   - Don't require rigid command syntax
   - Keywords as fallback, not primary interface

4. **Seamless Experience**
   - Users should never feel "mode switching"
   - Accessibility users and non-accessibility users have identical voice experiences
   - Commands work identically everywhere

---

## 2. Two-Tier Voice Interaction Model

UnaMentis implements voice interaction in two distinct tiers:

### Tier 1: Activity-Mode Voice-First (Primary)

**Scope:** Within voice-centric activities (oral practice, learning sessions, quizzes)

**Activation:** Automatic upon entering the activity

**Goal:** Complete the entire activity without touching the screen

**Use Cases:**
- Practicing while driving
- Hands-busy scenarios (cooking, exercising)
- Extended learning sessions

### Tier 2: App-Wide Voice Navigation (Secondary, Future)

**Scope:** Navigation, settings, browsing, activity selection

**Activation:** Opt-in via Accessibility settings

**Goal:** Full app control for vision-impaired users

**Use Cases:**
- Vision-impaired users
- Complete hands-free app usage
- Accessibility compliance

### The Boundary

| User Action | Tier | Activation |
|-------------|------|------------|
| Browsing curriculum | Tier 2 | Opt-in setting |
| Entering oral practice | Tier 1 | Automatic |
| Answering questions | Tier 1 | Automatic |
| Exiting to home | Tier 2 | Opt-in setting |

---

## 3. Activity-Mode Voice-First (Tier 1)

### Automatic Activation

When a user enters a voice-centric activity:
1. STT begins listening for commands immediately
2. No toggle or confirmation needed
3. Visual UI remains but is secondary
4. All state transitions have voice alternatives

### State-Based Commands

Each activity state accepts specific voice commands:

**Example: Oral Practice Session**

| State | Voice Commands | Action |
|-------|---------------|--------|
| Not Started | "start", "begin", "let's go", "ready" | Start session |
| Reading Question | "skip" | Skip TTS to conference |
| Conference Time | "ready", "I'm ready" | Skip to answering |
| Listening for Answer | "submit", "done", "skip" | Submit or skip |
| Showing Feedback | "next", "continue" | Advance |
| Completed | "done", "exit" | Dismiss |

### Continuous Command Listening

During activities:
- STT runs continuously in command detection mode
- Low-latency transcription for immediate response
- Seamless transition between command and content capture
- Commands recognized at contextually appropriate moments

### Answer Completion Detection

For answer capture states:
1. Listen for explicit "submit" or "done" command
2. Extended silence (2.5s) triggers auto-submit
3. Audio confirmation before evaluation
4. Natural speech patterns honored (no premature cutoff)

---

## 4. App-Wide Voice Navigation (Tier 2)

*Note: Tier 2 is future work. This section documents the design for forward compatibility.*

### Accessibility Setting

```
Settings > Accessibility > Voice Navigation
  [ ] Enable Voice Navigation
      Level: [Basic] [Full]
```

**Basic Level:**
- Navigation commands (next, back, select)
- Menu item selection by name

**Full Level:**
- All interactions (forms, toggles, text input)
- Complete hands-free operation

### Command Consistency

All Tier 2 commands must use the same vocabulary as Tier 1:
- "Next" navigates forward (same as activity "next")
- "Back" or "go back" returns (same as activity "exit")
- "Select" activates items (same as activity "ready")

This ensures users with Tier 2 enabled experience seamless transitions.

---

## 5. Unified Command Vocabulary

All voice commands use a single, unified vocabulary. This ensures:
- No relearning between contexts
- Accessibility users have seamless experience
- Commands feel natural and consistent

### Core Commands

| Command | Phrases | Meaning |
|---------|---------|---------|
| **ready** | "ready", "I'm ready", "let's go", "go ahead", "start" | Proceed/confirm |
| **submit** | "submit", "that's my answer", "done", "final answer" | Submit current input |
| **next** | "next", "continue", "next question", "move on" | Advance forward |
| **skip** | "skip", "pass", "I don't know", "no idea" | Skip current item |
| **repeat** | "repeat", "say again", "what was that", "repeat question" | Replay last audio |
| **quit** | "quit", "stop", "end", "exit", "go back" | Exit/cancel |

### Command Recognition Strategy

Commands are recognized WITHOUT LLM, using local matching:

1. **Exact Match** (Confidence: 1.0)
   - Normalize input (lowercase, trim whitespace)
   - Direct string comparison

2. **Phonetic Match** (Confidence: 0.9)
   - Double Metaphone algorithm
   - Catches STT transcription errors ("reddy" -> "ready")

3. **Token Similarity** (Confidence: 0.8)
   - Jaccard similarity > 0.7
   - Handles partial matches ("I'm ready to go" contains "ready")

4. **Confidence Threshold**
   - Minimum 0.75 to trigger command
   - Below threshold: treat as content, not command

### Context-Aware Filtering

Not all commands are valid in all states:
- "submit" only valid when answer expected
- "next" only valid after feedback shown
- Invalid commands produce subtle audio feedback, not errors

---

## 6. Accessibility Compliance

**All voice-first work MUST follow accessibility standards**, regardless of whether it's "for accessibility" or not.

### Non-Negotiable Requirements

1. **VoiceOver Compatibility**
   - Voice commands work alongside VoiceOver
   - No conflicts with VoiceOver gestures
   - Accessibility labels describe voice command availability

2. **Audio Has Visual Equivalents**
   - Every audio announcement has on-screen text
   - Countdown milestones shown visually too
   - Deaf users can follow along

3. **Haptic Feedback**
   - All audio cues have haptic equivalents
   - State changes produce tactile feedback
   - Works with sound off

4. **Dynamic Type**
   - Voice command feedback scales with system text size
   - No fixed font sizes

### Seamless Transitions

Users with Tier 2 (full voice nav) enabled should feel no difference when:
- Entering an activity (Tier 1 takes over)
- Exiting an activity (Tier 2 resumes)
- Commands work identically in both contexts

---

## 7. Audio Feedback Design

### Principles

1. **Informative, Not Intrusive**
   - Announce state changes clearly
   - Don't over-narrate obvious actions
   - Respect user's attention

2. **Milestone-Based, Not Continuous**
   - Countdown at key points (30s, 15s, 10s, 5-1)
   - Not constant ticking
   - Allow focused thinking time

3. **Immediate Confirmation**
   - Command recognition within 300ms
   - Audio feedback within 100ms of recognition
   - User knows action was received

### Announcement Types

| Type | Method | Example |
|------|--------|---------|
| State Change | TTS | "Conference time. 30 seconds." |
| Milestone | TTS (brief) | "15 seconds" |
| Countdown | System sound | Tick at 5, 4, 3, 2, 1 |
| Command Recognized | System sound | Subtle chime |
| Correct Answer | TTS + Sound | Chime + "Correct!" |
| Incorrect Answer | TTS | "The answer was [X]" |

### Audio During Conference Time

Non-distracting countdown approach:

```
0:30  "Conference time. 30 seconds."
0:15  "15 seconds"
0:10  "10 seconds"
0:05  [tick] + haptic
0:04  [tick] + haptic
0:03  [tick] + haptic
0:02  [tick] + haptic
0:01  [tick] + haptic
0:00  "Time. Ready to answer."
```

---

## 8. Performance Requirements

### Latency Targets

| Operation | Target | Maximum |
|-----------|--------|---------|
| Command Recognition | < 200ms | 300ms |
| Audio Feedback | < 100ms | 200ms |
| State Transition | < 50ms | 100ms |
| Answer Submission | < 100ms | 200ms |

### Resource Constraints

- Continuous STT: Acceptable battery impact during activities
- Memory: Clean up STT buffers between states
- CPU: Phonetic matching is O(n) per phrase; pre-compute codes

### Reliability

- Command recognition must work in noisy environments
- False positive rate < 5% (avoid accidental commands)
- False negative rate < 10% (recognize clear commands)

---

## 9. Testing Checklist

### Unit Tests

- [ ] Command recognition: exact, phonetic, token matches
- [ ] Confidence thresholds respected
- [ ] State-valid command filtering
- [ ] Phrase variations recognized

### Integration Tests

- [ ] Complete activity using only voice
- [ ] Audio announcements at correct times
- [ ] State transitions via voice commands
- [ ] Silence-based auto-submit

### Accessibility Tests

- [ ] VoiceOver enabled: voice commands still work
- [ ] Audio feedback has visual equivalents
- [ ] Haptic feedback works with sound off
- [ ] Dynamic Type scaling verified

### Manual Tests

- [ ] Complete 10-question session hands-free
- [ ] Test all command variations
- [ ] Test in car simulation (noise, road sounds)
- [ ] Verify feedback timing feels natural

### Consistency Tests

- [ ] Document all recognized commands
- [ ] Verify same commands work in all contexts
- [ ] Test transition between Tier 1 and Tier 2 (when implemented)

---

## Appendix: Related Documents

- [IOS_STYLE_GUIDE.md](../ios/IOS_STYLE_GUIDE.md) - iOS accessibility and audio-first requirements
- [SPEAKER_MIC_BARGE_IN_DESIGN.md](../ios/SPEAKER_MIC_BARGE_IN_DESIGN.md) - Echo cancellation and barge-in
- [CLAUDE.md](../../CLAUDE.md) - Project-wide development guidelines
