'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';
import type { Message, SessionState } from '@/types';

// ===== Message Bubble Component =====

interface MessageBubbleProps {
  message: Message;
  className?: string;
}

function MessageBubble({ message, className }: MessageBubbleProps) {
  const isUser = message.role === 'user';
  const isSystem = message.role === 'system';

  if (isSystem) {
    return (
      <div className={cn('my-2 text-center text-sm text-muted-foreground italic', className)}>
        {message.content}
      </div>
    );
  }

  return (
    <div
      className={cn('flex', isUser ? 'justify-end' : 'justify-start', className)}
      role="listitem"
      aria-label={`${isUser ? 'You' : 'AI'} said: ${message.content.slice(0, 50)}${message.content.length > 50 ? '...' : ''}`}
    >
      <div
        className={cn(
          'max-w-[80%] rounded-2xl px-4 py-3',
          isUser
            ? 'bg-primary text-primary-foreground rounded-br-md'
            : 'bg-muted text-foreground rounded-bl-md'
        )}
      >
        <p className="text-sm leading-relaxed whitespace-pre-wrap">{message.content}</p>
      </div>
    </div>
  );
}

// ===== Current Utterance Component =====

interface CurrentUtteranceProps {
  text: string;
  state: SessionState;
  className?: string;
}

function CurrentUtterance({ text, state, className }: CurrentUtteranceProps) {
  const isUserSpeaking = state === 'userSpeaking';
  const isAIResponding = state === 'aiThinking' || state === 'aiSpeaking';

  if (!text) return null;

  return (
    <div
      className={cn('flex', isUserSpeaking ? 'justify-end' : 'justify-start', className)}
      role="status"
      aria-live="polite"
      aria-label={`${isUserSpeaking ? 'You are saying' : 'AI is responding with'}: ${text}`}
    >
      <div
        className={cn(
          'max-w-[80%] rounded-2xl px-4 py-3',
          isUserSpeaking
            ? 'bg-primary/70 text-primary-foreground rounded-br-md'
            : 'bg-muted/70 text-foreground rounded-bl-md',
          'animate-pulse'
        )}
      >
        <p className="text-sm leading-relaxed whitespace-pre-wrap">
          {text}
          {isAIResponding && <span className="inline-block animate-pulse">...</span>}
        </p>
      </div>
    </div>
  );
}

// ===== Transcript Component =====

export interface TranscriptProps {
  conversationHistory: Message[];
  currentUtterance?: string;
  state: SessionState;
  className?: string;
}

function Transcript({ conversationHistory, currentUtterance, state, className }: TranscriptProps) {
  const scrollRef = React.useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom on new messages
  React.useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTo({
        top: scrollRef.current.scrollHeight,
        behavior: 'smooth',
      });
    }
  }, [conversationHistory, currentUtterance]);

  const isEmpty = conversationHistory.length === 0 && !currentUtterance;

  return (
    <div
      ref={scrollRef}
      className={cn('flex-1 overflow-y-auto p-4', className)}
      role="log"
      aria-label="Conversation transcript"
      aria-live="polite"
    >
      {isEmpty ? (
        <div className="flex h-full items-center justify-center">
          <p className="text-muted-foreground text-center">
            {state === 'idle'
              ? 'Start a session to begin the conversation'
              : 'Listening for your voice...'}
          </p>
        </div>
      ) : (
        <div className="space-y-4" role="list">
          {conversationHistory.map((message, index) => (
            <MessageBubble key={index} message={message} />
          ))}

          {currentUtterance && <CurrentUtterance text={currentUtterance} state={state} />}
        </div>
      )}
    </div>
  );
}

export { Transcript, MessageBubble, CurrentUtterance };
