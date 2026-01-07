'use client';

/**
 * HelpModal component for displaying comprehensive help documentation.
 *
 * A modal dialog that provides access to all help content, organized by
 * sections. Includes search functionality, section navigation, and links
 * to keyboard shortcuts and the onboarding tour.
 *
 * @module components/help/HelpModal
 *
 * @example
 * ```tsx
 * const [isOpen, setIsOpen] = useState(false);
 *
 * <button onClick={() => setIsOpen(true)}>Help</button>
 * <HelpModal isOpen={isOpen} onClose={() => setIsOpen(false)} />
 * ```
 */

import * as React from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import * as Tabs from '@radix-ui/react-tabs';
import { clsx } from 'clsx';
import {
  helpModalSections,
  generalHelp,
  type HelpContent,
} from '@/lib/help/content';

/**
 * Props for the HelpModal component.
 */
export interface HelpModalProps {
  /** Whether the modal is open */
  isOpen: boolean;
  /** Called when the modal is closed */
  onClose: () => void;
  /** Callback to open keyboard shortcuts view */
  onOpenKeyboardShortcuts?: () => void;
  /** Callback to start the onboarding tour */
  onStartTour?: () => void;
  /** Initial section to display */
  initialSection?: string;
}

/**
 * Renders a single help topic card.
 */
