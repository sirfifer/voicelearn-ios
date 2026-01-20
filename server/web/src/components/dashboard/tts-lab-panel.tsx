'use client';

/**
 * TTS Lab Panel
 *
 * TTS experimentation interface for testing models and configurations before batch processing.
 *
 * This panel loads the Next.js page from /management/tts-lab which provides:
 * - Model selection (Kyutai TTS 1.6B, Pocket TTS, Fish Speech)
 * - Configuration controls (cfg_coef, n_q, padding, temperature, etc.)
 * - Test audio generation with different settings
 * - Side-by-side comparison of configurations
 * - Save optimal config for batch conversion of thousands of questions
 */

export function TTSLabPanel() {
  return (
    <div className="h-full w-full">
      <iframe
        src="/management/tts-lab"
        className="w-full h-[calc(100vh-200px)] border-0"
        title="TTS Lab"
      />
    </div>
  );
}
