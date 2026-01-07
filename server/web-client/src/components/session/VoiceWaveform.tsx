'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';
import type { SessionState } from '@/types';

// ===== Types =====

export interface VoiceWaveformProps {
  state: SessionState;
  audioLevel?: number; // 0-1 normalized audio level
  className?: string;
  barCount?: number;
}

// ===== Voice Waveform Component =====

function VoiceWaveform({
  state,
  audioLevel = 0,
  className,
  barCount = 5,
}: VoiceWaveformProps) {
  const isActive = state === 'userSpeaking' || state === 'aiSpeaking';
  const isUserSpeaking = state === 'userSpeaking';
  const isAISpeaking = state === 'aiSpeaking';

  // Generate bar heights based on audio level and state
  const generateBarHeights = React.useCallback(() => {
    const bars: number[] = [];
    for (let i = 0; i < barCount; i++) {
      if (!isActive) {
        // Minimal height when inactive
        bars.push(0.1);
      } else {
        // Randomized heights based on audio level
        const baseHeight = audioLevel * 0.5;
        const randomVariation = Math.random() * 0.5;
        bars.push(Math.min(1, baseHeight + randomVariation));
      }
    }
    return bars;
  }, [barCount, isActive, audioLevel]);

  const [barHeights, setBarHeights] = React.useState<number[]>(() => generateBarHeights());

  // Animate bar heights when active
  React.useEffect(() => {
    if (!isActive) {
      setBarHeights(Array(barCount).fill(0.1));
      return;
    }

    const intervalId = setInterval(() => {
      setBarHeights(generateBarHeights());
    }, 100);

    return () => clearInterval(intervalId);
  }, [isActive, generateBarHeights, barCount]);

  return (
    <div
      className={cn('flex items-center justify-center gap-1', className)}
      role="img"
      aria-label={
        isUserSpeaking
          ? 'Voice activity: You are speaking'
          : isAISpeaking
            ? 'Voice activity: AI is speaking'
            : 'Voice activity: Idle'
      }
    >
      {barHeights.map((height, index) => (
        <div
          key={index}
          className={cn(
            'w-1 rounded-full transition-all duration-100',
            isUserSpeaking && 'bg-primary',
            isAISpeaking && 'bg-secondary-foreground',
            !isActive && 'bg-muted-foreground/30'
          )}
          style={{
            height: `${Math.max(4, height * 32)}px`,
          }}
        />
      ))}
    </div>
  );
}

// ===== Animated Dots Component (Alternative) =====

export interface AnimatedDotsProps {
  state: SessionState;
  className?: string;
}

function AnimatedDots({ state, className }: AnimatedDotsProps) {
  const isActive =
    state === 'aiThinking' ||
    state === 'processingUserUtterance';

  if (!isActive) return null;

  return (
    <div className={cn('flex items-center gap-1', className)} role="status" aria-label="Processing">
      <span className="sr-only">Processing</span>
      {[0, 1, 2].map((index) => (
        <div
          key={index}
          className="h-2 w-2 rounded-full bg-muted-foreground animate-bounce"
          style={{
            animationDelay: `${index * 0.15}s`,
            animationDuration: '0.6s',
          }}
        />
      ))}
    </div>
  );
}

export { VoiceWaveform, AnimatedDots };
