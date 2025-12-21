# UnaMentis - Debug & Testing UI

UnaMentis includes built-in debugging and testing tools accessible from the Settings screen. These tools help validate subsystems independently before running full voice sessions.

## Accessing Debug Tools

Navigate to **Settings > Debug & Testing** to access:

1. **Subsystem Diagnostics** - System health checks
2. **Audio Pipeline Test** - Microphone, VAD, and TTS testing
3. **Provider Connectivity** - API connection verification

## Subsystem Diagnostics

The Diagnostics view provides a comprehensive system health check:

### Audio Engine Checks
- **Audio Session** - Verifies voice chat mode is available
- **Microphone Access** - Checks permission status (granted/denied/undetermined)
- **VAD Service** - Confirms Silero VAD is ready

### API Connectivity Checks
- **STT Service** - Verifies Deepgram or AssemblyAI API key configured
- **TTS Service** - Verifies ElevenLabs or Deepgram API key configured
- **LLM Service** - Verifies Anthropic or OpenAI API key configured

### System Checks
- **Thermal State** - Current device thermal status (nominal/fair/serious/critical)
- **Memory Usage** - Application memory status

### Usage

1. Tap **Run All Diagnostics** to check all systems
2. Review results:
   - ✅ Green checkmark = OK
   - ⚠️ Yellow warning = Potential issue
   - ❌ Red X = Error/Not configured

## Audio Pipeline Test

Test the audio capture and playback pipeline independently:

### Microphone Test
- **Start Recording** - Begin capturing audio from microphone
- **Audio Level Meter** - Real-time visualization of input levels
- **Stop Recording** - End capture and save for playback
- **Play Back** - Listen to recorded audio

### VAD Test
- **Speech Detected** - Live indicator showing VAD results
- **Confidence** - Numeric confidence score (0.0 - 1.0)

This helps verify:
- Microphone permissions are working
- Audio levels are appropriate
- VAD is detecting speech correctly

### TTS Test
- Enter custom text to synthesize
- **Speak** button plays audio through configured TTS provider
- Verifies TTS API connectivity and audio playback

## Provider Connectivity

Test individual API providers to verify configuration:

### STT Providers
- **Deepgram** - Tests Deepgram STT API
- **AssemblyAI** - Tests AssemblyAI STT API

### TTS Providers
- **ElevenLabs** - Tests ElevenLabs TTS API
- **Deepgram Aura** - Tests Deepgram TTS API

### LLM Providers
- **Anthropic Claude** - Tests Anthropic API
- **OpenAI** - Tests OpenAI API

### Results
Each test shows:
- **Latency** - Response time in milliseconds (e.g., "150ms")
- **No API key** - API key not configured
- **Error message** - Connection or authentication failure

### Usage

1. Tap **Test** next to individual providers
2. Or tap **Test All Providers** to check everything
3. Configure missing API keys in Settings > API Keys

## Debug Settings

Additional debug options in Settings:

- **Debug Mode** - Enables additional logging and debug overlays
- **Verbose Logging** - Increases log detail level

## Troubleshooting Workflow

When voice sessions aren't working:

1. **Run Diagnostics First**
   - Check all systems are green
   - Fix any red/yellow items

2. **Test Audio Pipeline**
   - Verify microphone captures audio
   - Confirm VAD detects speech
   - Test TTS playback works

3. **Test Provider Connectivity**
   - Verify each API responds
   - Note latency values
   - Fix any connection errors

4. **Check API Keys**
   - Ensure all required keys are configured
   - Verify keys are valid (not expired/revoked)

## Implementation Details

The debug UI is implemented in `UnaMentis/UI/Settings/SettingsView.swift`:

- `DiagnosticsView` - System diagnostics
- `DiagnosticsViewModel` - Diagnostic logic
- `AudioTestView` - Audio pipeline testing
- `AudioTestViewModel` - Audio test logic
- `ProviderTestView` - Provider connectivity tests
- `ProviderTestViewModel` - Provider test logic

These views use real service implementations where possible, with simulated responses only when actual API calls would be inappropriate for quick testing.
