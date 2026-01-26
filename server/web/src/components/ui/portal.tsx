'use client';

import { useRef, useState, useSyncExternalStore, type ReactNode } from 'react';
import { createPortal } from 'react-dom';

interface PortalProps {
  children: ReactNode;
}

// Client-side subscription that never changes
const subscribe = () => () => {};
const getSnapshot = () => true;
const getServerSnapshot = () => false;

/**
 * Portal component that renders children to document.body.
 * Useful for modals, tooltips, and other overlays that need to escape
 * stacking context constraints.
 *
 * Uses useSyncExternalStore to safely detect client-side mounting
 * without triggering cascading renders in useEffect.
 */
export function Portal({ children }: PortalProps) {
  const isClient = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  if (!isClient) {
    return null;
  }

  return createPortal(children, document.body);
}
