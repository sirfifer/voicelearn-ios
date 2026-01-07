'use client';

/**
 * Login Form Component
 *
 * Email/password login form with validation and error handling.
 */

import { useState, useCallback, type FormEvent } from 'react';
import { useAuth } from './AuthProvider';
import { ApiError } from '@/lib/api';

interface LoginFormProps {
  /** Called after successful login */
  onSuccess?: () => void;
  /** Called when user wants to switch to register */
  onSwitchToRegister?: () => void;
  /** Custom class name */
  className?: string;
}

interface FormErrors {
  email?: string;
  password?: string;
  general?: string;
}

/**
 * Validate email format.
 */
function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function LoginForm({
  onSuccess,
  onSwitchToRegister,
  className = '',
}: LoginFormProps) {
  const { login, isLoading: authLoading } = useAuth();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [errors, setErrors] = useState<FormErrors>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  /**
   * Validate form inputs.
   */
  const validateForm = useCallback((): boolean => {
    const newErrors: FormErrors = {};

    if (!email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!isValidEmail(email)) {
      newErrors.email = 'Please enter a valid email address';
    }

    if (!password) {
      newErrors.password = 'Password is required';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }, [email, password]);

  /**
   * Handle form submission.
   */
  const handleSubmit = useCallback(
    async (e: FormEvent) => {
      e.preventDefault();

      if (!validateForm()) {
        return;
      }

      setIsSubmitting(true);
      setErrors({});

      try {
        await login(email, password);
        onSuccess?.();
      } catch (error) {
        if (error instanceof ApiError) {
          switch (error.code) {
            case 'invalid_credentials':
              setErrors({ general: 'Invalid email or password' });
              break;
            case 'account_locked':
              setErrors({
                general: 'Account locked. Please try again later.',
              });
              break;
            case 'account_inactive':
              setErrors({
                general: 'Account is inactive. Please contact support.',
              });
              break;
            default:
              setErrors({ general: error.message });
          }
        } else {
          setErrors({ general: 'An unexpected error occurred' });
        }
      } finally {
        setIsSubmitting(false);
      }
    },
    [email, password, login, validateForm, onSuccess]
  );

  const isLoading = authLoading || isSubmitting;

  return (
    <form onSubmit={handleSubmit} className={`space-y-4 ${className}`}>
      {/* General error message */}
      {errors.general && (
        <div
          className="rounded-md bg-red-50 p-3 text-sm text-red-700 dark:bg-red-900/20 dark:text-red-400"
          role="alert"
        >
          {errors.general}
        </div>
      )}

      {/* Email field */}
      <div>
        <label
          htmlFor="login-email"
          className="block text-sm font-medium text-gray-700 dark:text-gray-300"
        >
          Email
        </label>
        <input
          id="login-email"
          type="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={isLoading}
          aria-invalid={!!errors.email}
          aria-describedby={errors.email ? 'login-email-error' : undefined}
          className={`mt-1 block w-full rounded-md border px-3 py-2 shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:cursor-not-allowed disabled:bg-gray-100 dark:bg-gray-800 dark:text-white ${
            errors.email
              ? 'border-red-500 focus:border-red-500'
              : 'border-gray-300 focus:border-blue-500 dark:border-gray-600'
          }`}
          placeholder="you@example.com"
        />
        {errors.email && (
          <p
            id="login-email-error"
            className="mt-1 text-sm text-red-600 dark:text-red-400"
          >
            {errors.email}
          </p>
        )}
      </div>

      {/* Password field */}
      <div>
        <label
          htmlFor="login-password"
          className="block text-sm font-medium text-gray-700 dark:text-gray-300"
        >
          Password
        </label>
        <input
          id="login-password"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          disabled={isLoading}
          aria-invalid={!!errors.password}
          aria-describedby={errors.password ? 'login-password-error' : undefined}
          className={`mt-1 block w-full rounded-md border px-3 py-2 shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:cursor-not-allowed disabled:bg-gray-100 dark:bg-gray-800 dark:text-white ${
            errors.password
              ? 'border-red-500 focus:border-red-500'
              : 'border-gray-300 focus:border-blue-500 dark:border-gray-600'
          }`}
          placeholder="Enter your password"
        />
        {errors.password && (
          <p
            id="login-password-error"
            className="mt-1 text-sm text-red-600 dark:text-red-400"
          >
            {errors.password}
          </p>
        )}
      </div>

      {/* Submit button */}
      <button
        type="submit"
        disabled={isLoading}
        className="w-full rounded-md bg-blue-600 px-4 py-2 font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {isLoading ? (
          <span className="flex items-center justify-center gap-2">
            <svg
              className="h-4 w-4 animate-spin"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
            >
              <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
              />
              <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
              />
            </svg>
            Signing in...
          </span>
        ) : (
          'Sign in'
        )}
      </button>

      {/* Switch to register */}
      {onSwitchToRegister && (
        <p className="text-center text-sm text-gray-600 dark:text-gray-400">
          Don&apos;t have an account?{' '}
          <button
            type="button"
            onClick={onSwitchToRegister}
            className="font-medium text-blue-600 hover:text-blue-500 dark:text-blue-400"
          >
            Sign up
          </button>
        </p>
      )}
    </form>
  );
}
