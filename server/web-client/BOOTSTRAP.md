# UnaMentis Web Client - Bootstrap Implementation Guide

This document is the initial prompt for AI-assisted development. Follow phases in order, completing all checkboxes before proceeding.

---

## Pre-Implementation Checklist

Before starting, ensure you have:

- [ ] Read `WEB_CLIENT_TDD.md` completely
- [ ] Read `docs/API_REFERENCE.md` for server endpoints
- [ ] Read `docs/AUTHENTICATION.md` for auth flow
- [ ] Read `docs/PROVIDER_GUIDE.md` for voice integrations
- [ ] Read `docs/UMCF_SPECIFICATION.md` for curriculum format
- [ ] Node.js 20+ installed
- [ ] Access to Management API (localhost:8766)

---

## Phase 0: Project Initialization

**Goal**: Create Next.js project with all dependencies and configuration.

### 0.1 Create Next.js Project

```bash
npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
```

- [ ] Project created successfully
- [ ] Can run `npm run dev`
- [ ] Verify http://localhost:3000 loads

### 0.2 Install Dependencies

```bash
# Core dependencies
npm install clsx tailwind-merge lucide-react

# State management
npm install xstate @xstate/react

# Validation
npm install zod

# Math rendering
npm install katex
npm install --save-dev @types/katex

# Maps
npm install leaflet react-leaflet
npm install --save-dev @types/leaflet

# Diagrams and charts
npm install mermaid chart.js react-chartjs-2

# Audio (if needed beyond native APIs)
# npm install hark  # for VAD
```

- [ ] All dependencies installed
- [ ] No npm audit critical vulnerabilities

### 0.3 Configure TypeScript

Update `tsconfig.json`:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}
```

- [ ] TypeScript strict mode enabled
- [ ] Project still compiles

### 0.4 Configure Tailwind

Update `tailwind.config.ts`:

```typescript
import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0f9ff',
          // ... full palette
          900: '#0c4a6e',
        },
      },
    },
  },
  plugins: [],
}
export default config
```

- [ ] Tailwind configured
- [ ] Custom colors defined

### 0.5 Create Folder Structure

```bash
mkdir -p src/{components/{ui,session,curriculum,layout},lib/{api,providers,hooks,utils},types,contexts}
```

```
src/
├── app/
│   ├── layout.tsx
│   ├── page.tsx
│   ├── (auth)/
│   │   ├── login/page.tsx
│   │   └── register/page.tsx
│   ├── session/page.tsx
│   ├── curriculum/page.tsx
│   ├── history/page.tsx
│   ├── settings/page.tsx
│   └── api/
│       ├── auth/
│       └── realtime/
├── components/
│   ├── ui/           # Button, Input, Card, etc.
│   ├── session/      # TranscriptPanel, VisualPanel, etc.
│   ├── curriculum/   # CurriculumList, TopicCard, etc.
│   └── layout/       # Header, TabBar, etc.
├── lib/
│   ├── api/          # API client
│   ├── providers/    # STT, TTS, LLM providers
│   ├── hooks/        # Custom hooks
│   └── utils/        # Utilities
├── types/            # TypeScript types
└── contexts/         # React contexts
```

- [ ] Folder structure created
- [ ] Index files created where needed

### 0.6 Environment Variables

Create `.env.local`:

```bash
# Server
NEXT_PUBLIC_API_URL=http://localhost:8766
NEXT_PUBLIC_WS_URL=ws://localhost:8766

# OpenAI (server-side only)
OPENAI_API_KEY=

