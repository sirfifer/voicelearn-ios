# Voice Lab - Management Console Guide

## Overview

The **Voice Lab** is a dedicated section in the UnaMentis management console for all TTS and voice-related functionality. It consolidates AI model selection, TTS experimentation, and batch processing configuration into a single unified workspace.

## Accessing Voice Lab

**Web Console:** http://localhost:3000/?section=voicelab

The Voice Lab appears as a third top-level section in the management console navigation, alongside **Operations** and **Content**.

## Structure

The Voice Lab section contains three tabs:

### 1. AI Model Selection

**Purpose:** Compare and select AI models for all use cases

**Features:**
- On-Device LLM comparison (SmolLM3-3B vs Llama 3.2 1B for KB validation)
- Server LLM comparison (Qwen3-235B, DeepSeek-V3, Llama 3.3 70B for tutoring)
- Server TTS comparison (Fish Speech V1.5, Kyutai TTS 1.6B, IndexTTS-2, VibeVoice)
- On-Device TTS comparison (Kyutai Pocket TTS, NeuTTS Air, Kokoro-82M)

**Model Information Displayed:**
- Release date and version
- Parameters and model size
- Performance benchmarks
- Feature lists
- Deployment requirements
- License information
- Status badges (RECOMMENDED, CURRENT, OUTDATED)

**Workflow:**
1. Select use case tab (On-Device LLM, Server LLM, Server TTS, On-Device TTS)
2. Review model cards with full specifications
3. Compare benchmarks and features
4. Click external links for detailed documentation
5. Make informed decisions based on latest 2026 research

**Documentation:** See `docs/AI_MODEL_SELECTION_2026.md` for detailed model analysis

### 2. TTS Lab (Experimentation)

**Purpose:** Test TTS models and configurations before batch processing

**Features:**
- **Configure Tab:**
  - Model selection (Kyutai TTS 1.6B, Pocket TTS, Fish Speech V1.5)
  - Voice selection (40+ voices for TTS 1.6B, 8 for Pocket TTS)
  - Configuration parameters ("nerd knobs"):
    - cfg_coef (1.0-5.0) - Voice adherence
    - n_q (8-32) - Quality levels
    - padding_between (0-5) - Word articulation
    - padding_bonus (-3 to 3) - Speech speed
    - temperature (0.1-2.0) - Variation
    - top_p (0.1-1.0) - Nucleus sampling
  - Test text input with duration estimation
  - Generate button for creating test samples

- **Compare Tab:**
  - Side-by-side audio sample comparison
  - Audio players for each generated sample
  - Configuration details for each sample
  - Copy/download actions
  - Clear all functionality

- **Batch Settings Tab:**
  - Batch size configuration (parallel generations)
  - Configuration summary
  - Save for batch processing
  - Reset to defaults
  - Pipeline overview

**Workflow:**
1. Navigate to TTS Lab tab
2. Select model and voice
3. Adjust "nerd knobs" to tune generation
4. Generate test samples with different settings
5. Compare audio quality side-by-side
6. Save optimal configuration for batch use
7. Use saved config in batch processing pipeline

**API Endpoints:**
- `GET /api/tts-lab/models` - List supported models
- `POST /api/tts-lab/generate` - Generate test audio
- `POST /api/tts-lab/config` - Save configuration
- `GET /api/tts-lab/configs` - List saved configurations
- `POST /api/tts-lab/validate` - Validate configuration

**Documentation:** See `docs/server/TTS_LAB_GUIDE.md` for complete guide

### 3. Batch Profiles

**Purpose:** Manage TTS profiles for batch audio generation

**Features:**
- Create and edit TTS generation profiles
- Configure voice, speed, pitch, quality settings
- A/B testing and comparison tools
- Batch job management
- Rating and quality assessment

**Use Cases:**
- Pre-generate audio for thousands of Knowledge Bowl questions
- Batch process Quiz Ball content
- Pre-cache curriculum audio
- Generate FOV context audio

**Workflow:**
1. Create profile with specific TTS settings
2. Test with sample questions
3. Run A/B comparison with different profiles
4. Rate and select best profile
5. Launch batch job for production
6. Monitor progress and quality

**API Integration:**
- Uses saved configurations from TTS Lab
- Integrates with `tts_pregen_api.py` for batch processing
- Connects to TTS cache system for storage

