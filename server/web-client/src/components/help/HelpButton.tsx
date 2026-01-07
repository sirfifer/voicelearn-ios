'use client';

/**
 * HelpButton component for the app header.
 *
 * A dropdown menu button that provides quick access to help resources
 * including the help modal, keyboard shortcuts, and onboarding tour.
 *
 * @module components/help/HelpButton
 *
 * @example
 * ```tsx
 * // In the app header
 * <header>
 *   <nav>...</nav>
 *   <HelpButton />
 * </header>
 * ```
 */

import * as React from 'react';
import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import { clsx } from 'clsx';
import { HelpModal } from './HelpModal';
import { KeyboardShortcuts, useKeyboardShortcuts } from './KeyboardShortcuts';
import { OnboardingTour, useOnboardingTour } from './OnboardingTour';

/**
 * Props for the HelpButton component.
 */
export interface HelpButtonProps {
  /** Additional CSS classes */
  className?: string;
}

/**
 * Help button with dropdown menu for accessing help resources.
 *
 * Features:
 * - Opens help modal
 * - Opens keyboard shortcuts
 * - Starts onboarding tour
 * - Integrates with global keyboard shortcuts (Ctrl+?, Ctrl+/)
 */
export function HelpButton({ className }: HelpButtonProps) {
  const [helpOpen, setHelpOpen] = React.useState(false);
  const [shortcutsOpen, setShortcutsOpen] = React.useState(false);
  const tour = useOnboardingTour();

  // Register global keyboard shortcuts
  useKeyboardShortcuts(
    () => setShortcutsOpen(true),
    () => setHelpOpen(true)
  );

  return (
    <>
      <DropdownMenu.Root>
        <DropdownMenu.Trigger asChild>
          <button
            type="button"
            className={clsx(
              'inline-flex items-center justify-center',
              'rounded-full p-2',
              'text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200',
              'hover:bg-gray-100 dark:hover:bg-gray-700',
              'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2',
              'dark:focus:ring-offset-gray-900',
              'transition-colors',
              className
            )}
            aria-label="Help menu"
            data-tour="help-button"
          >
            <svg
              className="h-5 w-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </button>
        </DropdownMenu.Trigger>

        <DropdownMenu.Portal>
          <DropdownMenu.Content
            className={clsx(
              'min-w-[180px] rounded-md p-1',
              'bg-white dark:bg-gray-800',
              'border border-gray-200 dark:border-gray-700',
              'shadow-lg',
              'z-50',
              'animate-in fade-in-0 zoom-in-95',
              'data-[side=bottom]:slide-in-from-top-2',
              'data-[side=top]:slide-in-from-bottom-2'
            )}
            sideOffset={5}
            align="end"
          >
            {/* Help Documentation */}
            <DropdownMenu.Item
              className={clsx(
                'flex items-center gap-3 px-3 py-2 rounded-sm cursor-pointer',
                'text-sm text-gray-700 dark:text-gray-300',
                'hover:bg-gray-100 dark:hover:bg-gray-700',
                'focus:outline-none focus:bg-gray-100 dark:focus:bg-gray-700'
              )}
              onSelect={() => setHelpOpen(true)}
            >
              <svg
                className="h-4 w-4 text-gray-500 dark:text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                />
              </svg>
              <span className="flex-1">Help & Docs</span>
              <kbd className="text-xs text-gray-400 font-mono">⌃?</kbd>
            </DropdownMenu.Item>

            {/* Keyboard Shortcuts */}
            <DropdownMenu.Item
              className={clsx(
                'flex items-center gap-3 px-3 py-2 rounded-sm cursor-pointer',
                'text-sm text-gray-700 dark:text-gray-300',
                'hover:bg-gray-100 dark:hover:bg-gray-700',
                'focus:outline-none focus:bg-gray-100 dark:focus:bg-gray-700'
              )}
              onSelect={() => setShortcutsOpen(true)}
            >
              <svg
                className="h-4 w-4 text-gray-500 dark:text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"
                />
              </svg>
              <span className="flex-1">Keyboard Shortcuts</span>
              <kbd className="text-xs text-gray-400 font-mono">⌃/</kbd>
            </DropdownMenu.Item>

            <DropdownMenu.Separator className="my-1 h-px bg-gray-200 dark:bg-gray-700" />

            {/* Take the Tour */}
            <DropdownMenu.Item
              className={clsx(
                'flex items-center gap-3 px-3 py-2 rounded-sm cursor-pointer',
                'text-sm text-gray-700 dark:text-gray-300',
                'hover:bg-gray-100 dark:hover:bg-gray-700',
                'focus:outline-none focus:bg-gray-100 dark:focus:bg-gray-700'
              )}
              onSelect={() => tour.openTour()}
            >
              <svg
                className="h-4 w-4 text-gray-500 dark:text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <span className="flex-1">Take the Tour</span>
            </DropdownMenu.Item>

            {/* What's New */}
            <DropdownMenu.Item
              className={clsx(
                'flex items-center gap-3 px-3 py-2 rounded-sm cursor-pointer',
                'text-sm text-gray-700 dark:text-gray-300',
                'hover:bg-gray-100 dark:hover:bg-gray-700',
                'focus:outline-none focus:bg-gray-100 dark:focus:bg-gray-700'
              )}
              disabled
            >
              <svg
                className="h-4 w-4 text-gray-500 dark:text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                />
              </svg>
              <span className="flex-1 opacity-50">What&apos;s New</span>
              <span className="text-xs text-gray-400">Coming soon</span>
            </DropdownMenu.Item>
          </DropdownMenu.Content>
        </DropdownMenu.Portal>
      </DropdownMenu.Root>

      {/* Help Modal */}
      <HelpModal
        isOpen={helpOpen}
        onClose={() => setHelpOpen(false)}
        onOpenKeyboardShortcuts={() => {
          setHelpOpen(false);
          setShortcutsOpen(true);
        }}
        onStartTour={() => {
          setHelpOpen(false);
          tour.openTour();
        }}
      />

      {/* Keyboard Shortcuts Modal */}
      <KeyboardShortcuts
        isOpen={shortcutsOpen}
        onClose={() => setShortcutsOpen(false)}
      />

      {/* Onboarding Tour */}
      <OnboardingTour
        isOpen={tour.isOpen}
        onClose={tour.closeTour}
        onComplete={tour.completeTour}
      />
    </>
  );
}

export default HelpButton;
