# App Store Compliance Guide

Guide for preparing UnaMentis for App Store submission.

## Current Status

**Overall Status:** CONDITIONALLY COMPLIANT

Pre-submission actions remain. See the full documentation for details.

## Key Strengths

- Properly uses Keychain for sensitive API keys
- All cloud APIs use HTTPS/WSS (secure transport)
- Privacy-focused design with on-device ML options
- No third-party analytics or tracking SDKs
- No IDFA/advertising identifier usage
- Minimal data collection
- PrivacyInfo.xcprivacy manifest included
- Remote logging hardened for release builds

## Critical Requirements

### 1. Privacy Manifest (Complete)

The `PrivacyInfo.xcprivacy` file is located at `UnaMentis/PrivacyInfo.xcprivacy`.

UnaMentis declares:
- Audio data collection for app functionality
- UserDefaults access for settings storage
- File timestamp APIs for Core Data

### 2. Remote Logging Security (Complete)

All remote logging functions are wrapped in `#if DEBUG` guards. Remote logging is completely disabled in release builds.

### 3. App Privacy Labels (Required)

When submitting to App Store Connect, declare:

| Data Type | Collected | Linked to User | Tracking |
|-----------|-----------|----------------|----------|
| Audio Data | Yes | No | No |
| User Content (transcripts) | Yes | No | No |
| Usage Data (session metrics) | Yes | No | No |
| Diagnostics | Yes | No | No |

## TestFlight Checklist

Before first TestFlight upload:

- [ ] Create PrivacyInfo.xcprivacy file
- [ ] Disable remote logging in Release configuration
- [ ] Run full test suite
- [ ] Test on physical device
- [ ] Test all permission flows
- [ ] Verify API keys can be entered and saved
- [ ] Test session persistence
- [ ] Archive and validate in Xcode Organizer
- [ ] Create App Store Connect listing

## App Store Submission Checklist

Pre-submission requirements:

- [ ] All TestFlight testing completed
- [ ] Crash-free rate > 99.5%
- [ ] Privacy policy hosted at accessible URL
- [ ] Support URL configured
- [ ] App description and metadata
- [ ] Screenshots for all device sizes

## Third-Party Service Compliance

| Provider | Data Sent | Privacy Policy Required |
|----------|-----------|------------------------|
| OpenAI | Audio/Text | Yes |
| Anthropic | Text | Yes |
| Deepgram | Audio/Text | Yes |
| ElevenLabs | Text | Yes |
| AssemblyAI | Audio | Yes |

## Privacy Modes

**Maximum Privacy (On-Device):**
- STT: Apple Speech Recognition
- TTS: AVSpeechSynthesizer
- LLM: On-device models
- No data leaves the device

**Self-Hosted:**
- All processing on your local network
- Full privacy mode available

## Full Documentation

See `docs/APP_STORE_COMPLIANCE.md` for the complete compliance guide including:
- Detailed App Store Review Guidelines compliance checklist
- Security analysis
- Network security requirements
- AI/ML compliance guidelines
- Ongoing compliance monitoring

---

Back to [[Tools]] | [[Home]]
