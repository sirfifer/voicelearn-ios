'use client';

/**
 * ContextualHelp component and HOC for adding help to UI elements.
 *
 * Provides easy-to-use wrappers for adding contextual help to any UI element.
 * Includes pre-built variants for common UI patterns like form fields,
 * buttons, and panels.
 *
 * @module components/help/ContextualHelp
 *
 * @example
 * ```tsx
 * // Basic usage - wrap any element
 * <ContextualHelp helpKey="email">
 *   <input type="email" />
 * </ContextualHelp>
 *
 * // With custom help content
 * <ContextualHelp
 *   title="Custom Title"
 *   description="Custom help text"
 *   showIcon
 * >
 *   <Button>Click me</Button>
 * </ContextualHelp>
 *
 * // Using HOC
 * const HelpfulButton = withContextualHelp(Button, { helpKey: 'startSession' });
 * ```
 */

import * as React from 'react';
import { clsx } from 'clsx';
import { HelpIcon, type HelpIconProps as _HelpIconProps } from './HelpIcon';
import { RichTooltip } from './Tooltip';
import { getHelpContent } from '@/lib/help/content';

/**
 * Props for the ContextualHelp component.
 */
export interface ContextualHelpProps {
  /** The element to provide help for */
  children: React.ReactNode;
  /** Key to look up help content */
  helpKey?: string;
  /** Custom title (overrides helpKey) */
  title?: string;
  /** Custom description (overrides helpKey) */
  description?: string;
  /** Keyboard shortcut to display */
  shortcut?: string;
  /** Tips to display */
  tips?: string[];
  /** Whether to show a help icon alongside the element */
  showIcon?: boolean;
  /** Position of the help icon relative to the element */
  iconPosition?: 'before' | 'after';
  /** Side where the tooltip appears */
  tooltipSide?: 'top' | 'right' | 'bottom' | 'left';
  /** Whether the tooltip wraps the element or just the icon */
  tooltipOnElement?: boolean;
  /** Additional CSS classes for the wrapper */
  className?: string;
}

/**
 * Wrapper component that adds contextual help to any UI element.
 *
 * Can display help via:
 * - A tooltip on hover/focus of the wrapped element
 * - A help icon next to the element
 * - Both
 */
export function ContextualHelp({
  children,
  helpKey,
  title,
  description,
  shortcut,
  tips,
  showIcon = false,
  iconPosition = 'after',
  tooltipSide = 'top',
  tooltipOnElement = true,
  className,
}: ContextualHelpProps) {
  // Look up content from centralized store if helpKey provided
  const lookedUpContent = helpKey ? getHelpContent(helpKey) : undefined;

  // Resolve final values
  const resolvedTitle = title ?? lookedUpContent?.title ?? 'Help';
  const resolvedDescription =
    description ?? lookedUpContent?.description ?? '';
  const resolvedShortcut = shortcut ?? lookedUpContent?.shortcut;
  const resolvedTips = tips ?? lookedUpContent?.tips;

  // If no help content available, just render children
  if (!resolvedTitle && !resolvedDescription) {
    return <>{children}</>;
  }

  // Render the help icon
  const helpIcon = showIcon ? (
    <HelpIcon
      title={resolvedTitle}
      description={resolvedDescription}
      shortcut={resolvedShortcut}
      tips={resolvedTips}
      size="sm"
      side={tooltipSide}
    />
  ) : null;

  // If we want tooltip on the element itself
  if (tooltipOnElement && !showIcon) {
    return (
      <RichTooltip
        title={resolvedTitle}
        description={resolvedDescription}
        shortcut={resolvedShortcut}
        tips={resolvedTips}
        side={tooltipSide}
      >
        {children}
      </RichTooltip>
    );
  }

  // Render with icon
  return (
    <span className={clsx('inline-flex items-center gap-1.5', className)}>
      {iconPosition === 'before' && helpIcon}
      {tooltipOnElement ? (
        <RichTooltip
          title={resolvedTitle}
          description={resolvedDescription}
          shortcut={resolvedShortcut}
          tips={resolvedTips}
          side={tooltipSide}
        >
          {children}
        </RichTooltip>
      ) : (
        children
      )}
      {iconPosition === 'after' && helpIcon}
    </span>
  );
}

/**
 * HOC that adds contextual help to a component.
 *
 * @example
 * ```tsx
 * const HelpfulButton = withContextualHelp(Button, { helpKey: 'startSession' });
 *
 * // Usage
 * <HelpfulButton onClick={handleStart}>Start</HelpfulButton>
 * ```
 */