## Navigation

### Section Navigation (Top Level)

Click on section tabs to switch between:
- **Operations** (MonitorCog icon) - System health, metrics, services
- **Content** (Library icon) - Curricula, modules, sources
- **Voice Lab** (Volume2 icon) - AI models, TTS experiments, profiles

### Tab Navigation (Within Voice Lab)

Three tabs within Voice Lab:
- **AI Model Selection** (FlaskConical icon) - Model comparison and selection
- **TTS Experimentation** (Settings icon) - Test and tune TTS configurations
- **Batch Profiles** (Mic icon) - Manage batch processing profiles

### URL State

The management console uses URL query parameters to maintain state:

```
http://localhost:3000/?section=voicelab&tab=tts-lab
```

- `section=voicelab` - Voice Lab section
- `tab=model-selection` - AI Model Selection tab
- `tab=tts-lab` - TTS Experimentation tab
- `tab=tts-profiles` - Batch Profiles tab

This allows bookmarking specific tabs and sharing links to specific views.

## Integration with Server APIs

### AI Model Selection
- Reads from `/app/management/models/page.tsx` (Next.js route)
- Displays data from `docs/AI_MODEL_SELECTION_2026.md`
- No server API (static Next.js page with model information)

### TTS Lab
- Reads from `/app/management/tts-lab/page.tsx` (Next.js route)
- Backend: `server/management/tts_lab_api.py`
- Endpoints registered in `server/management/server.py`
- Configuration storage: `server/management/tts_lab_configs/`

### Batch Profiles
- Component: `src/components/tts-pregen/profiles-panel.tsx`
- Backend: `server/management/tts_pregen_api.py`
- Database integration for profile storage
- Job queue for batch processing

## Development

### File Structure

```
server/web/
├── app/management/                    # Next.js routes (isolated pages)
│   ├── models/page.tsx                # AI Model Selection page
│   └── tts-lab/page.tsx               # TTS Lab page
├── src/
│   ├── app/                           # Main Next.js app
│   │   └── page.tsx                   # Root dashboard
│   └── components/
│       ├── dashboard/
│       │   ├── dashboard.tsx          # Main dashboard component
│       │   ├── nav-tabs.tsx           # Section/tab navigation
│       │   ├── model-selection-panel.tsx  # AI Model Selection wrapper
│       │   └── tts-lab-panel.tsx      # TTS Lab wrapper
│       └── tts-pregen/
│           └── profiles-panel.tsx     # Batch Profiles component

server/management/
├── server.py                          # Main server with route registration
├── tts_lab_api.py                     # TTS Lab API endpoints
├── tts_pregen_api.py                  # Batch profiles API endpoints
└── tts_lab_configs/                   # Saved TTS Lab configurations
```

### Adding New Voice Lab Features

To add a new tab to Voice Lab:

1. **Update nav-tabs.tsx:**
   ```typescript
   export type VoiceLabTabId =
     | 'model-selection'
     | 'tts-lab'
     | 'tts-profiles'
     | 'your-new-tab';  // Add here

   const voiceLabTabs = [
     // ... existing tabs
     { id: 'your-new-tab', label: 'Your Feature', shortLabel: 'Feature', icon: YourIcon },
   ];
   ```

2. **Update dashboard.tsx:**
   ```typescript
   const VOICELAB_TABS = [
     'model-selection',
     'tts-lab',
     'tts-profiles',
     'your-new-tab',  // Add here
   ] as const;

   // In render section:
   {activeTab === 'your-new-tab' && (
     <div className="animate-in fade-in duration-300">
       <YourNewPanel />
     </div>
   )}
   ```

3. **Create your panel component:**
   ```typescript
   // src/components/dashboard/your-new-panel.tsx
   export function YourNewPanel() {
     // Implementation
   }
   ```

4. **Add backend API if needed:**
   ```python
   # server/management/your_new_api.py
   def register_your_new_routes(app: web.Application) -> None:
       # Routes

   # In server.py:
   from your_new_api import register_your_new_routes
   register_your_new_routes(app)
   ```

## Workflow Examples

### Example 1: Select On-Device TTS Model

1. Navigate to Voice Lab → AI Model Selection
2. Click "On-Device TTS" tab
3. Review Kyutai Pocket TTS (100M, Jan 13 2026):
   - Best WER: 1.84%
   - Only 100MB
   - Sub-50ms latency
   - CPU-only
