/**
 * Token Manager
 *
 * In-memory token storage with automatic refresh before expiry.
 * Access tokens are stored in memory only (never localStorage) for security.
 * Refresh tokens are stored securely (httpOnly cookie or encrypted storage).
 */

import type { TokenPair } from '@/types';

// Refresh tokens 1 minute before expiry
const REFRESH_BUFFER_MS = 60 * 1000;

// Singleton instance
let instance: TokenManager | null = null;

export class TokenManager {
  private accessToken: string | null = null;
  private refreshToken: string | null = null;
  private expiresAt = 0;
  private refreshPromise: Promise<TokenPair | null> | null = null;
  private refreshCallback: ((refreshToken: string) => Promise<TokenPair>) | null = null;
  private onTokenChange: ((tokens: TokenPair | null) => void) | null = null;

  private constructor() {
    // Private constructor for singleton
  }

  static getInstance(): TokenManager {
    if (!instance) {
      instance = new TokenManager();
    }
    return instance;
  }

  /**
   * Set the callback function for refreshing tokens.
   * This is called when the access token is expired or about to expire.
   */
  setRefreshCallback(callback: (refreshToken: string) => Promise<TokenPair>): void {
    this.refreshCallback = callback;
  }

  /**
   * Set callback for token changes (for AuthProvider sync)
   */
  setOnTokenChange(callback: (tokens: TokenPair | null) => void): void {
    this.onTokenChange = callback;
  }

  /**
   * Store tokens after login/register/refresh.
   */
  setTokens(tokens: TokenPair): void {
    this.accessToken = tokens.access_token;
    this.refreshToken = tokens.refresh_token;
    // Calculate absolute expiry time
    this.expiresAt = Date.now() + tokens.expires_in * 1000;
    this.onTokenChange?.(tokens);
  }

  /**
   * Get the current access token.
   * Does NOT automatically refresh - use getValidToken() for that.
   */
  getAccessToken(): string | null {
    return this.accessToken;
  }

  /**
   * Get the refresh token.
   */
  getRefreshToken(): string | null {
    return this.refreshToken;
  }

  /**
   * Check if we have tokens stored.
   */
  hasTokens(): boolean {
    return this.accessToken !== null && this.refreshToken !== null;
  }

  /**
   * Check if the access token is expired or about to expire.
   */
  isAccessTokenExpired(): boolean {
    if (!this.accessToken) return true;
    return Date.now() > this.expiresAt - REFRESH_BUFFER_MS;
  }

  /**
   * Check if the access token is completely expired (past expiry, not just buffer).
   */
  isAccessTokenFullyExpired(): boolean {
    if (!this.accessToken) return true;
    return Date.now() > this.expiresAt;
  }

  /**
   * Get a valid access token, refreshing if necessary.
   * Deduplicates concurrent refresh requests.
   *
   * @throws Error if refresh fails or no tokens available
   */
  async getValidToken(): Promise<string> {
    // No tokens at all
    if (!this.accessToken || !this.refreshToken) {
      throw new Error('No authentication tokens available');
    }

    // Token is still valid
    if (!this.isAccessTokenExpired()) {
      return this.accessToken;
    }

    // Token needs refresh - deduplicate concurrent requests
    if (!this.refreshPromise) {
      this.refreshPromise = this.performRefresh();
    }

    try {
      const newTokens = await this.refreshPromise;
      if (!newTokens) {
        throw new Error('Token refresh failed');
      }
      return newTokens.access_token;
    } finally {
      this.refreshPromise = null;
    }
  }

  /**
   * Perform the actual token refresh.
   */
  private async performRefresh(): Promise<TokenPair | null> {
    if (!this.refreshToken) {
      return null;
    }

    if (!this.refreshCallback) {
      throw new Error('No refresh callback configured');
    }

    try {
      const newTokens = await this.refreshCallback(this.refreshToken);
      this.setTokens(newTokens);
      return newTokens;
    } catch {
      // Refresh failed - clear tokens
      this.clear();
      return null;
    }
  }

  /**
   * Clear all tokens (logout).
   */
  clear(): void {
    this.accessToken = null;
    this.refreshToken = null;
    this.expiresAt = 0;
    this.refreshPromise = null;
    this.onTokenChange?.(null);
  }

  /**
   * Get time remaining until token expires (ms).
   * Returns 0 if no token or already expired.
   */
  getTimeUntilExpiry(): number {
    if (!this.accessToken) return 0;
    const remaining = this.expiresAt - Date.now();
    return Math.max(0, remaining);
  }
}

// Export singleton instance
export const tokenManager = TokenManager.getInstance();
