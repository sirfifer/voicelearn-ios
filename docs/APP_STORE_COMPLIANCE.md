# UnaMentis iOS App Store Compliance & Security Guide

**Version:** 1.0
**Last Updated:** January 12, 2026
**Target Platform:** iOS 18.0+, TestFlight / App Store

This document provides a comprehensive review of UnaMentis's compliance with Apple's App Store Review Guidelines, privacy requirements, and security best practices. Use this as a living document to ensure ongoing compliance.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Critical Action Items](#critical-action-items)
3. [App Store Review Guidelines Compliance](#app-store-review-guidelines-compliance)
4. [Privacy Requirements](#privacy-requirements)
5. [Security Analysis](#security-analysis)
6. [Data Collection & Storage](#data-collection--storage)
7. [Third-Party Service Compliance](#third-party-service-compliance)
8. [AI/ML Compliance](#aiml-compliance)
9. [Network Security](#network-security)
10. [TestFlight Preparation Checklist](#testflight-preparation-checklist)
11. [App Store Submission Checklist](#app-store-submission-checklist)
12. [Ongoing Compliance Monitoring](#ongoing-compliance-monitoring)

---

## Executive Summary

### Overall Status: COMPLIANT

UnaMentis is a voice-based AI tutoring application that uses:
- Microphone access for speech-to-text
- Optional speech recognition (Apple on-device)
- Cloud AI services (OpenAI, Anthropic, Deepgram, ElevenLabs, AssemblyAI)
- Optional self-hosted local AI services
- On-device ML models (VAD, STT, LLM via llama.cpp)
- Core Data for local data persistence
- Keychain for secure API key storage

### Key Strengths
- Properly uses Keychain for sensitive API keys
- All cloud APIs use HTTPS/WSS (secure transport)
- Privacy-focused design with on-device ML options
- No third-party analytics or tracking SDKs
- No IDFA/advertising identifier usage
- Minimal data collection
- PrivacyInfo.xcprivacy manifest included
- Remote logging hardened for release builds

### Remaining Actions Before Submission
1. **[HIGH]** Add App Privacy nutrition labels in App Store Connect
2. **[MEDIUM]** Document data handling for third-party AI services
3. **[LOW]** Consider adding certificate pinning for cloud APIs

---

## Critical Action Items

### 1. PrivacyInfo.xcprivacy Manifest (REQUIRED)

**Status:** ✅ COMPLETE
**Location:** `UnaMentis/PrivacyInfo.xcprivacy`

Apple now requires a `PrivacyInfo.xcprivacy` file for apps using certain APIs. UnaMentis uses:
- `UserDefaults` (for settings storage)
- File timestamp APIs (Core Data)
- System boot time (potentially via ProcessInfo)

**Required Action:** Create the following file at `UnaMentis/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeAudioData</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### 2. Remote Logging Security (REQUIRED)

**Status:** ✅ COMPLETE
**Location:** `UnaMentis/Core/Logging/RemoteLogHandler.swift`

**Resolution:** All remote logging functions (`configure()`, `enable()`, `disable()`) are now wrapped in `#if DEBUG` guards. Remote logging is completely disabled in release builds and cannot be enabled programmatically.

**Current Behavior:**
```swift
init() {
    #if DEBUG
    _isEnabled = true
    #else
    _isEnabled = false  // ✓ Good - disabled by default
    #endif
}
```

**Risk:** The `RemoteLogging.enable()` function can enable logging in production.

**Required Actions:**
1. Add compile-time guard to prevent enabling in release:
```swift
public static func enable() {
    #if DEBUG
    RemoteLogHandler.isEnabled = true
    #else
    // No-op in release builds
    #endif
}
```

2. Ensure `RemoteLogging.configure()` also respects DEBUG flag
3. Remove any hardcoded IP addresses from production code

### 3. App Privacy Labels (REQUIRED)

When submitting to App Store Connect, declare the following:

| Data Type | Collected | Linked to User | Tracking |
|-----------|-----------|----------------|----------|
| Audio Data | Yes | No | No |
| User Content (transcripts) | Yes | No | No |
| Usage Data (session metrics) | Yes | No | No |
| Diagnostics | Yes | No | No |

**Note:** Data is stored locally only. When cloud AI services are used, audio/text is transmitted to third parties for processing but not stored by UnaMentis.

---

## App Store Review Guidelines Compliance

### Guideline 1.1 - App Completeness

| Requirement | Status | Notes |
|-------------|--------|-------|
| App must be complete | ✅ Pass | Core functionality works |
| No placeholder content | ✅ Pass | All features implemented |
| No hidden features | ✅ Pass | Debug views gated by DEBUG flag |

### Guideline 2.1 - App Functionality

| Requirement | Status | Notes |
|-------------|--------|-------|
| Works as advertised | ✅ Pass | Voice tutoring functions correctly |
| No crashes | ⚠️ Verify | Run full test suite before submission |
| Handles permissions gracefully | ✅ Pass | Proper permission prompts with descriptions |

### Guideline 2.3 - Accurate Metadata

| Requirement | Status | Notes |
|-------------|--------|-------|
| Screenshots match app | ⚠️ Todo | Create accurate screenshots |
| Description is accurate | ⚠️ Todo | Write accurate App Store description |
| Age rating appropriate | ✅ Pass | No objectionable content |

### Guideline 2.5 - Software Requirements

| Requirement | Status | Notes |
|-------------|--------|-------|
| Uses public APIs | ✅ Pass | No private API usage detected |
| No deprecated APIs | ✅ Pass | Using modern Swift 6 APIs |
| Background modes justified | ✅ Pass | Audio background mode for TTS playback |

### Guideline 4.2 - Minimum Functionality

| Requirement | Status | Notes |
|-------------|--------|-------|
| More than a website wrapper | ✅ Pass | Full native app with on-device ML |
| Provides value | ✅ Pass | Unique voice tutoring experience |

### Guideline 5.1 - Privacy

| Requirement | Status | Notes |
|-------------|--------|-------|
| Privacy policy required | ⚠️ Required | Must create and host privacy policy |
| Data collection disclosure | ⚠️ Required | Must declare in App Store Connect |
| Permission purpose strings | ✅ Pass | NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription present |
| PrivacyInfo.xcprivacy | ✅ Present | Created at UnaMentis/PrivacyInfo.xcprivacy |

### Guideline 5.1.1 - Data Collection and Storage

| Requirement | Status | Notes |
|-------------|--------|-------|
| Collect only necessary data | ✅ Pass | Only curriculum/session data |
| Store securely | ✅ Pass | Keychain for secrets, Core Data for app data |
| Delete on request capability | ⚠️ Consider | Add "Clear All Data" option in settings |

### Guideline 5.1.2 - Data Use and Sharing

| Requirement | Status | Notes |
|-------------|--------|-------|
| Disclose third-party sharing | ⚠️ Required | Must document AI service data sharing |
| Obtain consent | ✅ Pass | User initiates all API calls |

---

## Privacy Requirements

### Required Privacy Strings (Info.plist)

| Key | Value | Status |
|-----|-------|--------|
| NSMicrophoneUsageDescription | "UnaMentis needs microphone access for voice-based educational conversations." | ✅ Present |
| NSSpeechRecognitionUsageDescription | "UnaMentis uses speech recognition for voice commands." | ✅ Present |

### Privacy Manifest (PrivacyInfo.xcprivacy)

**Status:** ✅ PRESENT at `UnaMentis/PrivacyInfo.xcprivacy`

### App Tracking Transparency (ATT)

**Status:** NOT REQUIRED

UnaMentis does not:
- Use IDFA (Advertising Identifier)
- Track users across apps/websites
- Share data with data brokers
- Use third-party analytics that track users

Therefore, ATT prompt is NOT required.

### Data Minimization Compliance

| Data | Collected | Justification | Retention |
|------|-----------|---------------|-----------|
| Audio (microphone) | Yes - Streaming only | Core app functionality | Not stored - processed in real-time |
| Transcripts | Yes - Local | Session history feature | User-controlled deletion |
| Learning Progress | Yes - Local | Progress tracking feature | User-controlled deletion |
| API Keys | Yes - Keychain | Required for cloud services | User-controlled deletion |
| Usage Metrics | Yes - Local | Analytics view feature | Session-based, not persistent |

---

## Security Analysis

### API Key Management

**Location:** `UnaMentis/Core/Config/APIKeyManager.swift`

| Aspect | Status | Details |
|--------|--------|---------|
| Storage mechanism | ✅ Secure | Uses iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock` |
| Fallback mechanism | ⚠️ Caution | Falls back to UserDefaults if Keychain fails |
| Access control | ✅ Good | Actor-based isolation prevents race conditions |

**Recommendation:** Remove UserDefaults fallback in production or show warning to user.

### Network Security

| Aspect | Status | Details |
|--------|--------|---------|
| Cloud API transport | ✅ Secure | All use HTTPS or WSS |
| Certificate pinning | ❌ Not implemented | Consider for high-security scenarios |
| Local network | ⚠️ HTTP allowed | Intentional for self-hosted servers via NSAllowsLocalNetworking |

### Data at Rest

| Data | Encryption | Status |
|------|------------|--------|
| API Keys | iOS Keychain encryption | ✅ Secure |
| UserDefaults | iOS Data Protection | ✅ Secure (after first unlock) |
| Core Data | iOS Data Protection | ✅ Secure |
| Model files (GGUF) | None | ✅ OK - Not sensitive |

### Input Validation

| Component | Validation | Status |
|-----------|------------|--------|
| API responses | JSON decoding with Codable | ✅ Safe |
| User input (voice) | Processed by trusted STT services | ✅ Safe |
| Server URLs | URL validation | ✅ Safe |

### Potential Vulnerabilities

| Risk | Severity | Mitigation |
|------|----------|------------|
| API key exposure via logs | Medium | Ensure keys are never logged |
| Remote log data leakage | High | Disable in production (see Critical Actions) |
| Man-in-middle on local network | Low | Acceptable for self-hosted scenario |

---

## Data Collection & Storage

### Local Storage (Core Data)

**Database:** `UnaMentis.xcdatamodeld`

| Entity | Purpose | Sensitive |
|--------|---------|-----------|
| Curriculum | Learning materials | No |
| Topic | Topic structure | No |
| Document | Curriculum content | No |
| Session | Conversation sessions | Yes - Contains transcripts |
| TranscriptEntry | Conversation messages | Yes - User/AI conversation |
| TopicProgress | Learning progress | No |

**Security:** Core Data is stored in the app's sandbox and protected by iOS Data Protection.

### Keychain Storage

| Item | Purpose | Protection |
|------|---------|------------|
| OPENAI_API_KEY | OpenAI API access | kSecAttrAccessibleAfterFirstUnlock |
| ANTHROPIC_API_KEY | Anthropic API access | kSecAttrAccessibleAfterFirstUnlock |
| DEEPGRAM_API_KEY | Deepgram STT/TTS | kSecAttrAccessibleAfterFirstUnlock |
| ASSEMBLYAI_API_KEY | AssemblyAI STT | kSecAttrAccessibleAfterFirstUnlock |
| ELEVENLABS_API_KEY | ElevenLabs TTS | kSecAttrAccessibleAfterFirstUnlock |
| LIVEKIT_API_KEY | LiveKit WebRTC | kSecAttrAccessibleAfterFirstUnlock |
| LIVEKIT_API_SECRET | LiveKit WebRTC | kSecAttrAccessibleAfterFirstUnlock |

### UserDefaults Storage

| Key | Purpose | Sensitive |
|-----|---------|-----------|
| sttProvider | Selected STT provider | No |
| llmProvider | Selected LLM provider | No |
| ttsProvider | Selected TTS provider | No |
| primaryServerIP | Self-hosted server IP | No |
| selfHostedEnabled | Feature flag | No |
| TTS playback settings | Audio tuning | No |
| unamentis.server.configs | Server configurations | No |

---

## Third-Party Service Compliance

### Cloud AI Services

| Provider | Data Sent | Data Retention by Provider | Privacy Policy Required |
|----------|-----------|---------------------------|------------------------|
| OpenAI | Audio/Text | 30 days (API), shorter with opt-out | Yes - reference in app |
| Anthropic | Text | Per Anthropic policy | Yes - reference in app |
| Deepgram | Audio/Text | Per Deepgram policy | Yes - reference in app |
| ElevenLabs | Text | Per ElevenLabs policy | Yes - reference in app |
| AssemblyAI | Audio | Per AssemblyAI policy | Yes - reference in app |

**Required Action:** Create privacy policy that discloses data sharing with these providers when cloud services are selected.

### Self-Hosted Services (No Third-Party Data Sharing)

When using self-hosted services (Ollama, Whisper, Piper, VibeVoice), all data stays on user's local network:
- No data sent to external servers
- Full privacy mode available

**Recommendation:** Prominently advertise this as a privacy-focused option.

### SDK Dependencies

| SDK | Purpose | Privacy Impact |
|-----|---------|----------------|
| LiveKit Swift SDK | WebRTC transport | Minimal - peer-to-peer capable |
| Swift Log | Logging | None - local only |
| Swift Collections | Data structures | None |
| llama.cpp | On-device LLM | None - fully local |

---

## AI/ML Compliance

### Apple's AI/ML Guidelines

| Requirement | Status | Notes |
|-------------|--------|-------|
| On-device processing preferred | ✅ Available | VAD, STT, LLM all have on-device options |
| User control over AI features | ✅ Pass | User can choose cloud vs. local |
| Transparent AI usage | ✅ Pass | Clear labeling of AI features |
| No deceptive AI | ✅ Pass | AI is clearly an AI tutor, not human |

### Generative AI Disclosure

**Status:** ⚠️ RECOMMENDED

Apple recommends disclosing use of generative AI. UnaMentis uses:
- LLMs for tutoring responses (GPT-4, Claude, on-device models)
- TTS for voice synthesis

**Recommendation:** Add disclosure in app description and/or onboarding.

### Content Moderation

| Concern | Status | Notes |
|---------|--------|-------|
| Generated harmful content | Low risk | Educational context, no user-to-user interaction |
| Age-inappropriate content | Low risk | Educational focus |

---

## Network Security

### Endpoints Used

| Service | Endpoint | Protocol | Security |
|---------|----------|----------|----------|
| Anthropic | api.anthropic.com | HTTPS | ✅ TLS 1.2+ |
| OpenAI | api.openai.com | HTTPS | ✅ TLS 1.2+ |
| Deepgram STT | api.deepgram.com | WSS | ✅ TLS 1.2+ |
| Deepgram TTS | api.deepgram.com | HTTPS | ✅ TLS 1.2+ |
| ElevenLabs | api.elevenlabs.io | WSS | ✅ TLS 1.2+ |
| AssemblyAI | api.assemblyai.com | WSS | ✅ TLS 1.2+ |
| Self-hosted | configurable | HTTP | ⚠️ Local network only |

### App Transport Security (ATS)

**Info.plist Configuration:**
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

**Status:** ✅ Acceptable - Only allows HTTP for local network (self-hosted servers)

### Recommendations

1. **Certificate Pinning (Optional):** For highest security, implement certificate pinning for critical APIs:
   - OpenAI
   - Anthropic

2. **Network Reachability:** Already monitoring via Network.framework

---

## TestFlight Preparation Checklist

### Before First TestFlight Upload

- [ ] Create `PrivacyInfo.xcprivacy` file
- [ ] Disable remote logging in Release configuration
- [ ] Run full test suite (`xcodebuild test`)
- [ ] Test on physical device (not just simulator)
- [ ] Test all permission flows (microphone, speech recognition)
- [ ] Test error handling (no network, API errors)
- [ ] Verify all API keys can be entered and saved
- [ ] Test session persistence across app restarts
- [ ] Archive build and validate in Xcode Organizer
- [ ] Create App Store Connect listing (even for TestFlight)

### App Store Connect Setup

- [ ] Create app record
- [ ] Set bundle ID
- [ ] Configure app privacy declarations
- [ ] Upload app icon (1024x1024)
- [ ] Set age rating (likely 4+)
- [ ] Add TestFlight test information
- [ ] Invite internal testers

### Build Settings Verification

```
ENABLE_BITCODE = NO (deprecated)
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
SWIFT_OPTIMIZATION_LEVEL = -O (Release)
STRIP_SWIFT_SYMBOLS = YES
CODE_SIGN_IDENTITY = Apple Distribution
```

---

## App Store Submission Checklist

### Pre-Submission

- [ ] All TestFlight testing completed
- [ ] Crash-free rate > 99.5%
- [ ] Privacy policy hosted at accessible URL
- [ ] Terms of service (if applicable)
- [ ] Support URL configured
- [ ] Marketing website (optional but recommended)

### App Store Connect Metadata

- [ ] App name and subtitle
- [ ] Description (4000 char max)
- [ ] Keywords (100 char max)
- [ ] Screenshots for all device sizes
- [ ] App preview videos (optional)
- [ ] What's New text (for updates)

### Privacy Declarations

- [ ] Data types collected
- [ ] Data linked to user (none for UnaMentis)
- [ ] Data used for tracking (none for UnaMentis)
- [ ] Third-party data sharing disclosed

### Review Notes

Prepare notes for App Review team explaining:
1. How to test the app (provide test API keys if needed)
2. Explanation of microphone usage
3. Explanation of cloud AI services
4. Note about self-hosted option for privacy

---

## Ongoing Compliance Monitoring

### Regular Checks

| Check | Frequency | Action |
|-------|-----------|--------|
| SDK updates | Monthly | Review for security patches |
| API provider policy changes | Quarterly | Update privacy policy if needed |
| Apple guideline updates | At each iOS release | Review compliance |
| Privacy manifest updates | With each SDK update | Ensure still accurate |

### Automated Checks

1. **Xcode Analysis:** Run `Analyze` before each release
2. **Privacy Report:** Generate and review Privacy Report in Xcode
3. **Dependency Audit:** Use `swift package show-dependencies` to audit

### Version Control

- Keep this document in version control
- Update with each release
- Track compliance changes

---

## Appendix A: Relevant Apple Documentation

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Human Interface Guidelines - Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
- [Security Overview](https://developer.apple.com/documentation/security)

## Appendix B: Contact Information

- **Apple Developer Support:** developer.apple.com/contact
- **App Review:** Contact via App Store Connect resolution center
- **Privacy Questions:** Contact Apple Legal if needed

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2024-12-21 | Automated Review | Initial comprehensive review |

---

*This document should be reviewed and updated before each App Store submission.*