# Feature flags
NEXT_PUBLIC_ENABLE_WEBRTC=true
```

Create `.env.example`:

```bash
# Copy to .env.local and fill in values
NEXT_PUBLIC_API_URL=http://localhost:8766
NEXT_PUBLIC_WS_URL=ws://localhost:8766
OPENAI_API_KEY=sk-your-key-here
```

- [ ] `.env.local` created with values
- [ ] `.env.example` created for documentation
- [ ] `.env.local` added to `.gitignore`

### Phase 0 Verification

- [ ] `npm run dev` works
- [ ] `npm run build` succeeds
- [ ] `npm run lint` passes
- [ ] TypeScript compiles without errors

---

## Phase 1: Core Infrastructure

**Goal**: Implement API client, provider abstractions, and audio handling.

### 1.1 Types

Create `src/types/index.ts`:

```typescript
// Re-export all types
export * from './api';
export * from './session';
export * from './providers';
export * from './curriculum';
```

Create `src/types/api.ts`:

```typescript
export interface User {
  id: string;
  email: string;
  display_name?: string;
  role: 'user' | 'admin';
}

export interface AuthTokens {
  access_token: string;
  refresh_token: string;
  token_type: 'Bearer';
  expires_in: number;
}

export interface Device {
  id: string;
  fingerprint: string;
  name: string;
  type: 'web';
}

export interface ApiError {
  error: string;
  message: string;
  code: string;
  details?: Record<string, unknown>;
}
```

Create `src/types/session.ts`:

```typescript
export type SessionState =
  | 'idle'
  | 'userSpeaking'
  | 'processingUserUtterance'
  | 'aiThinking'
  | 'aiSpeaking'
  | 'interrupted'
  | 'paused'
  | 'error';

export interface Message {
  role: 'system' | 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

export interface SessionMetrics {
  turnCount: number;
  totalDuration: number;
  sttLatencies: number[];
  llmTTFTs: number[];
  ttsTTFBs: number[];
  e2eLatencies: number[];
  sttCost: number;
  llmCost: number;
  ttsCost: number;
}
```

Create `src/types/providers.ts`:

```typescript
export interface STTResult {
  text: string;
  isFinal: boolean;
  confidence?: number;
}

export interface LLMToken {
  content: string;
  finishReason?: 'stop' | 'length';
}

export interface AudioChunk {
  audio: ArrayBuffer;
  format: 'pcm' | 'mp3' | 'opus';
  sampleRate: number;
  isFinal: boolean;
}

export interface STTProvider {
  readonly name: string;
  connect(config: STTConfig): Promise<void>;
  startStreaming(): AsyncIterable<STTResult>;
  sendAudio(buffer: ArrayBuffer): void;
  stopStreaming(): Promise<STTResult | null>;
  disconnect(): void;
}

export interface LLMProvider {
  readonly name: string;
  streamCompletion(messages: Message[], config: LLMConfig): AsyncIterable<LLMToken>;
  cancelCompletion(): void;
}

export interface TTSProvider {
  readonly name: string;
  configure(config: TTSConfig): void;
  synthesize(text: string): AsyncIterable<AudioChunk>;
  cancel(): void;
}

export interface STTConfig {
  sampleRate: number;
  language?: string;
}

export interface LLMConfig {
  model: string;
  maxTokens: number;
  temperature: number;
}

export interface TTSConfig {
  voice: string;
  speed?: number;
}
```

- [ ] All type files created
- [ ] Types compile without errors

### 1.2 API Client

Create `src/lib/api/client.ts`:

```typescript
import { ApiError } from '@/types';

class ApiClient {
  private baseUrl: string;
  private accessToken: string | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  setAccessToken(token: string | null) {
    this.accessToken = token;
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown
  ): Promise<T> {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };

    if (this.accessToken) {
      headers['Authorization'] = `Bearer ${this.accessToken}`;
    }

    const response = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
      credentials: 'include',
    });

    if (!response.ok) {
      const error: ApiError = await response.json();
      throw new ApiClientError(error.message, error.code, response.status);
    }

    return response.json();
  }

  get<T>(path: string): Promise<T> {
    return this.request<T>('GET', path);
  }

  post<T>(path: string, body?: unknown): Promise<T> {
    return this.request<T>('POST', path, body);
  }

  patch<T>(path: string, body?: unknown): Promise<T> {
    return this.request<T>('PATCH', path, body);
  }

  delete<T>(path: string): Promise<T> {
    return this.request<T>('DELETE', path);
  }
}