export function withContextualHelp<P extends object>(
  Component: React.ComponentType<P>,
  helpProps: Omit<ContextualHelpProps, 'children'>
) {
  function WrappedComponent(props: P) {
    return (
      <ContextualHelp {...helpProps}>
        <Component {...props} />
      </ContextualHelp>
    );
  }

  WrappedComponent.displayName = `withContextualHelp(${Component.displayName ?? Component.name ?? 'Component'})`;

  return WrappedComponent;
}

// =============================================================================
// Pre-built Contextual Help Variants
// =============================================================================

/**
 * Props for FormFieldHelp.
 */
export interface FormFieldHelpProps extends Omit<ContextualHelpProps, 'showIcon' | 'iconPosition'> {
  /** Label for the form field */
  label: string;
  /** Whether the field is required */
  required?: boolean;
  /** HTML id for the label's "for" attribute */
  htmlFor?: string;
}

/**
 * Form field label with integrated help icon.
 *
 * @example
 * ```tsx
 * <FormFieldHelp label="Email Address" helpKey="email" htmlFor="email-input">
 *   <input id="email-input" type="email" />
 * </FormFieldHelp>
 * ```
 */
export function FormFieldHelp({
  label,
  required = false,
  htmlFor,
  children,
  ...helpProps
}: FormFieldHelpProps) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center gap-1.5">
        <label
          htmlFor={htmlFor}
          className="text-sm font-medium text-gray-700 dark:text-gray-300"
        >
          {label}
          {required && (
            <span className="text-red-500 ml-0.5" aria-hidden="true">
              *
            </span>
          )}
        </label>
        {(helpProps.helpKey || helpProps.title) && (
          <HelpIcon {...helpProps} size="sm" />
        )}
      </div>
      {children}
    </div>
  );
}

/**
 * Props for ButtonHelp.
 */
export interface ButtonHelpProps extends Omit<ContextualHelpProps, 'tooltipOnElement'> {
  /** Click handler for the button */
  onClick?: () => void;
  /** Whether the button is disabled */
  disabled?: boolean;
  /** Button variant */
  variant?: 'primary' | 'secondary' | 'ghost';
  /** Button size */
  size?: 'sm' | 'md' | 'lg';
}

/**
 * Button with integrated tooltip help.
 *
 * @example
 * ```tsx
 * <ButtonHelp
 *   helpKey="startSession"
 *   onClick={handleStart}
 *   variant="primary"
 * >
 *   Start Session
 * </ButtonHelp>
 * ```
 */
export function ButtonHelp({
  children,
  onClick,
  disabled = false,
  variant = 'primary',
  size = 'md',
  ...helpProps
}: ButtonHelpProps) {
  const variantClasses = {
    primary: 'bg-blue-500 text-white hover:bg-blue-600 disabled:bg-blue-300',
    secondary:
      'border border-gray-300 text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700',
    ghost: 'text-gray-600 hover:bg-gray-100 dark:text-gray-400 dark:hover:bg-gray-800',
  };

  const sizeClasses = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-sm',
    lg: 'px-6 py-3 text-base',
  };

  return (
    <ContextualHelp {...helpProps} tooltipOnElement>
      <button
        type="button"
        onClick={onClick}
        disabled={disabled}
        className={clsx(
          'rounded-md font-medium',
          'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2',
          'transition-colors',
          variantClasses[variant],
          sizeClasses[size]
        )}
      >
        {children}
      </button>
    </ContextualHelp>
  );
}

/**
 * Props for PanelHelp.
 */
export interface PanelHelpProps extends Omit<ContextualHelpProps, 'showIcon'> {
  /** Panel heading */
  heading: string;
}

/**
 * Panel/section with help icon in the header.
 *
 * @example
 * ```tsx
 * <PanelHelp heading="Voice Settings" helpKey="voiceSettings">
 *   <VoiceSettingsForm />
 * </PanelHelp>
 * ```
 */
export function PanelHelp({
  heading,
  children,
  ...helpProps
}: PanelHelpProps) {
  return (
    <div className="rounded-lg border border-gray-200 dark:border-gray-700">
      <div className="flex items-center justify-between border-b border-gray-200 dark:border-gray-700 px-4 py-3">
        <h3 className="font-medium text-gray-900 dark:text-gray-100">
          {heading}
        </h3>
        {(helpProps.helpKey || helpProps.title) && (
          <HelpIcon {...helpProps} size="md" />
        )}
      </div>
      <div className="p-4">{children}</div>
    </div>
  );
}

export default ContextualHelp;
