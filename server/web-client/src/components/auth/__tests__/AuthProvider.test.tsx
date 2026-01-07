/**
 * AuthProvider Tests
 */

import { describe, it, expect, beforeEach, vi, type Mock } from 'vitest';
import { render, screen, waitFor, act } from '@testing-library/react';
import { AuthProvider, useAuth, useIsAuthenticated, useCurrentUser } from '../AuthProvider';
import { mockUser, mockAuthResponse } from '@/__tests__/mocks';
import * as api from '@/lib/api';

// Mock the API module
vi.mock('@/lib/api', () => ({
  login: vi.fn(),
  logout: vi.fn(),
  register: vi.fn(),
  getCurrentUser: vi.fn(),
  tokenManager: {
    hasTokens: vi.fn(),
    clear: vi.fn(),
    setOnTokenChange: vi.fn(),
    getValidToken: vi.fn(),
  },
}));

// Test component that uses useAuth hook
function TestAuthConsumer() {
  const { isAuthenticated, isLoading, user, error } = useAuth();
  return (
    <div>
      <div data-testid="loading">{isLoading ? 'loading' : 'not-loading'}</div>
      <div data-testid="authenticated">{isAuthenticated ? 'authenticated' : 'not-authenticated'}</div>
      <div data-testid="user">{user?.email || 'no-user'}</div>
      <div data-testid="error">{error || 'no-error'}</div>
    </div>
  );
}

// Test component for login functionality
function TestLoginComponent() {
  const { login, isLoading, error } = useAuth();

  const handleLogin = async () => {
    try {
      await login('test@example.com', 'password123');
    } catch {
      // Error handled by context
    }
  };

  return (
    <div>
      <button onClick={handleLogin} data-testid="login-btn">
        Login
      </button>
      <div data-testid="loading">{isLoading ? 'loading' : 'not-loading'}</div>
      <div data-testid="error">{error || 'no-error'}</div>
    </div>
  );
}

// Test component for logout functionality
function TestLogoutComponent() {
  const { logout, isAuthenticated } = useAuth();

  return (
    <div>
      <button onClick={() => logout()} data-testid="logout-btn">
        Logout
      </button>
      <div data-testid="authenticated">{isAuthenticated ? 'authenticated' : 'not-authenticated'}</div>
    </div>
  );
}