export class ApiClientError extends Error {
  constructor(
    message: string,
    public code: string,
    public status: number
  ) {
    super(message);
    this.name = 'ApiClientError';
  }
}

export const apiClient = new ApiClient(
  process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8766'
);
```

- [ ] API client created
- [ ] Error handling implemented

### 1.3 Token Manager

Create `src/lib/api/token-manager.ts`:

```typescript
import { AuthTokens } from '@/types';
import { apiClient } from './client';

class TokenManager {
  private accessToken: string | null = null;
  private expiresAt: number = 0;
  private refreshPromise: Promise<void> | null = null;

  setTokens(tokens: AuthTokens) {
    this.accessToken = tokens.access_token;
    this.expiresAt = Date.now() + tokens.expires_in * 1000;
    apiClient.setAccessToken(this.accessToken);
  }

  async getValidToken(): Promise<string | null> {
    if (!this.accessToken) return null;

    // Refresh if expiring in less than 1 minute
    if (Date.now() > this.expiresAt - 60000) {
      await this.refresh();
    }

    return this.accessToken;
  }

  private async refresh(): Promise<void> {
    // Deduplicate concurrent refresh requests
    if (this.refreshPromise) {
      return this.refreshPromise;
    }

    this.refreshPromise = this.doRefresh();
    try {
      await this.refreshPromise;
    } finally {
      this.refreshPromise = null;
    }
  }

  private async doRefresh(): Promise<void> {
    try {
      const response = await fetch('/api/auth/refresh', {
        method: 'POST',
        credentials: 'include',
      });

      if (!response.ok) {
        this.clear();
        throw new Error('Session expired');
      }

      const { tokens } = await response.json();
      this.setTokens(tokens);
    } catch {
      this.clear();
      throw new Error('Failed to refresh token');
    }
  }

  clear() {
    this.accessToken = null;
    this.expiresAt = 0;
    apiClient.setAccessToken(null);
  }

  isAuthenticated(): boolean {
    return this.accessToken !== null && Date.now() < this.expiresAt;
  }
}

export const tokenManager = new TokenManager();
```

- [ ] Token manager created
- [ ] Refresh logic implemented

### 1.4 Provider Abstractions

Create `src/lib/providers/index.ts`:

```typescript
export * from './stt';
export * from './llm';
export * from './tts';
export * from './manager';
```

Create `src/lib/providers/stt/index.ts`:

```typescript
import { STTProvider, STTConfig, STTResult } from '@/types';

export abstract class BaseSTTProvider implements STTProvider {
  abstract readonly name: string;
  abstract connect(config: STTConfig): Promise<void>;
  abstract startStreaming(): AsyncIterable<STTResult>;
  abstract sendAudio(buffer: ArrayBuffer): void;
  abstract stopStreaming(): Promise<STTResult | null>;
  abstract disconnect(): void;
}

export { OpenAIRealtimeSTT } from './openai-realtime';
// export { DeepgramSTT } from './deepgram';
// export { AssemblyAISTT } from './assemblyai';
```

Create placeholder `src/lib/providers/stt/openai-realtime.ts`:

```typescript
import { BaseSTTProvider } from './index';
import { STTConfig, STTResult } from '@/types';

export class OpenAIRealtimeSTT extends BaseSTTProvider {
  readonly name = 'openai-realtime';

  async connect(config: STTConfig): Promise<void> {
    // TODO: Implement WebRTC connection
    throw new Error('Not implemented');
  }

  async *startStreaming(): AsyncIterable<STTResult> {
    // TODO: Implement streaming
    throw new Error('Not implemented');
  }

  sendAudio(buffer: ArrayBuffer): void {
    // TODO: Implement
    throw new Error('Not implemented');
  }

  async stopStreaming(): Promise<STTResult | null> {
    // TODO: Implement
    return null;
  }

