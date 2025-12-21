# UnaMentis - TestFlight Distribution Guide

This document provides step-by-step instructions for distributing UnaMentis to beta testers via Apple's TestFlight platform.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Configuration](#project-configuration)
3. [App Store Connect Setup](#app-store-connect-setup)
4. [Building and Archiving](#building-and-archiving)
5. [Uploading to App Store Connect](#uploading-to-app-store-connect)
6. [TestFlight Configuration](#testflight-configuration)
7. [Adding Testers](#adding-testers)
8. [Managing Builds](#managing-builds)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts & Memberships

| Requirement | Status | Notes |
|-------------|--------|-------|
| Apple Developer Program | Required | $99/year - https://developer.apple.com/programs/ |
| App Store Connect access | Required | Comes with Developer Program membership |
| Apple ID with 2FA enabled | Required | Required for App Store Connect |

### Required Information

Before starting, gather the following:

| Item | Current Value | Notes |
|------|---------------|-------|
| Bundle Identifier | `com.unamentis.app` | Already configured in project |
| App Name | UnaMentis | Must be unique on App Store |
| SKU | `voicelearn-ios-001` | Your internal reference (any string) |
| Primary Language | English (U.S.) | Or your preferred language |
| App Category | Education | Primary category |
| Secondary Category | Lifestyle | Optional |

### Required Assets

You'll need to prepare these before uploading:

| Asset | Specification | Status |
|-------|---------------|--------|
| App Icon | 1024x1024 PNG, no alpha/transparency | Check `Assets.xcassets` |
| Screenshots (iPhone 6.7") | 1290 x 2796 pixels | Need to capture |
| Screenshots (iPhone 6.5") | 1284 x 2778 pixels | Optional but recommended |
| App Description | Up to 4000 characters | Need to write |
| Keywords | Up to 100 characters total | Need to define |
| Support URL | Valid URL | Need to provide |
| Privacy Policy URL | Valid URL | Required for apps with user data |

---

## Project Configuration

### 1. Verify Bundle Identifier

Your bundle identifier is already set to `com.unamentis.app`. Ensure this matches what you register in App Store Connect.

**Location:** UnaMentis.xcodeproj → UnaMentis target → Signing & Capabilities

### 2. Set Development Team

Currently your project shows `DEVELOPMENT_TEAM = "";` which needs to be configured.

1. Open `UnaMentis.xcodeproj` in Xcode
2. Select the **UnaMentis** target
3. Go to **Signing & Capabilities** tab
4. Under **Signing**, select your Team from the dropdown
5. Ensure "Automatically manage signing" is checked (recommended for simplicity)

### 3. Configure Version Numbers

**Current values in Info.plist:**
- `CFBundleShortVersionString`: 1.0 (marketing version shown to users)
- `CFBundleVersion`: 1 (build number, must increment for each upload)

**Version Strategy:**
- Marketing version (1.0, 1.1, 2.0): Change for user-visible updates
- Build number (1, 2, 3...): Increment for EVERY TestFlight upload

To update in Xcode:
1. Select the UnaMentis target
2. Go to **General** tab
3. Update **Version** and **Build** fields

### 4. Verify Entitlements

Your app uses these capabilities (already configured):
- Background Modes (audio)
- Local Networking (for self-hosted servers)

Ensure these are properly registered in your Developer Account:
1. Go to https://developer.apple.com/account/resources/identifiers
2. Find or create your App ID for `com.unamentis.app`
3. Enable required capabilities

### 5. Create Distribution Certificate (if needed)

1. Open Xcode → Settings → Accounts
2. Select your Apple ID
3. Select your Team
4. Click "Manage Certificates"
5. If no "Apple Distribution" certificate exists, click "+" and create one

---

## App Store Connect Setup

### 1. Access App Store Connect

Go to: https://appstoreconnect.apple.com

### 2. Create New App

1. Click **My Apps** in the dashboard
2. Click the **+** button → **New App**
3. Fill in the form:

| Field | Value |
|-------|-------|
| Platforms | iOS |
| Name | UnaMentis |
| Primary Language | English (U.S.) |
| Bundle ID | com.unamentis.app (select from dropdown after registering) |
| SKU | voicelearn-ios-001 |
| User Access | Full Access (or Limited if you want to restrict) |

4. Click **Create**

### 3. Register Bundle ID (if not in dropdown)

If your bundle ID doesn't appear in the dropdown:

1. Go to https://developer.apple.com/account/resources/identifiers
2. Click **+** to register a new identifier
3. Select **App IDs** → **App**
4. Enter:
   - Description: UnaMentis
   - Bundle ID: Explicit → `com.unamentis.app`
5. Enable capabilities:
   - [x] Background Modes
   - [x] (Any others your app needs)
6. Click **Continue** → **Register**
7. Return to App Store Connect and refresh the Bundle ID dropdown

### 4. Fill in App Information

After creating the app, complete these sections:

#### App Information Tab
- **Name:** UnaMentis
- **Subtitle:** (optional, up to 30 chars) e.g., "AI Voice Tutoring"
- **Category:** Education
- **Secondary Category:** Lifestyle (optional)
- **Content Rights:** Indicate if you have third-party content

#### Pricing and Availability Tab
- **Price:** Free (or your chosen price)
- **Availability:** Select countries/regions

#### App Privacy Tab
- **Privacy Policy URL:** Your privacy policy URL
- **Data Collection:** Complete the questionnaire about data your app collects:
  - Audio Data (for voice conversations)
  - Usage Data (if you track analytics)
  - Identifiers (if applicable)

---

## Building and Archiving

### 1. Select Destination

1. In Xcode, select the scheme **UnaMentis**
2. For destination, select **Any iOS Device (arm64)** (NOT a simulator)

### 2. Clean Build Folder

Menu: **Product** → **Clean Build Folder** (Shift+Cmd+K)

### 3. Archive the App

1. Menu: **Product** → **Archive**
2. Wait for the build to complete (may take several minutes)
3. The Organizer window will open automatically when done

### 4. Verify Archive

In the Organizer (Window → Organizer):
- Confirm the archive appears with correct version/build
- Check the date and time are correct

---

## Uploading to App Store Connect

### Method 1: Via Xcode Organizer (Recommended)

1. In Organizer, select your archive
2. Click **Distribute App**
3. Select **App Store Connect** → **Next**
4. Select **Upload** → **Next**
5. Choose distribution options:
   - [x] Upload your app's symbols (recommended for crash reports)
   - [x] Manage Version and Build Number (let Xcode handle it)
6. Select signing certificate and provisioning profile:
   - Automatically manage signing (recommended)
7. Click **Upload**
8. Wait for upload and processing (5-15 minutes)

### Method 2: Via Command Line (Advanced)

```bash
# Export archive to IPA
xcodebuild -exportArchive \
  -archivePath ~/Library/Developer/Xcode/Archives/[DATE]/UnaMentis.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath ./build

# Upload using altool
xcrun altool --upload-app \
  -f ./build/UnaMentis.ipa \
  -t ios \
  -u YOUR_APPLE_ID \
  -p YOUR_APP_SPECIFIC_PASSWORD
```

Create `ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

---

## TestFlight Configuration

### 1. Wait for Processing

After uploading:
1. Go to App Store Connect → My Apps → UnaMentis
2. Click **TestFlight** tab
3. Your build will show as "Processing" (typically 15-30 minutes)
4. Once processed, it will show a yellow "Missing Compliance" warning

### 2. Complete Export Compliance

For each new build:
1. Click on the build version
2. Under "Missing Compliance", click **Manage**
3. Answer the encryption questionnaire:
   - UnaMentis likely uses HTTPS only (standard encryption)
   - If only using HTTPS/TLS: Select "No" for custom encryption
4. Click **Start Internal Testing** (or **Save** for external)

### 3. Configure Test Information

Go to **TestFlight** → **Test Information** (in sidebar):

| Field | Description |
|-------|-------------|
| Beta App Description | What testers should know about this beta |
| Feedback Email | Where testers send feedback |
| Marketing URL | Optional link to your website |
| Privacy Policy URL | Required - link to privacy policy |
| Beta App Review Contact | Name, email, phone for Apple to contact |
| Sign-In Required | If app needs login, provide test credentials |

### 4. What to Test (Optional)

For each build, you can add specific testing instructions:
1. Click on the build
2. Click **Test Details**
3. Add "What to Test" instructions for testers

---

## Adding Testers

### Internal Testers (No Review Required)

Internal testers are members of your App Store Connect team (up to 100 people).

1. Go to **Users and Access** in App Store Connect (top nav)
2. Click **+** to add a new user
3. Assign roles:
   - **App Manager** - Full access including TestFlight
   - **Developer** - Can access TestFlight
   - **Marketing** - Can access TestFlight
4. Users must accept invitation and verify their Apple ID
5. Go to **TestFlight** → **Internal Testing**
6. Create a group or use "App Store Connect Users"
7. Add builds to the group

**Advantages:**
- No Apple review required
- Immediate access to builds
- Good for team members

### External Testers (Requires Initial Review)

External testers are anyone with an email address (up to 10,000 people).

1. Go to **TestFlight** → **External Testing**
2. Click **+** to create a new group (e.g., "Beta Testers")
3. Click **Add Testers**:
   - Enter email addresses manually, OR
   - Import from CSV file
4. Select which builds to include
5. Submit for **Beta App Review** (first build only, ~24-48 hours)

**Beta App Review Requirements:**
- App must not crash on launch
- Core functionality must work
- App description must be accurate
- Test credentials provided if needed

### Sending Invitations

Once a build is approved for external testing:
1. Testers receive email invitation automatically
2. They tap the link to open TestFlight app
3. If they don't have TestFlight, they're directed to download it
4. They tap "Accept" and can install your app

### Public Link (Optional)

Create a public link anyone can use to join:
1. Go to your external testing group
2. Enable **Public Link**
3. Set a tester limit (1-10,000)
4. Share the link

---

## Managing Builds

### Build Expiration

- **All TestFlight builds expire after 90 days**
- Testers will be notified before expiration
- Upload new builds regularly to keep testers engaged

### Incrementing Build Numbers

For each new upload:
1. Keep marketing version same (1.0) unless significant changes
2. Increment build number (1 → 2 → 3...)

**Quick update in Xcode:**
1. Select UnaMentis target
2. General tab → Build field
3. Increment the number

**Or via command line:**
```bash
# Increment build number
xcrun agvtool next-version -all

# Or set specific build number
xcrun agvtool new-version -all 42
```

### Automatic Build Distribution

To automatically distribute new builds to existing testers:
1. Go to TestFlight → Your testing group
2. Enable **Automatic Distribution**
3. New builds will be available to testers immediately after processing

### Viewing Crash Reports

1. Go to **TestFlight** → Select a build
2. Click **Crashes** tab
3. View crash logs and symbolicated stack traces

### Viewing Feedback

1. Go to **TestFlight** → **Feedback** (sidebar)
2. View screenshots and comments from testers
3. Testers can shake device in app to send feedback

---

## Troubleshooting

### Common Issues

#### "No accounts with App Store Connect access"
- Ensure your Apple ID is enrolled in Apple Developer Program
- Verify you accepted all agreements in App Store Connect

#### "No signing certificate found"
- Open Xcode → Settings → Accounts
- Select your team → Manage Certificates
- Create Apple Distribution certificate

#### "Bundle ID not registered"
- Register the identifier at developer.apple.com/account/resources/identifiers

#### Build stuck in "Processing"
- Processing typically takes 15-30 minutes
- If longer than 1 hour, try uploading again
- Check Apple System Status: https://developer.apple.com/system-status/

#### "Missing Compliance" warning
- Click on the build in TestFlight
- Complete the Export Compliance questionnaire
- For HTTPS-only apps, answer "No" to custom encryption

#### Beta App Review Rejection
- Common reasons:
  - App crashes on launch
  - Placeholder content
  - Incomplete features marked as complete
  - Missing privacy policy
- Fix issues and submit again (re-review is usually faster)

#### Testers can't install
- Verify tester email matches their Apple ID
- Ensure tester has iOS 15+ (check your deployment target)
- Have them delete and re-accept TestFlight invitation

### Getting Help

- Apple Developer Forums: https://developer.apple.com/forums/
- App Store Connect Help: https://developer.apple.com/help/app-store-connect/
- Contact Apple Developer Support: https://developer.apple.com/contact/

---

## Quick Reference Checklist

### First-Time Setup
- [ ] Apple Developer Program membership active ($99/year)
- [ ] App Store Connect agreements accepted
- [ ] Bundle ID registered (`com.unamentis.app`)
- [ ] App created in App Store Connect
- [ ] Development Team set in Xcode project
- [ ] Distribution certificate created
- [ ] App icon (1024x1024) added to asset catalog
- [ ] Privacy Policy URL ready

### For Each Build
- [ ] Increment build number
- [ ] Clean build folder
- [ ] Archive with "Any iOS Device" destination
- [ ] Upload via Xcode Organizer
- [ ] Wait for processing (~15-30 min)
- [ ] Complete Export Compliance
- [ ] Add "What to Test" notes (optional)
- [ ] Verify testers can download

### Adding New Testers
- [ ] For team members: Add as Internal Testers (no review)
- [ ] For others: Add as External Testers (requires initial review)
- [ ] Confirm they received invitation email
- [ ] Verify they have TestFlight app installed

---

## UnaMentis-Specific Notes

### Special Considerations

1. **Microphone Permission**: Testers will be prompted for microphone access on first use. Ensure they grant this permission.

2. **API Keys**: Testers need their own API keys for:
   - Anthropic Claude
   - OpenAI
   - ElevenLabs
   - Deepgram
   - AssemblyAI

   Consider providing test keys or instructions for obtaining them.

3. **Self-Hosted Servers**: If testers want to use local Ollama/llama.cpp servers, they need to be on the same network. This won't work for remote testers unless servers are exposed externally.

4. **Long Sessions**: Remind testers about the 60-90+ minute session target. Encourage testing extended conversations for stability.

5. **Background Audio**: The app uses background audio mode. Testers should verify sessions continue when the app is backgrounded.

### Recommended Test Instructions

Example "What to Test" content for builds:

```
UnaMentis Beta - What to Test

1. Voice Session Flow
   - Start a learning session
   - Verify microphone capture and AI responses
   - Test interruption handling (speak while AI is talking)

2. API Configuration
   - Add your API keys in Settings
   - Verify each provider works (Anthropic, OpenAI, etc.)

3. Long Session Stability
   - Run a 30+ minute session
   - Note any performance issues or crashes

4. Self-Hosted (if applicable)
   - Connect to local Ollama server
   - Verify model discovery works

Please report:
- Any crashes (automatic via TestFlight)
- Performance issues (lag, audio glitches)
- Feature requests

Feedback: shake device or email [your-email]
```

---

*Last updated: December 2024*
