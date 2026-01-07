/**
 * Test Mocks
 *
 * Centralized mock data and utilities for testing.
 */

import * as React from 'react';
import type { User, TokenPair, AuthResponse, CurriculumSummary, Curriculum, Topic, CatalogId } from '@/types';

// ===== Mock Users =====

export const mockUser: User = {
  id: 'user-123',
  email: 'test@example.com',
  email_verified: true,
  display_name: 'Test User',
  avatar_url: null,
  locale: 'en-US',
  timezone: 'America/New_York',
  role: 'user',
  mfa_enabled: false,
  created_at: '2024-01-01T00:00:00Z',
  last_login_at: '2024-01-15T12:00:00Z',
};

export const mockAdminUser: User = {
  ...mockUser,
  id: 'admin-123',
  email: 'admin@example.com',
  display_name: 'Admin User',
  role: 'admin',
};

// ===== Mock Tokens =====

export const mockTokenPair: TokenPair = {
  access_token: 'mock-access-token-12345',
  refresh_token: 'mock-refresh-token-67890',
  token_type: 'Bearer',
  expires_in: 900, // 15 minutes
};

export const mockExpiredTokenPair: TokenPair = {
  ...mockTokenPair,
  expires_in: 0,
};

// ===== Mock Auth Responses =====

export const mockAuthResponse: AuthResponse = {
  user: mockUser,
  device: {
    id: 'device-123',
  },
  tokens: mockTokenPair,
};

// ===== Mock Curricula =====

export const mockCurriculumSummary: CurriculumSummary = {
  id: 'curriculum-123',
  title: 'Introduction to Physics',
  description: 'A comprehensive introduction to physics concepts',
  author: 'Test Author',
  language: 'en',
  created_at: '2024-01-01T00:00:00Z',
  updated_at: '2024-01-15T00:00:00Z',
  topics_count: 10,
  status: 'published',
};

export const mockCurricula: CurriculumSummary[] = [
  mockCurriculumSummary,
  {
    ...mockCurriculumSummary,
    id: 'curriculum-456',
    title: 'Advanced Mathematics',
    topics_count: 15,
  },
  {
    ...mockCurriculumSummary,
    id: 'curriculum-789',
    title: 'World History',
    topics_count: 20,
  },
];

const mockTopicId: CatalogId = {
  catalog: 'umcf',
  value: 'topic-1',
};

const mockTopic: Topic = {
  id: mockTopicId,
  title: 'Introduction',
  type: 'topic',
  description: 'An introduction to the subject',
  orderIndex: 1,
};

export const mockCurriculum: Curriculum = {
  ...mockCurriculumSummary,
  topics: [
    mockTopic,
    {
      ...mockTopic,
      id: { catalog: 'umcf', value: 'topic-2' },
      title: 'Core Concepts',
      description: 'Core concepts and fundamentals',
      orderIndex: 2,
    },
  ],
};

// ===== Mock API Responses =====

export const mockHealthResponse = {
  status: 'healthy' as const,
  server_time: '2024-01-15T12:00:00Z',
  uptime_seconds: 86400,
  version: '1.0.0',
};

export const mockErrorResponse = {
  error: 'error_code',
  message: 'An error occurred',
  code: 'ERROR_CODE',
};

// ===== Mock Fetch Helpers =====

export function createMockResponse<T>(data: T, status = 200): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    statusText: status === 200 ? 'OK' : 'Error',
    headers: new Headers({
      'Content-Type': 'application/json',
    }),
    json: async () => data,
    text: async () => JSON.stringify(data),
  } as Response;
}

export function createMockErrorResponse(
  error: string,
  message: string,
  status = 400
): Response {
  return createMockResponse({ error, message, code: error.toUpperCase() }, status);
}

// ===== Test Wrapper Utilities =====

export function createTestWrapper({ children }: { children: React.ReactNode }) {
  return children;
}
