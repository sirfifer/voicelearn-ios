'use client';

import { useEffect } from 'react';
import { WebSocketProvider } from '@/lib/websocket-provider';
import { FeatureFlagProvider } from '@/lib/feature-flags/context';
import type { FeatureFlagConfig } from '@/lib/feature-flags/types';
import { ToastProvider } from '@/components/ui/toast';
import { initializeTestHooks } from '@/lib/test-hooks';

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
  // Initialize test hooks for automated testing via Playwright
  useEffect(() => {
    // Use management server URL (defaults to localhost:8766)
    const serverUrl = process.env.NEXT_PUBLIC_MANAGEMENT_SERVER_URL || 'http://localhost:8766';
    initializeTestHooks(serverUrl);
  }, []);

  return (
    <FeatureFlagProvider config={featureFlagConfig}>
      <WebSocketProvider>
        <ToastProvider>{children}</ToastProvider>
      </WebSocketProvider>
    </FeatureFlagProvider>
  );
}
