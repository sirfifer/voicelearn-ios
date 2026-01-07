'use client';

/**
 * Session Page
 *
 * Voice tutoring session interface with transcript and visual panel.
 * Uses session state machine for voice interaction flow.
 */

import * as React from 'react';
import dynamic from 'next/dynamic';
import { useRouter } from 'next/navigation';
import { ArrowLeft, BookOpen } from 'lucide-react';
import { useAuth } from '@/components/auth/AuthProvider';
import { Button } from '@/components/ui';
import { Transcript, SessionControls, SessionHeader } from '@/components/session';
import type { SessionState, Message, VisualAsset } from '@/types';

// Dynamic imports for components that may use browser APIs
const VoiceWaveform = dynamic(
  () => import('@/components/session').then((mod) => mod.VoiceWaveform),
  { ssr: false }
);
const VisualPanel = dynamic(
  () => import('@/components/visual').then((mod) => mod.VisualPanel),
  { ssr: false }
);

// Stub session hook until Track 2 is complete
function useSessionState() {
  const [state, setState] = React.useState<SessionState>('idle');
  const [conversationHistory, setConversationHistory] = React.useState<Message[]>([]);
  const [currentUtterance, setCurrentUtterance] = React.useState<string>('');
  const [visualAssets, setVisualAssets] = React.useState<VisualAsset[]>([]);
  const [duration, setDuration] = React.useState(0);
  const [isMuted, setIsMuted] = React.useState(false);
  const [isSpeakerMuted, setIsSpeakerMuted] = React.useState(false);

  // Timer for session duration
  React.useEffect(() => {
    let interval: ReturnType<typeof setInterval>;
    if (state !== 'idle' && state !== 'paused' && state !== 'error') {
      interval = setInterval(() => {
        setDuration((d) => d + 1);
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [state]);

  const start = React.useCallback(() => {
    setState('userSpeaking');
    setConversationHistory([
      {
        role: 'system',
        content: 'Session started. You can begin speaking.',
      },
    ]);
  }, []);

  const stop = React.useCallback(() => {
    setState('idle');
    setCurrentUtterance('');
    setDuration(0);
    setConversationHistory([]);
    setVisualAssets([]);
  }, []);

  const pause = React.useCallback(() => {
    setState('paused');
  }, []);

  const resume = React.useCallback(() => {
    setState('userSpeaking');
  }, []);

  const toggleMute = React.useCallback(() => {
    setIsMuted((m) => !m);
  }, []);

  const toggleSpeaker = React.useCallback(() => {
    setIsSpeakerMuted((m) => !m);
  }, []);

  // Simulate a demo conversation (for development purposes)
  const simulateDemo = React.useCallback(() => {
    setState('userSpeaking');
    setCurrentUtterance('What is the Pythagorean theorem?');

    setTimeout(() => {
      setConversationHistory((h) => [
        ...h,
        {
          role: 'user',
          content: 'What is the Pythagorean theorem?',
        },
      ]);
      setCurrentUtterance('');
      setState('aiThinking');
    }, 2000);

    setTimeout(() => {
      setState('aiSpeaking');
      setCurrentUtterance('The Pythagorean theorem states that...');
    }, 3000);

    setTimeout(() => {
      setConversationHistory((h) => [
        ...h,
        {
          role: 'assistant',
          content:
            'The Pythagorean theorem states that in a right triangle, the square of the hypotenuse equals the sum of the squares of the other two sides. It can be written as a² + b² = c².',
        },
      ]);
      setCurrentUtterance('');
      setState('userSpeaking');

      // Add a visual asset
      setVisualAssets([
        {
          id: 'formula-1',
          type: 'formula',
          title: 'Pythagorean Theorem',
          alt: 'Pythagorean theorem formula',
          latex: 'a^2 + b^2 = c^2',
          displayMode: 'block',
        } as VisualAsset,
      ]);
    }, 5000);
  }, []);

  return {
    state,
    conversationHistory,
    currentUtterance,
    visualAssets,
    duration,
    isMuted,
    isSpeakerMuted,
    start,
    stop,
    pause,
    resume,
    toggleMute,
    toggleSpeaker,
    simulateDemo,
  };
}

export default function SessionPage() {
  const router = useRouter();
  const { isAuthenticated, isLoading } = useAuth();
  const session = useSessionState();
  const [visualIndex, setVisualIndex] = React.useState(0);

  // Redirect if not authenticated
  React.useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [isAuthenticated, isLoading, router]);

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="text-center">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent mx-auto" />
          <p className="mt-4 text-muted-foreground">Loading...</p>
        </div>
      </main>
    );
  }

  if (!isAuthenticated) {
    return null;
  }

  return (
    <main className="flex flex-col h-screen">
      {/* Navigation Header */}
      <div className="flex items-center gap-2 px-4 py-2 border-b bg-muted/30">
        <Button variant="ghost" size="icon" onClick={() => router.push('/')}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <span className="text-sm font-medium">Voice Session</span>
        <div className="flex-1" />
        <Button variant="outline" size="sm" onClick={() => router.push('/curriculum')}>
          <BookOpen className="h-4 w-4 mr-2" />
          Select Topic
        </Button>
      </div>

      {/* Session Header with status */}
      <SessionHeader
        state={session.state}
        topicTitle="General Tutoring"
        curriculumTitle="Open Session"
        duration={session.duration}
      />

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col lg:flex-row overflow-hidden">
        {/* Transcript Panel */}
        <div className="flex-1 flex flex-col min-h-0 lg:w-1/2">
          <Transcript
            conversationHistory={session.conversationHistory}
            currentUtterance={session.currentUtterance}
            state={session.state}
            className="flex-1"
          />
        </div>

        {/* Visual Panel (Desktop: side panel, Mobile: bottom sheet) */}
        <div className="h-64 lg:h-auto lg:w-1/2 border-t lg:border-t-0 lg:border-l bg-muted/20">
          <VisualPanel
            assets={session.visualAssets}
            currentIndex={visualIndex}
            onIndexChange={setVisualIndex}
            className="h-full"
          />
        </div>
      </div>

      {/* Voice Waveform */}
      <div className="h-16 border-t bg-muted/30 flex items-center justify-center px-4">
        <VoiceWaveform
          state={session.state}
          audioLevel={0.5}
          className="w-full max-w-md"
        />
      </div>

      {/* Session Controls */}
      <div className="border-t bg-background py-4 px-4">
        <SessionControls
          state={session.state}
          isMuted={session.isMuted}
          isSpeakerMuted={session.isSpeakerMuted}
          onStart={session.start}
          onStop={session.stop}
          onPause={session.pause}
          onResume={session.resume}
          onMuteToggle={session.toggleMute}
          onSpeakerToggle={session.toggleSpeaker}
        />

        {/* Demo button for development */}
        {session.state === 'idle' && (
          <div className="mt-4 text-center">
            <Button variant="outline" size="sm" onClick={session.simulateDemo}>
              Run Demo Conversation
            </Button>
          </div>
        )}
      </div>
    </main>
  );
}
