'use client';

import { useEffect } from 'react';
import { WebSocketProvider } from '@/lib/websocket-provider';
import { FeatureFlagProvider } from '@/lib/feature-flags/context';
import type { FeatureFlagConfig } from '@/lib/feature-flags/types';

interface ProvidersProps {
  children: React.ReactNode;
}

// Feature flag configuration for development
// Uses environment variables with localhost fallbacks
const featureFlagConfig: FeatureFlagConfig = {
  proxyUrl: process.env.NEXT_PUBLIC_FEATURE_FLAG_URL || 'http://localhost:3063/proxy',
  clientKey: process.env.NEXT_PUBLIC_FEATURE_FLAG_KEY || 'proxy-client-key',
  appName: 'UnaMentis-Web',
  refreshInterval: 30000,
  enableCache: true,
};

export function Providers({ children }: ProvidersProps) {
  return (
    <FeatureFlagProvider config={featureFlagConfig}>
      <WebSocketProvider>{children}</WebSocketProvider>
    </FeatureFlagProvider>
  );
}