  disconnect(): void {
    // TODO: Implement
  }
}
```

Create similar structures for LLM and TTS providers.

- [ ] STT provider interface created
- [ ] LLM provider interface created
- [ ] TTS provider interface created
- [ ] Provider manager skeleton created

### 1.5 Audio Utilities

Create `src/lib/utils/audio.ts`:

```typescript
export async function getAudioStream(): Promise<MediaStream> {
  return navigator.mediaDevices.getUserMedia({
    audio: {
      sampleRate: 24000,
      channelCount: 1,
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    },
  });
}

export function createAudioContext(): AudioContext {
  return new AudioContext({ sampleRate: 24000 });
}

export async function playAudioBuffer(
  context: AudioContext,
  buffer: ArrayBuffer
): Promise<void> {
  const audioBuffer = await context.decodeAudioData(buffer.slice(0));
  const source = context.createBufferSource();
  source.buffer = audioBuffer;
  source.connect(context.destination);
  source.start();

  return new Promise((resolve) => {
    source.onended = () => resolve();
  });
}

export function pcmToFloat32(pcm: Int16Array): Float32Array {
  const float32 = new Float32Array(pcm.length);
  for (let i = 0; i < pcm.length; i++) {
    float32[i] = pcm[i] / 32768;
  }
  return float32;
}
```

- [ ] Audio utilities created
- [ ] PCM conversion implemented

### Phase 1 Verification

- [ ] Types are correctly defined
- [ ] API client can make requests
- [ ] Token manager handles refresh
- [ ] Provider interfaces defined
- [ ] Audio utilities work
- [ ] `npm run build` succeeds

---

## Phase 2: Authentication

**Goal**: Implement login, registration, and session management.

### 2.1 Auth Context

Create `src/contexts/auth-context.tsx`:

```typescript
'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { User, AuthTokens, Device } from '@/types';
import { apiClient, tokenManager } from '@/lib/api';

interface AuthContextValue {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, displayName?: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check for existing session
    checkAuth();
  }, []);

  async function checkAuth() {
    try {
      const token = await tokenManager.getValidToken();
      if (token) {
        const response = await apiClient.get<{ user: User }>('/api/auth/me');
        setUser(response.user);
      }
    } catch {
      // Not authenticated
    } finally {
      setIsLoading(false);
    }
  }

  async function login(email: string, password: string) {
    const device = await getDeviceInfo();
    const response = await apiClient.post<{
      user: User;
      tokens: AuthTokens;
    }>('/api/auth/login', { email, password, device });

    tokenManager.setTokens(response.tokens);
    setUser(response.user);
  }

  async function register(email: string, password: string, displayName?: string) {
    const device = await getDeviceInfo();
    const response = await apiClient.post<{
      user: User;
      tokens: AuthTokens;
    }>('/api/auth/register', { email, password, display_name: displayName, device });

    tokenManager.setTokens(response.tokens);
    setUser(response.user);
  }

  async function logout() {
    await apiClient.post('/api/auth/logout');
    tokenManager.clear();
    setUser(null);
  }

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isAuthenticated: !!user,
        login,
        register,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}

async function getDeviceInfo(): Promise<Device> {
  const fingerprint = await generateFingerprint();
  return {
    id: '',
    fingerprint,
    name: `${getBrowserName()} on ${getOSName()}`,
    type: 'web',
  };
}

function generateFingerprint(): Promise<string> {
  // Simplified fingerprint
  const data = [
    navigator.userAgent,
    navigator.language,
    screen.width,
    screen.height,
  ].join('|');

  return crypto.subtle.digest('SHA-256', new TextEncoder().encode(data))
    .then(hash => Array.from(new Uint8Array(hash))
      .map(b => b.toString(16).padStart(2, '0'))
      .join(''));
}

function getBrowserName(): string {
  const ua = navigator.userAgent;
  if (ua.includes('Chrome')) return 'Chrome';
  if (ua.includes('Safari')) return 'Safari';
  if (ua.includes('Firefox')) return 'Firefox';
  return 'Unknown';
}

