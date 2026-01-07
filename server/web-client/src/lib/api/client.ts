/**
 * API Client
 *
 * Base fetch wrapper with authentication headers, error handling,
 * and automatic token refresh on 401 responses.
 */

import type { ApiErrorResponse, RateLimitInfo } from '@/types';
import { tokenManager } from './token-manager';

// Type alias for fetch RequestInit (avoids ESLint no-undef for DOM globals)
type FetchRequestInit = globalThis.RequestInit;

// API base URL - proxied through Next.js to avoid CORS
const API_BASE_URL = '/api';

// Management API URL for direct calls (development only)
const MANAGEMENT_API_URL = process.env.NEXT_PUBLIC_MANAGEMENT_API_URL || 'http://localhost:8766';

export interface ApiClientOptions {
  /** Skip adding Authorization header */
  skipAuth?: boolean;
  /** Use management API directly instead of Next.js proxy */
  direct?: boolean;
  /** Custom headers to merge */
  headers?: Record<string, string>;
  /** Request timeout in ms */
  timeout?: number;
}

export interface ApiRequestConfig extends FetchRequestInit {
  timeout?: number;
}

/**
 * Custom error class for API errors with additional context.
 */
export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly code: string,
    public readonly details?: Record<string, unknown>,
    public readonly rateLimit?: RateLimitInfo
  ) {
    super(message);
    this.name = 'ApiError';
  }

  static fromResponse(response: Response, body: ApiErrorResponse): ApiError {
    const rateLimit = extractRateLimitInfo(response);
    return new ApiError(
      body.message || body.error || 'An error occurred',
      response.status,
      body.code || body.error || 'UNKNOWN_ERROR',
      body.details,
      rateLimit
    );
  }

  /**
   * Check if this is an authentication error that requires re-login.
   */
  isAuthError(): boolean {
    return (
      this.status === 401 &&
      ['invalid_token', 'token_expired', 'token_reused'].includes(this.code)
    );
  }

  /**
   * Check if this is a rate limit error.
   */
  isRateLimitError(): boolean {
    return this.status === 429;
  }
}

/**
 * Extract rate limit information from response headers.
 */
function extractRateLimitInfo(response: Response): RateLimitInfo | undefined {
  const limit = response.headers.get('X-RateLimit-Limit');
  const remaining = response.headers.get('X-RateLimit-Remaining');
  const reset = response.headers.get('X-RateLimit-Reset');
  const window = response.headers.get('X-RateLimit-Window');

  if (limit && remaining && reset && window) {
    return {
      limit: parseInt(limit, 10),
      remaining: parseInt(remaining, 10),
      reset: parseInt(reset, 10),
      window: parseInt(window, 10),
    };
  }

  return undefined;
}

/**
 * Create a fetch request with timeout support.
 */
async function fetchWithTimeout(
  url: string,
  config: ApiRequestConfig
): Promise<Response> {
  const { timeout = 30000, ...fetchConfig } = config;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      ...fetchConfig,
      signal: controller.signal,
    });
    return response;
  } finally {
    clearTimeout(timeoutId);
  }
}

/**
 * Build the full URL for an API endpoint.
 */
function buildUrl(endpoint: string, direct: boolean = false): string {
  const baseUrl = direct ? MANAGEMENT_API_URL : API_BASE_URL;
  // Ensure endpoint starts with /
  const normalizedEndpoint = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
  return `${baseUrl}${normalizedEndpoint}`;
}

/**
 * Make an authenticated API request.
 *
 * @param endpoint - API endpoint (e.g., '/curricula', '/auth/me')
 * @param options - Request options
 * @returns Parsed JSON response
 * @throws ApiError on failure
 */
export async function apiRequest<T>(
  endpoint: string,
  options: ApiClientOptions & Omit<FetchRequestInit, 'headers'> = {}
): Promise<T> {
  const { skipAuth = false, direct = false, headers = {}, timeout, ...fetchOptions } = options;

  // Build headers
  const requestHeaders: Record<string, string> = {
    'Content-Type': 'application/json',
    ...headers,
  };

  // Add authorization header if not skipped
  if (!skipAuth && tokenManager.hasTokens()) {
    try {
      const token = await tokenManager.getValidToken();
      requestHeaders['Authorization'] = `Bearer ${token}`;
    } catch {
      // Token refresh failed - continue without auth
      // The request will fail with 401 if auth is required
    }
  }

  const url = buildUrl(endpoint, direct);
  const config: ApiRequestConfig = {
    ...fetchOptions,
    headers: requestHeaders,
    credentials: 'include', // Include cookies for httpOnly refresh tokens
    timeout,
  };

  const response = await fetchWithTimeout(url, config);

  // Handle no-content responses
  if (response.status === 204) {
    return {} as T;
  }

  // Parse response body
  let body: T | ApiErrorResponse;
  const contentType = response.headers.get('Content-Type') || '';

  if (contentType.includes('application/json')) {
    body = await response.json();
  } else {
    // Non-JSON response
    const text = await response.text();
    body = { error: 'invalid_response', message: text, code: 'INVALID_RESPONSE' };
  }

  // Handle error responses
  if (!response.ok) {
    const errorBody = body as ApiErrorResponse;
    throw ApiError.fromResponse(response, errorBody);
  }

  return body as T;
}

/**
 * GET request helper.
 */
export async function get<T>(
  endpoint: string,
  options?: ApiClientOptions
): Promise<T> {
  return apiRequest<T>(endpoint, { ...options, method: 'GET' });
}

/**
 * POST request helper.
 */
export async function post<T>(
  endpoint: string,
  data?: unknown,
  options?: ApiClientOptions
): Promise<T> {
  return apiRequest<T>(endpoint, {
    ...options,
    method: 'POST',
    body: data ? JSON.stringify(data) : undefined,
  });
}

/**
 * PUT request helper.
 */
export async function put<T>(
  endpoint: string,
  data?: unknown,
  options?: ApiClientOptions
): Promise<T> {
  return apiRequest<T>(endpoint, {
    ...options,
    method: 'PUT',
    body: data ? JSON.stringify(data) : undefined,
  });
}

/**
 * PATCH request helper.
 */
export async function patch<T>(
  endpoint: string,
  data?: unknown,
  options?: ApiClientOptions
): Promise<T> {
  return apiRequest<T>(endpoint, {
    ...options,
    method: 'PATCH',
    body: data ? JSON.stringify(data) : undefined,
  });
}

/**
 * DELETE request helper.
 */
export async function del<T>(
  endpoint: string,
  options?: ApiClientOptions
): Promise<T> {
  return apiRequest<T>(endpoint, { ...options, method: 'DELETE' });
}

/**
 * Upload file via multipart form data.
 */
export async function upload<T>(
  endpoint: string,
  formData: FormData,
  options?: Omit<ApiClientOptions, 'headers'>
): Promise<T> {
  const { skipAuth = false, direct = false, timeout } = options || {};

  const requestHeaders: Record<string, string> = {};

  // Add authorization header if not skipped
  if (!skipAuth && tokenManager.hasTokens()) {
    try {
      const token = await tokenManager.getValidToken();
      requestHeaders['Authorization'] = `Bearer ${token}`;
    } catch {
      // Token refresh failed
    }
  }

  const url = buildUrl(endpoint, direct);
  const config: ApiRequestConfig = {
    method: 'POST',
    headers: requestHeaders,
    body: formData,
    credentials: 'include',
    timeout,
  };

  const response = await fetchWithTimeout(url, config);

  const body = await response.json();

  if (!response.ok) {
    throw ApiError.fromResponse(response, body);
  }

  return body as T;
}
