# Enhanced Answer Validation for Knowledge Bowl

**For UnaMentis Users**

## What is Enhanced Validation?

Enhanced Answer Validation helps UnaMentis understand your answers better, even if you don't say them exactly right. Instead of requiring perfect spelling or exact wording, the app now uses smart algorithms to recognize when your answer is correct, even with:

- Spelling errors ("Missisipi" instead of "Mississippi")
- Different pronunciation ("Kristopher" instead of "Christopher")
- Word order changes ("States United" instead of "United States")
- Common abbreviations ("USA" instead of "United States")

## Three Levels of Understanding

### Level 1: Smart Algorithms (Everyone)

**What it does:** Uses advanced algorithms to understand your answers better

**Who gets it:** Everyone, on all devices

**How much:** Free, built into the app (0 bytes)

**Accuracy:** 85-90% correct recognition

**Examples:**
- ✓ "Missisipi" → "Mississippi" (spelling error)
- ✓ "Filadelfia" → "Philadelphia" (phonetic)
- ✓ "CO2" → "Carbon Dioxide" (synonym)
- ✓ "United States America" → "United States of America" (missing word)

### Level 2: Semantic Understanding (iPhone XS+)

**What it does:** Understands the meaning of your answer, not just the words

**Who gets it:** iPhone XS or newer (2018+), Android 8.0+ with 3GB RAM

**How much:** Optional 80MB download (one-time)

**Accuracy:** 92-95% correct recognition

**Examples:**
- ✓ "water" → "H2O" (different forms)
- ✓ "table salt" → "NaCl" (common name vs scientific)
- ✓ "genetic material" → "DNA" (description vs term)

**How to enable:**
1. Go to Settings → Knowledge Bowl → Enhanced Validation
2. Tap "Download Semantic Model" (80MB)
3. Wait for download to complete
4. Model activates automatically

### Level 3: AI Expert Judge (iPhone 12+)

**What it does:** Uses a small open-source AI (Llama 3.2 1B) to judge answers like a human expert would

**Who gets it:** iPhone 12 or newer (2020+), Android 10+ with 4GB RAM, when enabled by server administrator

**How much:** 1.5GB download (one-time), controlled by server administrator

**Accuracy:** 95-98% correct recognition

**Examples:**
- ✓ "the powerhouse of the cell" → "mitochondria"
- ✓ "the author of Romeo and Juliet" → "William Shakespeare"
- ✓ "the largest planet" → "Jupiter"

**How to enable:**
1. Verify your server administrator has enabled LLM validation
2. Go to Settings → Knowledge Bowl → Enhanced Validation
3. If enabled, you'll see "Download AI Model" option
4. Tap "Download AI Model" (1.5GB)
5. Wait for download to complete (may take a few minutes)
6. Model activates automatically

**Note:** If you see "Feature Not Enabled," contact your server administrator to request access.

## Regional Competition Rules

**Important:** Enhanced validation respects your regional competition's rules!

- **Colorado:** Strictest rules (exact + basic fuzzy only)
- **Minnesota & Washington:** Standard rules (all smart algorithms allowed)
- **Practice Mode:** Lenient (all levels available)

The app automatically uses the right rules based on your region and whether you're practicing or simulating a competition.

## Device Compatibility

Check if your device supports enhanced features:

### Level 1: Smart Algorithms
- ✓ All iPhones
- ✓ All Android phones
- ✓ All iPads and tablets

### Level 2: Semantic Understanding
- ✓ iPhone XS or newer
- ✓ iPhone XR or newer
- ✓ iPad Pro 3rd gen or newer
- ✓ iPad Air 3rd gen or newer
- ✓ Android 8.0+ with 3GB+ RAM

### Level 3: AI Expert Judge
- ✓ iPhone 12 or newer
- ✓ iPad Pro 4th gen (2020) or newer
- ✓ iPad Air 4th gen (2020) or newer
- ✓ Android 10+ with 4GB+ RAM
- ✓ Server administrator must enable the feature

**To check your device:**
1. Go to Settings → Knowledge Bowl → Enhanced Validation
2. See "Device Information" section
3. Available features will be shown

