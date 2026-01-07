/**
 * Help content and utilities for the UnaMentis web client.
 *
 * This module contains all centralized help content including:
 * - Session control help text
 * - Curriculum browser help
 * - Settings page help
 * - Authentication help
 * - Keyboard shortcuts
 * - Onboarding tour steps
 *
 * @module lib/help
 *
 * @example
 * ```tsx
 * import {
 *   getHelpContent,
 *   keyboardShortcuts,
 *   onboardingSteps,
 *   sessionControlsHelp,
 * } from '@/lib/help';
 *
 * // Get help for a specific key
 * const emailHelp = getHelpContent('email');
 * console.log(emailHelp?.title); // "Email Address"
 *
 * // Use pre-defined help content
 * const startHelp = sessionControlsHelp.startSession;
 * ```
 */

// Export all help content and types
export {
  // Types
  type HelpContent,
  type KeyboardShortcut,
  type OnboardingStep,

  // Help content by category
  sessionControlsHelp,
  curriculumHelp,
  settingsHelp,
  authHelp,
  generalHelp,

  // Keyboard shortcuts
  keyboardShortcuts,

  // Onboarding
  onboardingSteps,

  // Help modal sections
  helpModalSections,

  // Utility functions
  getHelpContent,
  getShortcutsByCategory,
  getShortcutCategories,
} from './content';