function getOSName(): string {
  const ua = navigator.userAgent;
  if (ua.includes('Mac')) return 'macOS';
  if (ua.includes('Windows')) return 'Windows';
  if (ua.includes('Linux')) return 'Linux';
  if (ua.includes('iPhone') || ua.includes('iPad')) return 'iOS';
  if (ua.includes('Android')) return 'Android';
  return 'Unknown';
}
```

- [ ] Auth context created
- [ ] Login function works
- [ ] Logout function works

### 2.2 Login Page

Create `src/app/(auth)/login/page.tsx`:

```typescript
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/auth-context';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

export default function LoginPage() {
  const router = useRouter();
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      await login(email, password);
      router.push('/session');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full p-8 bg-white rounded-lg shadow">
        <h1 className="text-2xl font-bold mb-6">Sign In</h1>

        <form onSubmit={handleSubmit} className="space-y-4">
          {error && (
            <div className="p-3 bg-red-50 text-red-600 rounded">{error}</div>
          )}

          <Input
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />

          <Input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />

          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading ? 'Signing in...' : 'Sign In'}
          </Button>
        </form>
      </div>
    </div>
  );
}
```

- [ ] Login page created
- [ ] Form validation works
- [ ] Error handling works

### 2.3 UI Components

Create basic UI components in `src/components/ui/`:

- [ ] `button.tsx` created
- [ ] `input.tsx` created
- [ ] `card.tsx` created

### 2.4 Protected Routes

Create `src/components/auth/protected-route.tsx`:

```typescript
'use client';

import { useAuth } from '@/contexts/auth-context';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [isAuthenticated, isLoading, router]);

  if (isLoading) {
    return <div>Loading...</div>;
  }

  if (!isAuthenticated) {
    return null;
  }

  return <>{children}</>;
}
```

- [ ] Protected route component created
- [ ] Redirects work correctly

### Phase 2 Verification

- [ ] Can register new user
- [ ] Can login with credentials
- [ ] Protected routes redirect to login
- [ ] Logout clears session
- [ ] Token refresh works

---

## Phase 3: Voice Pipeline

**Goal**: Implement OpenAI Realtime WebRTC connection and audio handling.

### 3.1 WebRTC Manager

Create `src/lib/providers/webrtc-manager.ts`:

```typescript
export class WebRTCManager {
  private pc: RTCPeerConnection | null = null;
  private dataChannel: RTCDataChannel | null = null;
  private audioElement: HTMLAudioElement | null = null;

  async connect(ephemeralToken: string): Promise<void> {
    this.pc = new RTCPeerConnection();

    // Get microphone
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        sampleRate: 24000,
        channelCount: 1,
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      },
    });

    // Add audio track
    stream.getAudioTracks().forEach(track => {
      this.pc!.addTrack(track, stream);
    });

    // Handle remote audio
    this.pc.ontrack = (event) => {
      this.audioElement = new Audio();
      this.audioElement.srcObject = event.streams[0];
      this.audioElement.play();
    };

    // Create data channel
    this.dataChannel = this.pc.createDataChannel('oai-events');
    this.dataChannel.onmessage = this.handleMessage.bind(this);

    // Create and set local description
    const offer = await this.pc.createOffer();
    await this.pc.setLocalDescription(offer);

    // Connect to OpenAI
    const response = await fetch('https://api.openai.com/v1/realtime', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ephemeralToken}`,
        'Content-Type': 'application/sdp',
      },
      body: offer.sdp,
    });

    const answerSdp = await response.text();
    await this.pc.setRemoteDescription({ type: 'answer', sdp: answerSdp });
  }

  private handleMessage(event: MessageEvent) {
    const message = JSON.parse(event.data);
    // Handle different message types
    console.log('Received:', message);
  }

  sendEvent(event: object) {
    if (this.dataChannel?.readyState === 'open') {
      this.dataChannel.send(JSON.stringify(event));
    }
  }

  disconnect() {
    this.audioElement?.pause();
    this.dataChannel?.close();
    this.pc?.close();
    this.pc = null;
    this.dataChannel = null;
    this.audioElement = null;
  }
}
```

