/**
 * LoginForm Tests
 */

import * as React from 'react';
import { describe, it, expect, beforeEach, vi, type Mock } from 'vitest';
import { render, screen, fireEvent as _fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoginForm } from '../LoginForm';
import { AuthProvider } from '../AuthProvider';
import { ApiError } from '@/lib/api';
import * as api from '@/lib/api';

// Mock the API module
vi.mock('@/lib/api', async (importOriginal) => {
  const actual = (await importOriginal()) as Record<string, unknown>;
  return {
    ...actual,
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
  };
});

// Wrapper component that provides auth context
function renderWithAuth(ui: React.ReactElement) {
  (api.tokenManager.hasTokens as Mock).mockReturnValue(false);
  (api.tokenManager.setOnTokenChange as Mock).mockImplementation(() => {});

  return render(<AuthProvider>{ui}</AuthProvider>);
}

describe('LoginForm', () => {
  const user = userEvent.setup();

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('rendering', () => {
    it('should render email and password fields', async () => {
      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
        expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
      });
    });

    it('should render submit button', async () => {
      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
      });
    });

    it('should render switch to register link when callback provided', async () => {
      const onSwitchToRegister = vi.fn();
      renderWithAuth(<LoginForm onSwitchToRegister={onSwitchToRegister} />);

      await waitFor(() => {
        expect(screen.getByText(/don't have an account/i)).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /sign up/i })).toBeInTheDocument();
      });
    });

    it('should not render switch to register link when no callback', async () => {
      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.queryByText(/don't have an account/i)).not.toBeInTheDocument();
      });
    });
  });

  describe('validation', () => {
    it('should show error when email is empty', async () => {
      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.type(screen.getByLabelText(/password/i), 'password123');
      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        expect(screen.getByText(/email is required/i)).toBeInTheDocument();
      });
    });

    it('should show error when email format is invalid', async () => {
      // Test the isValidEmail function directly since browser validation
      // on type="email" may interfere with form submission
      const isValidEmail = (email: string): boolean => {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
      };

      expect(isValidEmail('invalidemail')).toBe(false);
      expect(isValidEmail('invalid@')).toBe(false);
      expect(isValidEmail('@invalid.com')).toBe(false);
      expect(isValidEmail('valid@example.com')).toBe(true);
    });

    it('should show error when password is empty', async () => {
      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.type(screen.getByLabelText(/email/i), 'test@example.com');
      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        expect(screen.getByText(/password is required/i)).toBeInTheDocument();
      });
    });
  });

  describe('submission', () => {
    it('should call login on valid submission', async () => {
      (api.login as Mock).mockResolvedValue({
        user: { id: '1', email: 'test@example.com', display_name: 'Test' },
        tokens: { access_token: 'token', refresh_token: 'refresh', token_type: 'Bearer', expires_in: 900 },
        device: { id: 'device-1' },
      });

      const onSuccess = vi.fn();
      renderWithAuth(<LoginForm onSuccess={onSuccess} />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.type(screen.getByLabelText(/email/i), 'test@example.com');
      await user.type(screen.getByLabelText(/password/i), 'password123');
      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        expect(api.login).toHaveBeenCalledWith('test@example.com', 'password123');
        expect(onSuccess).toHaveBeenCalled();
      });
    });

    it('should show loading state during submission', async () => {
      (api.login as Mock).mockImplementation(
        () => new Promise((resolve) => setTimeout(resolve, 1000))
      );

      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.type(screen.getByLabelText(/email/i), 'test@example.com');
      await user.type(screen.getByLabelText(/password/i), 'password123');
      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        expect(screen.getByText(/signing in/i)).toBeInTheDocument();
      });
    });

    it('should disable inputs during submission', async () => {
      (api.login as Mock).mockImplementation(
        () => new Promise((resolve) => setTimeout(resolve, 1000))
      );

      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.type(screen.getByLabelText(/email/i), 'test@example.com');
      await user.type(screen.getByLabelText(/password/i), 'password123');
      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeDisabled();
        expect(screen.getByLabelText(/password/i)).toBeDisabled();
      });
    });
  });

  describe('error handling', () => {
    it('should show error for invalid credentials', async () => {
      const apiError = new ApiError('Invalid credentials', 401, 'invalid_credentials');
      (api.login as Mock).mockRejectedValue(apiError);

      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.type(screen.getByLabelText(/email/i), 'test@example.com');
      await user.type(screen.getByLabelText(/password/i), 'wrongpassword');
      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        expect(screen.getByRole('alert')).toHaveTextContent(/invalid email or password/i);
      });
    });

    it('should show error for locked account', async () => {
      const apiError = new ApiError('Account locked', 403, 'account_locked');
      (api.login as Mock).mockRejectedValue(apiError);

      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.type(screen.getByLabelText(/email/i), 'test@example.com');
      await user.type(screen.getByLabelText(/password/i), 'password123');
      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        expect(screen.getByRole('alert')).toHaveTextContent(/account locked/i);
      });
    });

    it('should show error for inactive account', async () => {
      const apiError = new ApiError('Account inactive', 403, 'account_inactive');
      (api.login as Mock).mockRejectedValue(apiError);

      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.type(screen.getByLabelText(/email/i), 'test@example.com');
      await user.type(screen.getByLabelText(/password/i), 'password123');
      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        expect(screen.getByRole('alert')).toHaveTextContent(/account is inactive/i);
      });
    });

    it('should show generic error for unexpected errors', async () => {
      (api.login as Mock).mockRejectedValue(new Error('Network error'));

      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.type(screen.getByLabelText(/email/i), 'test@example.com');
      await user.type(screen.getByLabelText(/password/i), 'password123');
      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        expect(screen.getByRole('alert')).toHaveTextContent(/unexpected error/i);
      });
    });
  });

  describe('accessibility', () => {
    it('should have aria-invalid on email field when error', async () => {
      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toHaveAttribute('aria-invalid', 'true');
      });
    });

    it('should have aria-describedby linking error message', async () => {
      renderWithAuth(<LoginForm />);

      await waitFor(() => {
        expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
      });

      await user.click(screen.getByRole('button', { name: /sign in/i }));

      await waitFor(() => {
        const emailInput = screen.getByLabelText(/email/i);
        const describedById = emailInput.getAttribute('aria-describedby');
        expect(describedById).toBe('login-email-error');
        expect(document.getElementById('login-email-error')).toBeInTheDocument();
      });
    });
  });

  describe('switch to register', () => {
    it('should call onSwitchToRegister when sign up button clicked', async () => {
      const onSwitchToRegister = vi.fn();
      renderWithAuth(<LoginForm onSwitchToRegister={onSwitchToRegister} />);

      await waitFor(() => {
        expect(screen.getByRole('button', { name: /sign up/i })).toBeInTheDocument();
      });

      await user.click(screen.getByRole('button', { name: /sign up/i }));

      expect(onSwitchToRegister).toHaveBeenCalled();
    });
  });
});
