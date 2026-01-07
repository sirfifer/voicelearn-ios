'use client';

/**
 * HelpIcon component for displaying contextual help throughout the UI.
 *
 * A small "?" icon button that shows help content when hovered or clicked.
 * Designed to be placed next to form fields, buttons, and other UI elements
 * that benefit from contextual help.
 *
 * @module components/help/HelpIcon
 *
 * @example
 * ```tsx
 * // Basic usage with help content key
 * <HelpIcon helpKey="email" />
 *
 * // Custom content
 * <HelpIcon
 *   title="Custom Title"
 *   description="Custom description text"
 * />
 *
 * // Different size and position
 * <HelpIcon helpKey="password" size="lg" side="right" />
 * ```
 */

import * as React from 'react';
import { clsx } from 'clsx';
import { RichTooltip, type TooltipProps } from './Tooltip';
import { getHelpContent, type HelpContent } from '@/lib/help/content';

/**
 * Size variants for the help icon.
 */
type HelpIconSize = 'sm' | 'md' | 'lg';

/**
 * Props for the HelpIcon component.
 */
export interface HelpIconProps {
  /**
   * Key to look up help content from the centralized content file.
   * If provided, title/description/tips are loaded automatically.
   */
  helpKey?: string;
  /** Custom title (overrides helpKey lookup) */
  title?: string;
  /** Custom description (overrides helpKey lookup) */
  description?: string;
  /** Keyboard shortcut to display */
  shortcut?: string;
  /** List of tips to display */
  tips?: string[];
  /** Size of the icon */
  size?: HelpIconSize;
  /** Side where the tooltip appears */
  side?: TooltipProps['side'];
  /** Alignment of the tooltip */
  align?: TooltipProps['align'];
  /** Additional CSS classes */
  className?: string;
  /** Called when the icon is clicked */
  onClick?: (event: React.MouseEvent<HTMLButtonElement>) => void;
  /** Accessible label for screen readers */
  ariaLabel?: string;
}

/**
 * Size class mappings for the icon button.
 */
const sizeClasses: Record<HelpIconSize, string> = {
  sm: 'h-4 w-4 text-xs',
  md: 'h-5 w-5 text-sm',
  lg: 'h-6 w-6 text-base',
};

/**
 * Help icon button that displays contextual help in a tooltip.
 *
 * Features:
 * - Automatic content lookup from centralized help content
 * - Multiple size variants
 * - Configurable tooltip position
 * - Keyboard accessible (focusable, activatable with Enter/Space)
 * - Proper ARIA attributes for screen readers
 */
export function HelpIcon({
  helpKey,
  title,
  description,
  shortcut,
  tips,
  size = 'md',
  side = 'top',
  align = 'center',
  className,
  onClick,
  ariaLabel,
}: HelpIconProps) {
  // Look up content from centralized store if helpKey provided
  const lookedUpContent: HelpContent | undefined = helpKey ? getHelpContent(helpKey) : undefined;

  // Merge looked-up content with explicit props (explicit props take precedence)
  const resolvedTitle = title ?? lookedUpContent?.title ?? 'Help';
  const resolvedDescription =
    description ?? lookedUpContent?.description ?? 'No help available for this item.';
  const resolvedShortcut = shortcut ?? lookedUpContent?.shortcut;
  const resolvedTips = tips ?? lookedUpContent?.tips;

  const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
    // Prevent default behavior to keep tooltip visible after click
    event.preventDefault();
    onClick?.(event);
  };

  const handleKeyDown = (event: React.KeyboardEvent<HTMLButtonElement>) => {
    // Allow Enter and Space to trigger click
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      onClick?.(event as unknown as React.MouseEvent<HTMLButtonElement>);
    }
  };

  return (
    <RichTooltip
      title={resolvedTitle}
      description={resolvedDescription}
      shortcut={resolvedShortcut}
      tips={resolvedTips}
      side={side}
      align={align}
    >
      <button
        type="button"
        onClick={handleClick}
        onKeyDown={handleKeyDown}
        className={clsx(
          // Base styles
          'inline-flex items-center justify-center rounded-full',
          'border border-gray-300 dark:border-gray-600',
          'text-gray-500 dark:text-gray-400',
          // Hover styles
          'hover:border-gray-400 hover:text-gray-700',
          'dark:hover:border-gray-500 dark:hover:text-gray-300',
          // Focus styles
          'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2',
          'dark:focus:ring-offset-gray-900',
          // Transition
          'transition-colors duration-150',
          // Size
          sizeClasses[size],
          // Custom classes
          className
        )}
        aria-label={ariaLabel ?? `Help: ${resolvedTitle}`}
      >
        <span className="font-semibold" aria-hidden="true">
          ?
        </span>
      </button>
    </RichTooltip>
  );
}

/**
 * Props for the InlineHelpIcon component.
 */
export interface InlineHelpIconProps extends HelpIconProps {
  /** Label text to display next to the icon */
  label?: string;
  /** Position of the label relative to the icon */
  labelPosition?: 'before' | 'after';
}

/**
 * Help icon with an optional inline label.
 *
 * Use this when you want to provide both a label and a help icon together,
 * such as next to form field labels.
 *
 * @example
 * ```tsx
 * <InlineHelpIcon
 *   helpKey="email"
 *   label="Email Address"
 *   labelPosition="before"
 * />
 * ```
 */
export function InlineHelpIcon({
  label,
  labelPosition = 'after',
  className,
  ...props
}: InlineHelpIconProps) {
  if (!label) {
    return <HelpIcon {...props} className={className} />;
  }

  return (
    <span
      className={clsx(
        'inline-flex items-center gap-1.5',
        className
      )}
    >
      {labelPosition === 'before' && (
        <span className="text-sm font-medium text-gray-700 dark:text-gray-300">{label}</span>
      )}
      <HelpIcon {...props} size={props.size ?? 'sm'} />
      {labelPosition === 'after' && (
        <span className="text-sm font-medium text-gray-700 dark:text-gray-300">{label}</span>
      )}
    </span>
  );
}

export default HelpIcon;
