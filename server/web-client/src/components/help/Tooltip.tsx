'use client';

/**
 * Tooltip component for displaying contextual help and hints.
 *
 * Uses Radix UI Tooltip primitive for accessible tooltip behavior including
 * keyboard support, proper ARIA attributes, and configurable positioning.
 *
 * @module components/help/Tooltip
 *
 * @example
 * ```tsx
 * <Tooltip content="This is a helpful tip">
 *   <button>Hover me</button>
 * </Tooltip>
 * ```
 *
 * @example
 * ```tsx
 * // With rich content
 * <Tooltip
 *   content={<div><strong>Title</strong><p>Description</p></div>}
 *   side="right"
 *   delayDuration={200}
 * >
 *   <InfoIcon />
 * </Tooltip>
 * ```
 */

import * as React from 'react';
import * as TooltipPrimitive from '@radix-ui/react-tooltip';
import { clsx } from 'clsx';

/**
 * Props for the Tooltip component.
 */
export interface TooltipProps {
  /** Content to display in the tooltip */
  content: React.ReactNode;
  /** The element that triggers the tooltip */
  children: React.ReactNode;
  /** Side of the trigger where the tooltip should appear */
  side?: 'top' | 'right' | 'bottom' | 'left';
  /** Alignment of the tooltip relative to the trigger */
  align?: 'start' | 'center' | 'end';
  /** Delay in ms before the tooltip appears */
  delayDuration?: number;
  /** Whether the tooltip should skip the delay when opening */
  skipDelayDuration?: number;
  /** Additional CSS classes for the tooltip content */
  className?: string;
  /** Whether the tooltip is disabled */
  disabled?: boolean;
  /** Accessible label for the tooltip (overrides content for screen readers) */
  ariaLabel?: string;
}

/**
 * Provider component for tooltips. Wrap your app with this to configure global tooltip behavior.
 */
export const TooltipProvider = TooltipPrimitive.Provider;

/**
 * Tooltip component with accessible behavior and customizable appearance.
 *
 * Features:
 * - Keyboard accessible (shows on focus)
 * - Configurable position and alignment
 * - Adjustable show delay
 * - Support for rich content
 * - Proper ARIA attributes for screen readers
 */
export function Tooltip({
  content,
  children,
  side = 'top',
  align = 'center',
  delayDuration = 400,
  skipDelayDuration: _skipDelayDuration = 0,
  className,
  disabled = false,
  ariaLabel,
}: TooltipProps) {
  // Don't render tooltip if disabled or no content
  if (disabled || !content) {
    return <>{children}</>;
  }

  return (
    <TooltipPrimitive.Root delayDuration={delayDuration}>
      <TooltipPrimitive.Trigger asChild>{children}</TooltipPrimitive.Trigger>
      <TooltipPrimitive.Portal>
        <TooltipPrimitive.Content
          side={side}
          align={align}
          sideOffset={4}
          className={clsx(
            // Base styles
            'z-50 overflow-hidden rounded-md px-3 py-1.5 text-sm',
            // Colors
            'bg-gray-900 text-gray-50 dark:bg-gray-50 dark:text-gray-900',
            // Shadow
            'shadow-md',
            // Animation
            'animate-in fade-in-0 zoom-in-95',
            'data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95',
            'data-[side=bottom]:slide-in-from-top-2',
            'data-[side=left]:slide-in-from-right-2',
            'data-[side=right]:slide-in-from-left-2',
            'data-[side=top]:slide-in-from-bottom-2',
            // Custom classes
            className
          )}
          aria-label={ariaLabel}
        >
          {content}
          <TooltipPrimitive.Arrow className="fill-gray-900 dark:fill-gray-50" />
        </TooltipPrimitive.Content>
      </TooltipPrimitive.Portal>
    </TooltipPrimitive.Root>
  );
}

/**
 * Props for the RichTooltip component.
 */
export interface RichTooltipProps extends Omit<TooltipProps, 'content'> {
  /** Title displayed at the top of the tooltip */
  title: string;
  /** Description text */
  description: string;
  /** Optional keyboard shortcut to display */
  shortcut?: string;
  /** Optional list of tips */
  tips?: string[];
}

/**
 * Rich tooltip with structured content including title, description, and optional tips.
 *
 * Use this for help icons and contextual help that requires more than a simple text hint.
 */
export function RichTooltip({
  title,
  description,
  shortcut,
  tips,
  children,
  ...props
}: RichTooltipProps) {
  const content = (
    <div className="max-w-xs space-y-2">
      <div className="flex items-center justify-between gap-4">
        <span className="font-semibold">{title}</span>
        {shortcut && (
          <kbd className="rounded bg-gray-700 px-1.5 py-0.5 text-xs font-mono dark:bg-gray-200">
            {shortcut}
          </kbd>
        )}
      </div>
      <p className="text-gray-300 dark:text-gray-600">{description}</p>
      {tips && tips.length > 0 && (
        <ul className="mt-2 space-y-1 text-xs text-gray-400 dark:text-gray-500">
          {tips.map((tip, index) => (
            <li key={index} className="flex items-start gap-1">
              <span className="text-gray-500 dark:text-gray-400">•</span>
              <span>{tip}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );

  return (
    <Tooltip content={content} ariaLabel={`${title}: ${description}`} {...props}>
      {children}
    </Tooltip>
  );
}

export default Tooltip;
