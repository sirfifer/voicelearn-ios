'use client';

/**
 * KeyboardShortcuts component for displaying keyboard shortcut reference.
 *
 * A modal dialog showing all available keyboard shortcuts organized by
 * category. Can be opened with Ctrl+/ or from the help menu.
 *
 * @module components/help/KeyboardShortcuts
 *
 * @example
 * ```tsx
 * const [isOpen, setIsOpen] = useState(false);
 *
 * // Open with keyboard shortcut
 * useEffect(() => {
 *   const handler = (e: KeyboardEvent) => {
 *     if (e.ctrlKey && e.key === '/') {
 *       e.preventDefault();
 *       setIsOpen(true);
 *     }
 *   };
 *   window.addEventListener('keydown', handler);
 *   return () => window.removeEventListener('keydown', handler);
 * }, []);
 *
 * <KeyboardShortcuts isOpen={isOpen} onClose={() => setIsOpen(false)} />
 * ```
 */

import * as React from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { clsx } from 'clsx';
import {
  keyboardShortcuts,
  getShortcutsByCategory,
  getShortcutCategories,
  type KeyboardShortcut,
} from '@/lib/help/content';

/**
 * Props for the KeyboardShortcuts component.
 */
export interface KeyboardShortcutsProps {
  /** Whether the modal is open */
  isOpen: boolean;
  /** Called when the modal is closed */
  onClose: () => void;
  /** Custom shortcuts to display (overrides default) */
  shortcuts?: KeyboardShortcut[];
}

/**
 * Category labels for display.
 */
const categoryLabels: Record<KeyboardShortcut['category'], string> = {
  session: 'Session Controls',
  navigation: 'Navigation',
  general: 'General',
};

/**
 * Category icons for display.
 */
function CategoryIcon({ category }: { category: KeyboardShortcut['category'] }) {
  switch (category) {
    case 'session':
      return (
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
            d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"
          />
        </svg>
      );
    case 'navigation':
      return (
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
            d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"
          />
        </svg>
      );
    case 'general':
      return (
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
            d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
          />
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
          />
        </svg>
      );
  }
}

/**
 * Shortcut row component.
 */
function ShortcutRow({ shortcut }: { shortcut: KeyboardShortcut }) {
  // Parse key combination for display
  const keys = shortcut.keys.split(/\s*\+\s*/);

  return (
    <div className="flex items-center justify-between py-2">
      <span className="text-sm text-gray-700 dark:text-gray-300">
        {shortcut.action}
      </span>
      <div className="flex items-center gap-1">
        {keys.map((key, index) => (
          <React.Fragment key={index}>
            {index > 0 && (
              <span className="text-gray-400 dark:text-gray-500 text-xs">+</span>
            )}
            <kbd
              className={clsx(
                'inline-flex items-center justify-center',
                'min-w-[1.5rem] px-1.5 py-0.5',
                'rounded border',
                'bg-gray-100 border-gray-300',
                'dark:bg-gray-700 dark:border-gray-600',
                'text-xs font-mono font-medium',
                'text-gray-700 dark:text-gray-300'
              )}
            >
              {formatKey(key)}
            </kbd>
          </React.Fragment>
        ))}
      </div>
    </div>
  );
}

/**
 * Format key name for display.
 */
function formatKey(key: string): string {
  // Map common key names to symbols/shorter forms
  const keyMap: Record<string, string> = {
    Ctrl: '⌃',
    Control: '⌃',
    Alt: '⌥',
    Option: '⌥',
    Shift: '⇧',
    Cmd: '⌘',
    Command: '⌘',
    Enter: '↵',
    Return: '↵',
    Escape: 'Esc',
    Backspace: '⌫',
    Delete: '⌦',
    ArrowUp: '↑',
    ArrowDown: '↓',
    ArrowLeft: '←',
    ArrowRight: '→',
    Space: '␣',
  };

  return keyMap[key] ?? key;
}