- [ ] WebRTC manager created
- [ ] Can establish connection
- [ ] Audio flows both directions

### 3.2 Ephemeral Token Endpoint

Create `src/app/api/realtime/token/route.ts`:

```typescript
import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  // Get OpenAI API key from server environment
  const apiKey = process.env.OPENAI_API_KEY;

  if (!apiKey) {
    return NextResponse.json(
      { error: 'OpenAI API key not configured' },
      { status: 500 }
    );
  }

  // Request ephemeral token from OpenAI
  const response = await fetch('https://api.openai.com/v1/realtime/sessions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-realtime-preview',
      voice: 'coral',
    }),
  });

  if (!response.ok) {
    return NextResponse.json(
      { error: 'Failed to get ephemeral token' },
      { status: response.status }
    );
  }

  const data = await response.json();
  return NextResponse.json({ token: data.client_secret.value });
}
```

- [ ] Token endpoint created
- [ ] Returns valid ephemeral token

### 3.3 Session State Machine

Create `src/lib/session/machine.ts`:

```typescript
import { createMachine, assign } from 'xstate';
import { SessionState, Message } from '@/types';

interface SessionContext {
  conversationHistory: Message[];
  currentUtterance: string;
  aiResponse: string;
  error: Error | null;
}

type SessionEvent =
  | { type: 'START_SESSION' }
  | { type: 'STT_INTERIM'; text: string }
  | { type: 'STT_FINAL'; text: string }
  | { type: 'LLM_TOKEN'; content: string }
  | { type: 'LLM_COMPLETE' }
  | { type: 'TTS_START' }
  | { type: 'TTS_COMPLETE' }
  | { type: 'USER_INTERRUPT' }
  | { type: 'INTERRUPT_CONFIRMED' }
  | { type: 'INTERRUPT_CANCELLED' }
  | { type: 'PAUSE' }
  | { type: 'RESUME' }
  | { type: 'STOP' }
  | { type: 'ERROR'; error: Error };

export const sessionMachine = createMachine({
  id: 'session',
  initial: 'idle',
  context: {
    conversationHistory: [],
    currentUtterance: '',
    aiResponse: '',
    error: null,
  } as SessionContext,
  states: {
    idle: {
      on: {
        START_SESSION: 'userSpeaking',
      },
    },
    userSpeaking: {
      on: {
        STT_INTERIM: {
          actions: assign({
            currentUtterance: (_, event) => event.text,
          }),
        },
        STT_FINAL: {
          target: 'processingUserUtterance',
          actions: assign({
            currentUtterance: (_, event) => event.text,
          }),
        },
        PAUSE: 'paused',
        ERROR: {
          target: 'error',
          actions: assign({ error: (_, event) => event.error }),
        },
      },
    },
    processingUserUtterance: {
      entry: assign({
        conversationHistory: (context) => [
          ...context.conversationHistory,
          { role: 'user', content: context.currentUtterance, timestamp: new Date() },
        ],
      }),
      always: 'aiThinking',
    },
    aiThinking: {
      on: {
        LLM_TOKEN: {
          actions: assign({
            aiResponse: (context, event) => context.aiResponse + event.content,
          }),
        },
        TTS_START: 'aiSpeaking',
        LLM_COMPLETE: {
          actions: assign({
            conversationHistory: (context) => [
              ...context.conversationHistory,
              { role: 'assistant', content: context.aiResponse, timestamp: new Date() },
            ],
            aiResponse: '',
          }),
        },
        PAUSE: 'paused',
        ERROR: {
          target: 'error',
          actions: assign({ error: (_, event) => event.error }),
        },
      },
    },
    aiSpeaking: {
      on: {
        TTS_COMPLETE: 'userSpeaking',
        USER_INTERRUPT: 'interrupted',
        PAUSE: 'paused',
      },
    },
    interrupted: {
      after: {
        600: [
          { target: 'userSpeaking', cond: 'userStillSpeaking' },
          { target: 'aiSpeaking' },
        ],
      },
      on: {
        INTERRUPT_CONFIRMED: 'userSpeaking',
        INTERRUPT_CANCELLED: 'aiSpeaking',
      },
    },
    paused: {
      on: {
        RESUME: 'userSpeaking',
        STOP: 'idle',
      },
    },
    error: {
      on: {
        RETRY: 'idle',
      },
    },
  },
});
```