4. Click external link to read full documentation
5. Note deployment requirements (iPhone, Android, etc.)
6. Make decision to implement

### Example 2: Configure TTS for Knowledge Bowl Questions

1. Navigate to Voice Lab → TTS Experimentation
2. Select Kyutai TTS 1.6B model
3. Choose "sarah" voice (neutral, professional)
4. Configure parameters:
   - cfg_coef: 2.0 (consistent voice)
   - n_q: 24 (full quality)
   - padding_between: 1 (clear articulation)
   - padding_bonus: 0 (neutral speed)
   - temperature: 0.8 (slight consistency)
5. Enter test question: "The French Revolution began in 1789..."
6. Generate audio sample
7. Listen and evaluate
8. Adjust if needed, regenerate
9. Compare multiple configurations
10. Save optimal config as "KB Questions - Sarah Voice"

### Example 3: Batch Process 5,000 Questions

1. Navigate to Voice Lab → TTS Experimentation → Batch Settings
2. Review saved configuration "KB Questions - Sarah Voice"
3. Set batch size: 8 (for GPU memory)
4. Save configuration
5. Navigate to Voice Lab → Batch Profiles
6. Create new profile using saved config
7. Test with 10 sample questions
8. Review quality and approve
9. Launch batch job for 5,000 questions
10. Monitor progress in profiles panel
11. Estimated completion: ~33 minutes at 150 questions/min

## Troubleshooting

### Voice Lab Section Not Visible

**Issue:** Voice Lab doesn't appear in section navigation

**Solutions:**
- Clear browser cache and hard refresh (Cmd+Shift+R / Ctrl+Shift+R)
- Check that Next.js dev server is running (`npm run dev` in server/web/)
- Verify management server is running (port 8766)
- Check browser console for errors

### TTS Lab Page Not Loading

**Issue:** TTS Lab tab shows blank or error

**Solutions:**
- Verify `/app/management/tts-lab/page.tsx` exists
- Check Next.js build: `npm run build` in server/web/
- Verify `tts_lab_api.py` routes are registered in server.py
- Check management server logs for API errors

### AI Model Selection Shows Old Data

**Issue:** Model information is outdated

**Solutions:**
- Update `docs/AI_MODEL_SELECTION_2026.md` with latest models
- Update model data in `/app/management/models/page.tsx`
- Refresh page to see changes
- Remember: This is static data, not live API

### Saved Configurations Not Appearing

**Issue:** Saved TTS Lab configs don't show up

**Solutions:**
- Check `server/management/tts_lab_configs/` directory exists
- Verify file permissions (should be writable)
- Check server logs for write errors
- Verify API endpoint: `GET /api/tts-lab/configs`

## Best Practices

### When to Use Each Tab

**AI Model Selection:**
- When evaluating new models
- When migrating from outdated models
- When comparing benchmarks
- When planning infrastructure

**TTS Experimentation:**
- Before batch processing thousands of questions
- When testing voice quality
- When tuning for specific use cases
- When comparing models side-by-side

**Batch Profiles:**
- After finalizing TTS configuration
- When managing production batches
- When tracking quality metrics
- When running A/B tests

### Configuration Management

- Save configurations with descriptive names
- Include use case in name (e.g., "KB Questions - Sarah Voice")
- Test with representative samples before batch processing
- Document non-default settings with rationale
- Keep configurations organized by use case

### Performance Optimization

- Use lower n_q for development/testing
- Use higher n_q for production archival quality
- Adjust batch size based on available GPU memory
- Monitor throughput and adjust accordingly
- Balance quality vs speed based on use case

## Related Documentation

- [AI Model Selection 2026](../AI_MODEL_SELECTION_2026.md) - Complete model analysis
- [TTS Lab Guide](TTS_LAB_GUIDE.md) - Detailed TTS Lab documentation
- [TTS Pre-Generation API](../../server/management/tts_pregen_api.py) - Batch API reference
- [Management Console Overview](MANAGEMENT_CONSOLE.md) - Full console documentation

## Support

For issues or questions about Voice Lab:
- Check documentation in `docs/server/`
- Review API code in `server/management/`
- Check Next.js pages in `server/web/app/management/`
- File issues on GitHub if needed