function HelpTopicCard({ topic }: { topic: HelpContent }) {
  return (
    <div className="rounded-lg border border-gray-200 dark:border-gray-700 p-4">
      <h4 className="font-medium text-gray-900 dark:text-gray-100">
        {topic.title}
        {topic.shortcut && (
          <kbd className="ml-2 rounded bg-gray-100 dark:bg-gray-700 px-1.5 py-0.5 text-xs font-mono text-gray-600 dark:text-gray-400">
            {topic.shortcut}
          </kbd>
        )}
      </h4>
      <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">
        {topic.description}
      </p>
      {topic.tips && topic.tips.length > 0 && (
        <ul className="mt-3 space-y-1 text-sm text-gray-500 dark:text-gray-500">
          {topic.tips.map((tip, index) => (
            <li key={index} className="flex items-start gap-2">
              <span className="text-blue-500" aria-hidden="true">
                •
              </span>
              <span>{tip}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/**
 * Section content with list of help topics.
 */
function SectionContent({
  topics,
}: {
  topics: HelpContent[];
}) {
  return (
    <div className="space-y-4">
      {topics.map((topic, index) => (
        <HelpTopicCard key={index} topic={topic} />
      ))}
    </div>
  );
}

/**
 * Search results display.
 */
function SearchResults({
  query,
  results,
}: {
  query: string;
  results: HelpContent[];
}) {
  if (results.length === 0) {
    return (
      <div className="py-8 text-center text-gray-500 dark:text-gray-400">
        <p>No results found for &quot;{query}&quot;</p>
        <p className="mt-2 text-sm">Try a different search term</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <p className="text-sm text-gray-500 dark:text-gray-400">
        {results.length} result{results.length !== 1 ? 's' : ''} for &quot;{query}&quot;
      </p>
      {results.map((topic, index) => (
        <HelpTopicCard key={index} topic={topic} />
      ))}
    </div>
  );
}

/**
 * Full help documentation modal.
 *
 * Features:
 * - Tabbed section navigation
 * - Search functionality
 * - Quick links to keyboard shortcuts and tour
 * - Keyboard accessible
 * - Scrollable content area
 */
export function HelpModal({
  isOpen,
  onClose,
  onOpenKeyboardShortcuts,
  onStartTour,
  initialSection = 'getting-started',
}: HelpModalProps) {
  const [searchQuery, setSearchQuery] = React.useState('');
  const [searchResults, setSearchResults] = React.useState<HelpContent[]>([]);
  const [activeTab, setActiveTab] = React.useState(initialSection);
  const searchInputRef = React.useRef<HTMLInputElement>(null);

  // Reset state when modal opens
  React.useEffect(() => {
    if (isOpen) {
      setSearchQuery('');
      setSearchResults([]);
      setActiveTab(initialSection);
    }
  }, [isOpen, initialSection]);

  // Focus search input when modal opens
  React.useEffect(() => {
    if (isOpen && searchInputRef.current) {
      // Small delay to ensure modal is rendered
      const timer = setTimeout(() => {
        searchInputRef.current?.focus();
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [isOpen]);

  // Collect all searchable content
  const allTopics = React.useMemo(() => {
    const topics: HelpContent[] = [];
    helpModalSections.forEach((section) => {
      topics.push(...section.content);
    });
    Object.values(generalHelp).forEach((topic) => {
      if (!topics.some((t) => t.title === topic.title)) {
        topics.push(topic);
      }
    });
    return topics;
  }, []);

  // Search handler
  const handleSearch = (query: string) => {
    setSearchQuery(query);

    if (!query.trim()) {
      setSearchResults([]);
      return;
    }

    const lowerQuery = query.toLowerCase();
    const results = allTopics.filter(
      (topic) =>
        topic.title.toLowerCase().includes(lowerQuery) ||
        topic.description.toLowerCase().includes(lowerQuery) ||
        topic.tips?.some((tip) => tip.toLowerCase().includes(lowerQuery))
    );
    setSearchResults(results);
  };

  // Keyboard shortcut handler
  const handleKeyDown = (event: React.KeyboardEvent) => {
    // Ctrl/Cmd + K to focus search
    if ((event.ctrlKey || event.metaKey) && event.key === 'k') {
      event.preventDefault();
      searchInputRef.current?.focus();
    }
  };

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
            'w-full max-w-2xl max-h-[85vh]',
            'rounded-lg bg-white dark:bg-gray-800',
            'shadow-xl',
            'flex flex-col',
            'data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95',
            'data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95',
            'focus:outline-none'
          )}
          onKeyDown={handleKeyDown}
          aria-describedby="help-modal-description"
        >
          {/* Header */}
          <div className="flex items-center justify-between border-b border-gray-200 dark:border-gray-700 px-6 py-4">
            <Dialog.Title className="text-xl font-semibold text-gray-900 dark:text-gray-100">
              Help & Documentation
            </Dialog.Title>
            <Dialog.Close
              className={clsx(
                'rounded-full p-1',
                'text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200',
                'hover:bg-gray-100 dark:hover:bg-gray-700',
                'focus:outline-none focus:ring-2 focus:ring-blue-500',
                'transition-colors'
              )}
              aria-label="Close help"
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
          <Dialog.Description id="help-modal-description" className="sr-only">
            Help documentation for UnaMentis web client. Use the search box or tabs to find help topics.
          </Dialog.Description>

          {/* Search bar */}
          <div className="border-b border-gray-200 dark:border-gray-700 px-6 py-3">
            <div className="relative">
              <svg
                className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                />
              </svg>
              <input
                ref={searchInputRef}
                type="search"
                placeholder="Search help topics..."
                value={searchQuery}
                onChange={(e) => handleSearch(e.target.value)}
                className={clsx(
                  'w-full rounded-md pl-10 pr-4 py-2',
                  'border border-gray-300 dark:border-gray-600',
                  'bg-white dark:bg-gray-700',
                  'text-gray-900 dark:text-gray-100',
                  'placeholder:text-gray-400 dark:placeholder:text-gray-500',
                  'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500'
                )}
                aria-label="Search help topics"
              />
              <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400">
                Ctrl+K
              </span>
            </div>
          </div>

          {/* Quick actions */}
          <div className="flex gap-4 border-b border-gray-200 dark:border-gray-700 px-6 py-3">
            {onOpenKeyboardShortcuts && (
              <button
                type="button"
                onClick={() => {
                  onClose();
                  onOpenKeyboardShortcuts();
                }}
                className={clsx(
                  'flex items-center gap-2 text-sm',
                  'text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300',
                  'focus:outline-none focus:underline'
                )}
              >
                <svg
                  className="h-4 w-4"
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
                Keyboard Shortcuts
              </button>
            )}
            {onStartTour && (
              <button
                type="button"
                onClick={() => {
                  onClose();
                  onStartTour();
                }}
                className={clsx(
                  'flex items-center gap-2 text-sm',
                  'text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300',
                  'focus:outline-none focus:underline'
                )}
              >
                <svg
                  className="h-4 w-4"
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
                Take the Tour
              </button>
            )}
          </div>

          {/* Content area */}
          <div className="flex-1 overflow-hidden">
            {searchQuery ? (
              /* Search results */
              <div className="h-full overflow-y-auto px-6 py-4">
                <SearchResults query={searchQuery} results={searchResults} />
              </div>
            ) : (
              /* Tabbed sections */
              <Tabs.Root
                value={activeTab}
                onValueChange={setActiveTab}
                className="flex h-full"
              >
                {/* Tab list (sidebar) */}
                <Tabs.List
                  className="w-48 flex-shrink-0 border-r border-gray-200 dark:border-gray-700 py-4"
                  aria-label="Help sections"
                >
                  {helpModalSections.map((section) => (
                    <Tabs.Trigger
                      key={section.id}
                      value={section.id}
                      className={clsx(
                        'w-full px-6 py-2 text-left text-sm',
                        'transition-colors',
                        'focus:outline-none focus:bg-gray-100 dark:focus:bg-gray-700',
                        'data-[state=active]:bg-blue-50 data-[state=active]:text-blue-700',
                        'data-[state=active]:dark:bg-blue-900/20 data-[state=active]:dark:text-blue-400',
                        'data-[state=inactive]:text-gray-600 data-[state=inactive]:hover:bg-gray-50',
                        'data-[state=inactive]:dark:text-gray-400 data-[state=inactive]:dark:hover:bg-gray-700/50'
                      )}
                    >
                      {section.title}
                    </Tabs.Trigger>
                  ))}
                </Tabs.List>

                {/* Tab content */}
                {helpModalSections.map((section) => (
                  <Tabs.Content
                    key={section.id}
                    value={section.id}
                    className="flex-1 overflow-y-auto px-6 py-4"
                  >
                    <SectionContent topics={section.content} />
                  </Tabs.Content>
                ))}
              </Tabs.Root>
            )}
          </div>

          {/* Footer */}
          <div className="border-t border-gray-200 dark:border-gray-700 px-6 py-3">
            <p className="text-center text-xs text-gray-500 dark:text-gray-400">
              Press <kbd className="rounded bg-gray-100 dark:bg-gray-700 px-1 py-0.5 font-mono">Ctrl + ?</kbd> to open help anytime
            </p>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

export default HelpModal;