- [ ] State machine created
- [ ] All states defined
- [ ] Transitions work correctly

### 3.4 Session Context

Create `src/contexts/session-context.tsx`:

```typescript
'use client';

import { createContext, useContext, ReactNode } from 'react';
import { useMachine } from '@xstate/react';
import { sessionMachine } from '@/lib/session/machine';
import { WebRTCManager } from '@/lib/providers/webrtc-manager';
import { Message, SessionState } from '@/types';

interface SessionContextValue {
  state: SessionState;
  conversationHistory: Message[];
  currentUtterance: string;
  aiResponse: string;
  startSession: () => Promise<void>;
  pauseSession: () => void;
  resumeSession: () => void;
  stopSession: () => void;
}

const SessionContext = createContext<SessionContextValue | null>(null);

export function SessionProvider({ children }: { children: ReactNode }) {
  const [snapshot, send] = useMachine(sessionMachine);
  const webrtc = new WebRTCManager();

  async function startSession() {
    // Get ephemeral token
    const response = await fetch('/api/realtime/token', { method: 'POST' });
    const { token } = await response.json();

    // Connect WebRTC
    await webrtc.connect(token);

    send({ type: 'START_SESSION' });
  }

  function pauseSession() {
    send({ type: 'PAUSE' });
  }

  function resumeSession() {
    send({ type: 'RESUME' });
  }

  function stopSession() {
    webrtc.disconnect();
    send({ type: 'STOP' });
  }

  return (
    <SessionContext.Provider
      value={{
        state: snapshot.value as SessionState,
        conversationHistory: snapshot.context.conversationHistory,
        currentUtterance: snapshot.context.currentUtterance,
        aiResponse: snapshot.context.aiResponse,
        startSession,
        pauseSession,
        resumeSession,
        stopSession,
      }}
    >
      {children}
    </SessionContext.Provider>
  );
}

export function useSession() {
  const context = useContext(SessionContext);
  if (!context) {
    throw new Error('useSession must be used within SessionProvider');
  }
  return context;
}
```

- [ ] Session context created
- [ ] WebRTC integration works
- [ ] State machine responds to events

### Phase 3 Verification

- [ ] WebRTC connects to OpenAI
- [ ] Microphone audio captured
- [ ] AI audio plays back
- [ ] State transitions work
- [ ] Can start/pause/stop session

---

## Phase 4: Session UI

**Goal**: Implement the session interface with transcript and visual panels.

### 4.1 Layout Components

Create `src/components/layout/header.tsx`:

- [ ] Header with session status, timer, controls

Create `src/components/layout/tab-bar.tsx`:

- [ ] Tab bar with 5 tabs

### 4.2 Session Page

Create `src/app/session/page.tsx`:

- [ ] Full session layout
- [ ] Responsive split/stack

### 4.3 Transcript Panel

Create `src/components/session/transcript-panel.tsx`:

- [ ] Message list
- [ ] Current utterance display
- [ ] Voice indicator
- [ ] Auto-scroll

### 4.4 Visual Panel

Create `src/components/session/visual-panel.tsx`:

- [ ] Asset viewer router
- [ ] Thumbnail strip

### 4.5 Voice Indicator

Create `src/components/session/voice-indicator.tsx`:

- [ ] Waveform or level display
- [ ] State-dependent styling

### Phase 4 Verification

- [ ] Session page renders
- [ ] Transcript updates in real-time
- [ ] Visual panel displays assets
- [ ] Responsive on mobile
- [ ] Controls work

---

## Phase 5: Curriculum Integration

**Goal**: Implement curriculum browsing and UMCF visual asset rendering.

