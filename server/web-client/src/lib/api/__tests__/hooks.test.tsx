/**
 * SWR Hooks Tests
 */

import { describe, it, expect, beforeEach, vi, type Mock } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { SWRConfig } from 'swr';
import { type ReactNode } from 'react';
import {
  useUser,
  useCurricula,
  useCurriculum,
  useHealth,
  useSessionHistory,
  useImportSources,
  usePlugins,
} from '../hooks';
import { tokenManager } from '../token-manager';
import * as client from '../client';
import {
  mockUser,
  mockCurricula,
  mockCurriculum,
  mockHealthResponse,
} from '@/__tests__/mocks';

// Mock the client module
vi.mock('../client', () => ({
  get: vi.fn(),
  post: vi.fn(),
  ApiError: class ApiError extends Error {
    constructor(
      message: string,
      public status: number,
      public code: string
    ) {
      super(message);
    }
    isAuthError() {
      return this.status === 401;
    }
  },
}));

// Mock tokenManager
vi.mock('../token-manager', () => ({
  tokenManager: {
    hasTokens: vi.fn(),
  },
}));

// Wrapper to provide SWR configuration for tests
function createWrapper() {
  return function Wrapper({ children }: { children: ReactNode }) {
    return (
      <SWRConfig
        value={{
          dedupingInterval: 0,
          provider: () => new Map(),
        }}
      >
        {children}
      </SWRConfig>
    );
  };
}

describe('SWR Hooks', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (tokenManager.hasTokens as Mock).mockReturnValue(true);
  });

  describe('useUser', () => {
    it('should fetch current user when tokens are available', async () => {
      (client.get as Mock).mockResolvedValue({ user: mockUser });

      const { result } = renderHook(() => useUser(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.user).toEqual(mockUser);
      });

      expect(client.get).toHaveBeenCalledWith('/auth/me');
    });

    it('should not fetch when no tokens are available', async () => {
      (tokenManager.hasTokens as Mock).mockReturnValue(false);

      const { result } = renderHook(() => useUser(), {
        wrapper: createWrapper(),
      });

      // Wait a bit and verify no fetch was made
      await new Promise((resolve) => setTimeout(resolve, 50));

      expect(client.get).not.toHaveBeenCalled();
      expect(result.current.user).toBeUndefined();
    });
  });

  describe('useCurricula', () => {
    it('should fetch curricula list', async () => {
      (client.get as Mock).mockResolvedValue({ curricula: mockCurricula });

      const { result } = renderHook(() => useCurricula(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.curricula).toEqual(mockCurricula);
      });

      expect(client.get).toHaveBeenCalledWith('/curricula');
    });

    it('should return empty array while loading', () => {
      (client.get as Mock).mockImplementation(() => new Promise(() => {}));

      const { result } = renderHook(() => useCurricula(), {
        wrapper: createWrapper(),
      });

      expect(result.current.curricula).toEqual([]);
    });
  });

  describe('useCurriculum', () => {
    it('should fetch single curriculum when id is provided', async () => {
      (client.get as Mock).mockResolvedValue({ curriculum: mockCurriculum });

      const { result } = renderHook(() => useCurriculum('curriculum-123'), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.curriculum).toEqual(mockCurriculum);
      });

      expect(client.get).toHaveBeenCalledWith('/curricula/curriculum-123');
    });

    it('should not fetch when id is null', async () => {
      const { result } = renderHook(() => useCurriculum(null), {
        wrapper: createWrapper(),
      });

      await new Promise((resolve) => setTimeout(resolve, 50));

      expect(client.get).not.toHaveBeenCalled();
      expect(result.current.curriculum).toBeUndefined();
    });

    it('should not fetch when id is undefined', async () => {
      const { result } = renderHook(() => useCurriculum(undefined), {
        wrapper: createWrapper(),
      });

      await new Promise((resolve) => setTimeout(resolve, 50));

      expect(client.get).not.toHaveBeenCalled();
      expect(result.current.curriculum).toBeUndefined();
    });
  });

  describe('useHealth', () => {
    it('should fetch server health', async () => {
      (client.get as Mock).mockResolvedValue(mockHealthResponse);

      const { result } = renderHook(() => useHealth(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.data).toEqual(mockHealthResponse);
      });

      expect(client.get).toHaveBeenCalledWith('/health');
    });
  });

  describe('useSessionHistory', () => {
    it('should fetch session history', async () => {
      const mockSessions = [
        { id: 'session-1', curriculum_id: 'curriculum-123' },
        { id: 'session-2', curriculum_id: 'curriculum-456' },
      ];
      (client.get as Mock).mockResolvedValue({ sessions: mockSessions });

      const { result } = renderHook(() => useSessionHistory(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.sessions).toEqual(mockSessions);
      });

      expect(client.get).toHaveBeenCalledWith('/sessions/history');
    });

    it('should return empty array when no sessions', () => {
      (client.get as Mock).mockImplementation(() => new Promise(() => {}));

      const { result } = renderHook(() => useSessionHistory(), {
        wrapper: createWrapper(),
      });

      expect(result.current.sessions).toEqual([]);
    });
  });

  describe('useImportSources', () => {
    it('should fetch import sources', async () => {
      const mockSources = [
        { id: 'source-1', name: 'Khan Academy' },
        { id: 'source-2', name: 'MIT OCW' },
      ];
      (client.get as Mock).mockResolvedValue({ success: true, sources: mockSources });

      const { result } = renderHook(() => useImportSources(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.sources).toEqual(mockSources);
      });

      expect(client.get).toHaveBeenCalledWith('/import/sources');
    });

    it('should return empty array while loading', () => {
      (client.get as Mock).mockImplementation(() => new Promise(() => {}));

      const { result } = renderHook(() => useImportSources(), {
        wrapper: createWrapper(),
      });

      expect(result.current.sources).toEqual([]);
    });
  });

  describe('usePlugins', () => {
    it('should fetch plugins list', async () => {
      const mockPlugins = [
        { plugin_id: 'plugin-1', name: 'Test Plugin', enabled: true },
      ];
      (client.get as Mock).mockResolvedValue({
        success: true,
        plugins: mockPlugins,
        first_run: false,
      });

      const { result } = renderHook(() => usePlugins(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.plugins).toEqual(mockPlugins);
        expect(result.current.firstRun).toBe(false);
      });

      expect(client.get).toHaveBeenCalledWith('/plugins');
    });

    it('should handle first_run flag', async () => {
      (client.get as Mock).mockResolvedValue({
        success: true,
        plugins: [],
        first_run: true,
      });

      const { result } = renderHook(() => usePlugins(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.firstRun).toBe(true);
      });
    });
  });

  describe('error handling', () => {
    it('should handle API errors', async () => {
      const error = new (client.ApiError as unknown as new (message: string, status: number, code: string) => Error)(
        'Not found',
        404,
        'NOT_FOUND'
      );
      (client.get as Mock).mockRejectedValue(error);

      const { result } = renderHook(() => useCurricula(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.error).toBeDefined();
      });

      expect(result.current.curricula).toEqual([]);
    });
  });
});