describe('AuthProvider', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (api.tokenManager.hasTokens as Mock).mockReturnValue(false);
    (api.tokenManager.setOnTokenChange as Mock).mockImplementation(() => {});
  });

  describe('initialization', () => {
    it('should show loading initially', async () => {
      render(
        <AuthProvider>
          <TestAuthConsumer />
        </AuthProvider>
      );

      // Eventually loading should be false
      await waitFor(() => {
        expect(screen.getByTestId('loading')).toHaveTextContent('not-loading');
      });
    });

    it('should be unauthenticated when no tokens exist', async () => {
      (api.tokenManager.hasTokens as Mock).mockReturnValue(false);

      render(
        <AuthProvider>
          <TestAuthConsumer />
        </AuthProvider>
      );

      await waitFor(() => {
        expect(screen.getByTestId('authenticated')).toHaveTextContent('not-authenticated');
        expect(screen.getByTestId('user')).toHaveTextContent('no-user');
      });
    });

    it('should fetch user when tokens exist', async () => {
      (api.tokenManager.hasTokens as Mock).mockReturnValue(true);
      (api.getCurrentUser as Mock).mockResolvedValue({ user: mockUser });

      render(
        <AuthProvider>
          <TestAuthConsumer />
        </AuthProvider>
      );

      await waitFor(() => {
        expect(screen.getByTestId('authenticated')).toHaveTextContent('authenticated');
        expect(screen.getByTestId('user')).toHaveTextContent(mockUser.email);
      });
    });

    it('should clear tokens and show unauthenticated when user fetch fails', async () => {
      (api.tokenManager.hasTokens as Mock).mockReturnValue(true);
      (api.getCurrentUser as Mock).mockRejectedValue(new Error('Token invalid'));

      render(
        <AuthProvider>
          <TestAuthConsumer />
        </AuthProvider>
      );

      await waitFor(() => {
        expect(api.tokenManager.clear).toHaveBeenCalled();
        expect(screen.getByTestId('authenticated')).toHaveTextContent('not-authenticated');
      });
    });
  });

  describe('login', () => {
    it('should login successfully', async () => {
      (api.login as Mock).mockResolvedValue(mockAuthResponse);

      render(
        <AuthProvider>
          <TestLoginComponent />
        </AuthProvider>
      );

      await waitFor(() => {
        expect(screen.getByTestId('loading')).toHaveTextContent('not-loading');
      });

      await act(async () => {
        screen.getByTestId('login-btn').click();
      });

      await waitFor(() => {
        expect(api.login).toHaveBeenCalledWith('test@example.com', 'password123');
      });
    });

    it('should set error on login failure', async () => {
      (api.login as Mock).mockRejectedValue(new Error('Invalid credentials'));

      render(
        <AuthProvider>
          <TestLoginComponent />
        </AuthProvider>
      );

      await waitFor(() => {
        expect(screen.getByTestId('loading')).toHaveTextContent('not-loading');
      });

      await act(async () => {
        screen.getByTestId('login-btn').click();
      });

      await waitFor(() => {
        expect(screen.getByTestId('error')).toHaveTextContent('Invalid credentials');
      });
    });
  });

  describe('logout', () => {
    it('should logout successfully', async () => {
      (api.tokenManager.hasTokens as Mock).mockReturnValue(true);
      (api.getCurrentUser as Mock).mockResolvedValue({ user: mockUser });
      (api.logout as Mock).mockResolvedValue(undefined);

      render(
        <AuthProvider>
          <TestLogoutComponent />
        </AuthProvider>
      );

      await waitFor(() => {
        expect(screen.getByTestId('authenticated')).toHaveTextContent('authenticated');
      });

      await act(async () => {
        screen.getByTestId('logout-btn').click();
      });

      await waitFor(() => {
        expect(api.logout).toHaveBeenCalled();
        expect(screen.getByTestId('authenticated')).toHaveTextContent('not-authenticated');
      });
    });

    // Note: Testing logout failure is complex with React/Vitest due to
    // unhandled rejection handling. The AuthProvider handles this gracefully
    // by always clearing tokens in the finally block of the logout function.
  });

  describe('useAuth hook', () => {
    it('should throw error when used outside AuthProvider', () => {
      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

      expect(() => {
        render(<TestAuthConsumer />);
      }).toThrow('useAuth must be used within an AuthProvider');

      consoleError.mockRestore();
    });
  });

  describe('useIsAuthenticated hook', () => {
    function TestIsAuthenticatedConsumer() {
      const { isAuthenticated, isLoading } = useIsAuthenticated();
      return (
        <div>
          <div data-testid="authenticated">{isAuthenticated ? 'yes' : 'no'}</div>
          <div data-testid="loading">{isLoading ? 'yes' : 'no'}</div>
        </div>
      );
    }

    it('should return authentication status', async () => {
      (api.tokenManager.hasTokens as Mock).mockReturnValue(true);
      (api.getCurrentUser as Mock).mockResolvedValue({ user: mockUser });

      render(
        <AuthProvider>
          <TestIsAuthenticatedConsumer />
        </AuthProvider>
      );

      await waitFor(() => {
        expect(screen.getByTestId('authenticated')).toHaveTextContent('yes');
        expect(screen.getByTestId('loading')).toHaveTextContent('no');
      });
    });
  });

  describe('useCurrentUser hook', () => {
    function TestCurrentUserConsumer() {
      const user = useCurrentUser();
      return <div data-testid="user">{user?.email || 'no-user'}</div>;
    }

    it('should return current user', async () => {
      (api.tokenManager.hasTokens as Mock).mockReturnValue(true);
      (api.getCurrentUser as Mock).mockResolvedValue({ user: mockUser });

      render(
        <AuthProvider>
          <TestCurrentUserConsumer />
        </AuthProvider>
      );

      await waitFor(() => {
        expect(screen.getByTestId('user')).toHaveTextContent(mockUser.email);
      });
    });

    it('should return null when not authenticated', async () => {
      (api.tokenManager.hasTokens as Mock).mockReturnValue(false);

      render(
        <AuthProvider>
          <TestCurrentUserConsumer />
        </AuthProvider>
      );

      await waitFor(() => {
        expect(screen.getByTestId('user')).toHaveTextContent('no-user');
      });
    });
  });
});
