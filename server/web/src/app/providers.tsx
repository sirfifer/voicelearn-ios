'use client';

import { WebSocketProvider } from '@/lib/websocket-provider';

interface ProvidersProps {
  children: React.ReactNode;
}

export function Providers({ children }: ProvidersProps) {
  return (
    <WebSocketProvider>
      {children}
    </WebSocketProvider>
  );
}