### 5.1 Curriculum API

Create `src/lib/api/curriculum.ts`:

- [ ] List curricula
- [ ] Get curriculum detail
- [ ] Get curriculum with assets

### 5.2 Curriculum Page

Create `src/app/curriculum/page.tsx`:

- [ ] Curriculum list
- [ ] Topic selection
- [ ] Start session with topic

### 5.3 Visual Asset Renderers

Create `src/components/session/visual-assets/`:

- [ ] `formula-renderer.tsx` (KaTeX)
- [ ] `map-viewer.tsx` (Leaflet)
- [ ] `diagram-viewer.tsx` (Mermaid)
- [ ] `chart-viewer.tsx` (Chart.js)
- [ ] `image-viewer.tsx`

### Phase 5 Verification

- [ ] Can browse curricula
- [ ] Can select topic
- [ ] Visual assets render correctly
- [ ] Formula LaTeX works
- [ ] Maps display properly

---

## Phase 6: Provider Implementations

**Goal**: Implement fallback providers for non-WebRTC scenarios.

### 6.1 Deepgram STT

Create `src/lib/providers/stt/deepgram.ts`:

- [ ] WebSocket connection
- [ ] Streaming transcription
- [ ] Word timestamps

### 6.2 ElevenLabs TTS

Create `src/lib/providers/tts/elevenlabs.ts`:

- [ ] Streaming synthesis
- [ ] Voice configuration

### 6.3 Anthropic LLM

Create `src/lib/providers/llm/anthropic.ts`:

- [ ] Server-Sent Events streaming
- [ ] Message formatting

### 6.4 Self-hosted Endpoints

Create `src/lib/providers/*/self-hosted.ts`:

- [ ] Ollama LLM
- [ ] Piper/VibeVoice TTS

### 6.5 Provider Switching

- [ ] Runtime provider selection
- [ ] Configuration UI

### Phase 6 Verification

- [ ] All providers implemented
- [ ] Can switch providers
- [ ] Fallback works when WebRTC fails

---

## Phase 7: Polish

**Goal**: Error handling, offline detection, analytics, optimization.

### 7.1 Error Handling

- [ ] Global error boundary
- [ ] Toast notifications
- [ ] Retry logic

### 7.2 Offline Detection

- [ ] Network status monitoring
- [ ] Graceful degradation
- [ ] Reconnection logic

### 7.3 Telemetry

- [ ] Metrics collection
- [ ] Upload to server
- [ ] Cost tracking display

### 7.4 Performance

- [ ] Code splitting
- [ ] Lazy loading
- [ ] Memory management

### 7.5 Accessibility

- [ ] Keyboard navigation
- [ ] Screen reader support
- [ ] Focus management

### Phase 7 Verification

- [ ] Errors handled gracefully
- [ ] Offline state shown
- [ ] Performance acceptable
- [ ] Accessibility audit passes

---

## Final Checklist

- [ ] All phases completed
- [ ] `npm run build` succeeds
- [ ] `npm run lint` passes
- [ ] Manual testing on Chrome
- [ ] Manual testing on Safari
- [ ] Manual testing on mobile
- [ ] Documentation updated

---

## Implementation Notes

### Key Files Reference

| File | Purpose |
|------|---------|
| `WEB_CLIENT_TDD.md` | Full technical spec |
| `docs/API_REFERENCE.md` | Server endpoints |
| `docs/UMCF_SPECIFICATION.md` | Curriculum format |
| `docs/PROVIDER_GUIDE.md` | Provider integration |
| `docs/AUTHENTICATION.md` | Auth flow |

### Common Issues

1. **WebRTC not working**: Check browser permissions, HTTPS required
2. **CORS errors**: Ensure API proxy configured
3. **Audio not playing**: Check autoplay policies
4. **Token refresh fails**: Check cookie settings

### Testing Approach

1. Unit test utilities and helpers
2. Integration test API client
3. E2E test critical flows
4. Manual test voice features

---

*End of Bootstrap Guide*
