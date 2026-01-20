'use client';

/**
 * AI Model Selection Panel
 *
 * Displays comprehensive AI model selection dashboard showing current and recommended
 * models for all use cases: on-device LLM, server LLM, server TTS, on-device TTS.
 *
 * This panel loads the Next.js page from /management/models which shows:
 * - SmolLM3-3B vs Llama 3.2 1B for on-device KB validation
 * - Qwen3-235B and other server LLMs for tutoring
 * - Fish Speech V1.5, Kyutai TTS 1.6B for server TTS
 * - Kyutai Pocket TTS (Jan 13, 2026) for on-device TTS
 */

export function ModelSelectionPanel() {
  return (
    <div className="h-full w-full">
      <iframe
        src="/management/models"
        className="w-full h-[calc(100vh-200px)] border-0"
        title="AI Model Selection"
      />
    </div>
  );
}