/**
 * Keyboard shortcuts modal.
 *
 * Features:
 * - Organized by category
 * - Clear visual key representations
 * - Keyboard accessible
 * - Escape to close
 */
export function KeyboardShortcuts({
  isOpen,
  onClose,
  shortcuts: _shortcuts = keyboardShortcuts,
}: KeyboardShortcutsProps) {
  const categories = getShortcutCategories();

  return (
    <Dialog.Root open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <Dialog.Portal>
        {/* Overlay */}
        <Dialog.Overlay
          className={clsx(
            'fixed inset-0 z-50 bg-black/50',
            'data-[state=open]:animate-in data-[state=open]:fade-in-0',
            'data-[state=closed]:animate-out data-[state=closed]:fade-out-0'
          )}
        />

        {/* Content */}
        <Dialog.Content
          className={clsx(
            'fixed left-1/2 top-1/2 z-50 -translate-x-1/2 -translate-y-1/2',
            'w-full max-w-lg max-h-[80vh]',
            'rounded-lg bg-white dark:bg-gray-800',
            'shadow-xl',
            'flex flex-col',
            'data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95',
            'data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95',
            'focus:outline-none'
          )}
          aria-describedby="shortcuts-description"
        >
          {/* Header */}
          <div className="flex items-center justify-between border-b border-gray-200 dark:border-gray-700 px-6 py-4">
            <Dialog.Title className="text-xl font-semibold text-gray-900 dark:text-gray-100">
              Keyboard Shortcuts
            </Dialog.Title>
            <Dialog.Close
              className={clsx(
                'rounded-full p-1',
                'text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200',
                'hover:bg-gray-100 dark:hover:bg-gray-700',
                'focus:outline-none focus:ring-2 focus:ring-blue-500',
                'transition-colors'
              )}
              aria-label="Close"
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
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </Dialog.Close>
          </div>

          {/* Hidden description for accessibility */}
          <Dialog.Description id="shortcuts-description" className="sr-only">
            List of keyboard shortcuts for UnaMentis web client, organized by category.
          </Dialog.Description>

          {/* Content */}
          <div className="flex-1 overflow-y-auto px-6 py-4">
            <div className="space-y-6">
              {categories.map((category) => {
                const categoryShortcuts = getShortcutsByCategory(category);
                if (categoryShortcuts.length === 0) return null;

                return (
                  <div key={category}>
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-gray-500 dark:text-gray-400">
                        <CategoryIcon category={category} />
                      </span>
                      <h3 className="font-medium text-gray-900 dark:text-gray-100">
                        {categoryLabels[category]}
                      </h3>
                    </div>
                    <div className="divide-y divide-gray-200 dark:divide-gray-700">
                      {categoryShortcuts.map((shortcut, index) => (
                        <ShortcutRow key={index} shortcut={shortcut} />
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Footer */}
          <div className="border-t border-gray-200 dark:border-gray-700 px-6 py-3">
            <p className="text-center text-xs text-gray-500 dark:text-gray-400">
              Press{' '}
              <kbd className="rounded bg-gray-100 dark:bg-gray-700 px-1 py-0.5 font-mono">
                Ctrl + /
              </kbd>{' '}
              to open this panel anytime
            </p>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

/**
 * Hook to register the global keyboard shortcut handler.
 *
 * @param onOpenShortcuts - Callback when Ctrl+/ is pressed
 * @param onOpenHelp - Callback when Ctrl+? is pressed
 */
export function useKeyboardShortcuts(
  onOpenShortcuts?: () => void,
  onOpenHelp?: () => void
) {
  React.useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      // Ctrl + / to open shortcuts
      if (event.ctrlKey && event.key === '/') {
        event.preventDefault();
        onOpenShortcuts?.();
        return;
      }

      // Ctrl + Shift + / (Ctrl + ?) to open help
      if (event.ctrlKey && event.shiftKey && event.key === '/') {
        event.preventDefault();
        onOpenHelp?.();
        return;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onOpenShortcuts, onOpenHelp]);
}

export default KeyboardShortcuts;
