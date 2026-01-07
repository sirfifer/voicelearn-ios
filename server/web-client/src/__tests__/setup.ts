/**
 * Vitest Test Setup
 *
 * This file runs before each test file.
 */

import '@testing-library/jest-dom';
import { vi, beforeEach, afterEach } from 'vitest';

// Mock window.matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

// Mock crypto.subtle for device fingerprinting
Object.defineProperty(global, 'crypto', {
  value: {
    subtle: {
      digest: vi.fn().mockImplementation(async () => new ArrayBuffer(32)),
    },
    getRandomValues: vi.fn().mockImplementation((array: Uint8Array) => {
      for (let i = 0; i < array.length; i++) {
        array[i] = Math.floor(Math.random() * 256);
      }
      return array;
    }),
  },
});

// Mock TextEncoder
global.TextEncoder = class TextEncoder {
  encode(input: string): Uint8Array {
    const encoder = new (require('util').TextEncoder)();
    return encoder.encode(input);
  }
} as unknown as typeof TextEncoder;

// Mock navigator properties
Object.defineProperty(navigator, 'userAgent', {
  value:
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  writable: true,
});

Object.defineProperty(navigator, 'language', {
  value: 'en-US',
  writable: true,
});

Object.defineProperty(navigator, 'hardwareConcurrency', {
  value: 8,
  writable: true,
});

// Mock screen properties
Object.defineProperty(screen, 'width', {
  value: 1920,
  writable: true,
});

Object.defineProperty(screen, 'height', {
  value: 1080,
  writable: true,
});

// Mock fetch
global.fetch = vi.fn();

// Reset all mocks between tests
beforeEach(() => {
  vi.clearAllMocks();
});

// Clean up after each test
afterEach(() => {
  vi.restoreAllMocks();
});
