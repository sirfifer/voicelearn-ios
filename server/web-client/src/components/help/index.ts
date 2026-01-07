/**
 * Help system components for the UnaMentis web client.
 *
 * This module provides a comprehensive help system including:
 * - Tooltips for contextual hints
 * - Help icons for inline documentation
 * - Onboarding tour for first-time users
 * - Help modal for full documentation
 * - Keyboard shortcuts reference
 *
 * @module components/help
 *
 * @example
 * ```tsx
 * import {
 *   Tooltip,
 *   HelpIcon,
 *   HelpModal,
 *   KeyboardShortcuts,
 *   OnboardingTour,
 *   useOnboardingTour,
 *   useKeyboardShortcuts,
 * } from '@/components/help';
 *
 * function App() {
 *   const [helpOpen, setHelpOpen] = useState(false);
 *   const [shortcutsOpen, setShortcutsOpen] = useState(false);
 *   const tour = useOnboardingTour();
 *
 *   useKeyboardShortcuts(
 *     () => setShortcutsOpen(true),
 *     () => setHelpOpen(true)
 *   );
 *
 *   return (
 *     <>
 *       <HelpModal
 *         isOpen={helpOpen}
 *         onClose={() => setHelpOpen(false)}
 *         onOpenKeyboardShortcuts={() => setShortcutsOpen(true)}
 *         onStartTour={tour.openTour}
 *       />
 *       <KeyboardShortcuts
 *         isOpen={shortcutsOpen}
 *         onClose={() => setShortcutsOpen(false)}
 *       />
 *       <OnboardingTour
 *         isOpen={tour.isOpen}
 *         onClose={tour.closeTour}
 *         onComplete={tour.completeTour}
 *       />
 *     </>
 *   );
 * }
 * ```
 */

// Tooltip components
export { Tooltip, RichTooltip, TooltipProvider } from './Tooltip';
export type { TooltipProps, RichTooltipProps } from './Tooltip';

// Help icon components
export { HelpIcon, InlineHelpIcon } from './HelpIcon';
export type { HelpIconProps, InlineHelpIconProps } from './HelpIcon';

// Onboarding tour
export { OnboardingTour, useOnboardingTour } from './OnboardingTour';
export type { OnboardingTourProps } from './OnboardingTour';

// Help modal
export { HelpModal } from './HelpModal';
export type { HelpModalProps } from './HelpModal';

// Keyboard shortcuts
export { KeyboardShortcuts, useKeyboardShortcuts } from './KeyboardShortcuts';
export type { KeyboardShortcutsProps } from './KeyboardShortcuts';

// Re-export context help wrappers
export {
  ContextualHelp,
  withContextualHelp,
  FormFieldHelp,
  ButtonHelp,
  PanelHelp,
} from './ContextualHelp';
export type {
  ContextualHelpProps,
  FormFieldHelpProps,
  ButtonHelpProps,
  PanelHelpProps,
} from './ContextualHelp';

// Help button for app header
export { HelpButton } from './HelpButton';
export type { HelpButtonProps } from './HelpButton';