## How It Works

When you answer a question, UnaMentis tries to match your answer in this order:

1. **Exact Match** → Instant correct!
2. **Listed Alternative** → Instant correct! (like "USA" for "United States")
3. **Basic Fuzzy Match** → Close enough! (small spelling errors)

If your answer doesn't match yet:

4. **Synonym Check** → Same meaning? (like "CO2" = "Carbon Dioxide")
5. **Sounds-Like Check** → Same pronunciation? (like "Stephen" = "Steven")
6. **Character Match** → Similar letters? (like "Missisipi" = "Mississippi")
7. **Word Match** → Same words, different order?

Still no match? (If you have advanced features enabled)

8. **Meaning Check** → Does it mean the same thing? (Tier 2)
9. **AI Judge** → Would an expert accept it? (Tier 3)

The app stops as soon as it finds a match, so fast answers stay fast!

## Managing Downloads

### Semantic Model (Level 2)

**Download:**
1. Settings → Knowledge Bowl → Enhanced Validation
2. Tap "Download Semantic Model"
3. Uses 80MB of storage

**Remove:**
1. Settings → Knowledge Bowl → Enhanced Validation
2. Tap "Remove" next to Semantic Model
3. Frees up 80MB

### AI Model (Level 3)

**Download:**
1. Verify server administrator has enabled LLM validation
2. Settings → Knowledge Bowl → Enhanced Validation
3. Tap "Download AI Model"
4. Uses 1.5GB of storage

**Remove:**
1. Settings → Knowledge Bowl → Enhanced Validation
2. Tap "Remove" next to AI Model
3. Frees up 1.5GB

Models are stored on your device and work offline!

## Privacy & Performance

**Privacy:**
- All processing happens on your device
- No answers sent to cloud servers
- Works completely offline

**Performance:**
- Level 1: Instant (<50ms)
- Level 2: Very fast (<80ms)
- Level 3: Fast (<250ms)

**Battery:**
- Level 1: Minimal impact
- Level 2: Low impact
- Level 3: Moderate impact during use

**Storage:**
- Level 1: 0 bytes
- Level 2: 80MB
- Level 3: 1.5GB

## Frequently Asked Questions

**Q: Do I need internet to use enhanced validation?**
A: Only to download the models. After download, everything works offline.

**Q: Will enhanced validation slow down my study sessions?**
A: No! Validation is very fast (<250ms even with AI), and the app checks faster methods first.

**Q: Can I use enhanced validation during real competitions?**
A: No, enhanced validation is for practice only. During competition simulation, the app uses your region's official rules.

**Q: What happens if I run out of storage?**
A: You can remove models anytime to free up space. Level 1 is always available with 0 bytes.

**Q: Does enhanced validation work for all question types?**
A: Yes! It works for all answer types: text, numbers, dates, places, people, titles, scientific terms, and multiple choice.

**Q: Will enhanced validation accept wrong answers?**
A: No! It's designed to accept correct answers said different ways, not incorrect answers. The algorithms are carefully tuned to maintain accuracy.

**Q: Can I disable enhanced validation?**
A: You can't disable Level 1 (it's built in), but you can remove Level 2 and 3 models. For competition simulation, the app automatically uses your region's rules.

**Q: Does enhanced validation work with voice input?**
A: Yes! Enhanced validation works great with speech-to-text, handling pronunciation variations and transcription errors.

## Troubleshooting

**Model download fails:**
1. Check internet connection
2. Ensure enough storage space (80MB for Level 2, 1.5GB for Level 3)
3. Restart the app and try again

**Model not loading:**
1. Check device meets requirements
2. Ensure enough RAM available
3. Close other apps to free memory

**Still having issues?**
Contact support: help@unamentis.com

## Learn More

- [Knowledge Bowl Module Overview](../modules/KNOWLEDGE_BOWL_MODULE.md)
- [Answer Validation API Documentation](../modules/KNOWLEDGE_BOWL_ANSWER_VALIDATION.md)
- [Testing Documentation](../testing/KNOWLEDGE_BOWL_VALIDATION_TESTING.md)

---

*Last updated: January 19, 2026*
