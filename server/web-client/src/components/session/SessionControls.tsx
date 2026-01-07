'use client';

import * as React from 'react';
import { Mic, MicOff, Pause, Play, Square, Volume2, VolumeX } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui';
import type { SessionState } from '@/types';

// ===== Types =====

export interface SessionControlsProps {
  state: SessionState;
  isMuted?: boolean;
  isSpeakerMuted?: boolean;
  onStart?: () => void;
  onStop?: () => void;
  onPause?: () => void;
  onResume?: () => void;
  onMuteToggle?: () => void;
  onSpeakerToggle?: () => void;
  className?: string;
  disabled?: boolean;
}

// ===== Session Controls Component =====

function SessionControls({
  state,
  isMuted = false,
  isSpeakerMuted = false,
  onStart,
  onStop,
  onPause,
  onResume,
  onMuteToggle,
  onSpeakerToggle,
  className,
  disabled = false,
}: SessionControlsProps) {
  const isIdle = state === 'idle';
  const isPaused = state === 'paused';
  const isActive = !isIdle && !isPaused && state !== 'error';
  const isError = state === 'error';

  // Determine primary action
  const handlePrimaryAction = React.useCallback(() => {
    if (isIdle || isError) {
      onStart?.();
    } else if (isPaused) {
      onResume?.();
    } else {
      onPause?.();
    }
  }, [isIdle, isPaused, isError, onStart, onResume, onPause]);

  return (
    <div
      className={cn('flex items-center justify-center gap-3', className)}
      role="group"
      aria-label="Session controls"
    >
      {/* Microphone Toggle */}
      <Button
        variant="outline"
        size="icon"
        onClick={onMuteToggle}
        disabled={disabled || isIdle}
        aria-label={isMuted ? 'Unmute microphone' : 'Mute microphone'}
        aria-pressed={isMuted}
        className={cn(isMuted && 'text-destructive border-destructive')}
      >
        {isMuted ? <MicOff className="h-4 w-4" /> : <Mic className="h-4 w-4" />}
      </Button>

      {/* Primary Action Button */}
      <Button
        variant={isIdle || isError ? 'default' : isPaused ? 'secondary' : 'outline'}
        size="lg"
        onClick={handlePrimaryAction}
        disabled={disabled}
        aria-label={
          isIdle || isError
            ? 'Start session'
            : isPaused
              ? 'Resume session'
              : 'Pause session'
        }
        className={cn(
          'h-14 w-14 rounded-full',
          isActive && 'bg-primary text-primary-foreground hover:bg-primary/90'
        )}
      >
        {isIdle || isError ? (
          <Mic className="h-6 w-6" />
        ) : isPaused ? (
          <Play className="h-6 w-6" />
        ) : (
          <Pause className="h-6 w-6" />
        )}
      </Button>

      {/* Stop Button */}
      <Button
        variant="outline"
        size="icon"
        onClick={onStop}
        disabled={disabled || isIdle}
        aria-label="Stop session"
        className={cn(!isIdle && 'hover:text-destructive hover:border-destructive')}
      >
        <Square className="h-4 w-4" />
      </Button>

      {/* Speaker Toggle */}
      <Button
        variant="outline"
        size="icon"
        onClick={onSpeakerToggle}
        disabled={disabled || isIdle}
        aria-label={isSpeakerMuted ? 'Unmute speaker' : 'Mute speaker'}
        aria-pressed={isSpeakerMuted}
        className={cn(isSpeakerMuted && 'text-destructive border-destructive')}
      >
        {isSpeakerMuted ? <VolumeX className="h-4 w-4" /> : <Volume2 className="h-4 w-4" />}
      </Button>
    </div>
  );
}

export { SessionControls };
