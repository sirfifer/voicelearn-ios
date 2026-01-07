'use client';

import * as React from 'react';
import { Clock, Circle, AlertCircle, Pause as PauseIcon } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { SessionState } from '@/types';

// ===== Types =====

export interface SessionHeaderProps {
  state: SessionState;
  topicTitle?: string;
  curriculumTitle?: string;
  duration?: number; // seconds
  className?: string;
}

// ===== Helpers =====

function formatDuration(seconds: number): string {
  const hrs = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hrs > 0) {
    return `${hrs}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

function getStateLabel(state: SessionState): string {
  switch (state) {
    case 'idle':
      return 'Ready';
    case 'userSpeaking':
      return 'Listening...';
    case 'processingUserUtterance':
      return 'Processing...';
    case 'aiThinking':
      return 'Thinking...';
    case 'aiSpeaking':
      return 'Speaking...';
    case 'interrupted':
      return 'Interrupted';
    case 'paused':
      return 'Paused';
    case 'error':
      return 'Error';
    default:
      return 'Unknown';
  }
}

function getStateColor(state: SessionState): string {
  switch (state) {
    case 'idle':
      return 'text-muted-foreground';
    case 'userSpeaking':
      return 'text-primary';
    case 'processingUserUtterance':
    case 'aiThinking':
      return 'text-amber-500';
    case 'aiSpeaking':
      return 'text-green-500';
    case 'interrupted':
      return 'text-orange-500';
    case 'paused':
      return 'text-muted-foreground';
    case 'error':
      return 'text-destructive';
    default:
      return 'text-muted-foreground';
  }
}

// ===== Status Indicator Component =====

interface StatusIndicatorProps {
  state: SessionState;
  className?: string;
}

function StatusIndicator({ state, className }: StatusIndicatorProps) {
  const color = getStateColor(state);
  const label = getStateLabel(state);
  const isActive = state !== 'idle' && state !== 'paused' && state !== 'error';
  const isPaused = state === 'paused';
  const isError = state === 'error';

  return (
    <div
      className={cn('flex items-center gap-2', className)}
      role="status"
      aria-live="polite"
      aria-label={`Session status: ${label}`}
    >
      {isError ? (
        <AlertCircle className={cn('h-3 w-3', color)} />
      ) : isPaused ? (
        <PauseIcon className={cn('h-3 w-3', color)} />
      ) : (
        <Circle
          className={cn('h-3 w-3', color, isActive && 'animate-pulse')}
          fill={isActive ? 'currentColor' : 'none'}
        />
      )}
      <span className={cn('text-sm font-medium', color)}>{label}</span>
    </div>
  );
}

// ===== Session Timer Component =====

interface SessionTimerProps {
  duration: number;
  isRunning?: boolean;
  className?: string;
}

function SessionTimer({ duration, isRunning = true, className }: SessionTimerProps) {
  return (
    <div
      className={cn('flex items-center gap-1.5 text-sm text-muted-foreground', className)}
      role="timer"
      aria-label={`Session duration: ${formatDuration(duration)}`}
    >
      <Clock className={cn('h-4 w-4', isRunning && 'animate-pulse')} />
      <span className="font-mono tabular-nums">{formatDuration(duration)}</span>
    </div>
  );
}

// ===== Session Header Component =====

function SessionHeader({
  state,
  topicTitle,
  curriculumTitle,
  duration = 0,
  className,
}: SessionHeaderProps) {
  const isRunning = state !== 'idle' && state !== 'paused' && state !== 'error';

  return (
    <div
      className={cn(
        'flex items-center justify-between border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 px-4 py-3',
        className
      )}
    >
      {/* Left: Topic Info */}
      <div className="flex flex-col min-w-0">
        {topicTitle ? (
          <>
            <h1 className="text-sm font-semibold truncate">{topicTitle}</h1>
            {curriculumTitle && (
              <p className="text-xs text-muted-foreground truncate">{curriculumTitle}</p>
            )}
          </>
        ) : (
          <h1 className="text-sm font-semibold text-muted-foreground">No topic selected</h1>
        )}
      </div>

      {/* Center: Status */}
      <StatusIndicator state={state} />

      {/* Right: Timer */}
      <SessionTimer duration={duration} isRunning={isRunning} />
    </div>
  );
}

export { SessionHeader, StatusIndicator, SessionTimer };
