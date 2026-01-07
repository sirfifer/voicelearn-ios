'use client';

/**
 * OnboardingTour component for first-time user walkthrough.
 *
 * Provides a step-by-step introduction to the UnaMentis web client,
 * highlighting key features and UI elements. The tour can be triggered
 * automatically for new users or manually from the help menu.
 *
 * @module components/help/OnboardingTour
 *
 * @example
 * ```tsx
 * // Basic usage
 * <OnboardingTour isOpen={isFirstVisit} onClose={() => setIsFirstVisit(false)} />
 *
 * // With completion callback
 * <OnboardingTour
 *   isOpen={showTour}
 *   onClose={() => setShowTour(false)}
 *   onComplete={() => saveUserPreference('tour_completed', true)}
 * />
 * ```
 */

import * as React from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { clsx } from 'clsx';
import { onboardingSteps, type OnboardingStep } from '@/lib/help/content';

/**
 * Props for the OnboardingTour component.
 */
export interface OnboardingTourProps {
  /** Whether the tour is currently open */
  isOpen: boolean;
  /** Called when the tour is closed (via skip, complete, or escape) */
  onClose: () => void;
  /** Called when the tour is completed (all steps viewed) */
  onComplete?: () => void;
  /** Custom steps to use instead of default onboarding steps */
  steps?: OnboardingStep[];
  /** Initial step index to start from */
  initialStep?: number;
}

/**
 * Tour step indicator showing progress through the tour.
 */
function StepIndicator({
  currentStep,
  totalSteps,
}: {
  currentStep: number;
  totalSteps: number;
}) {
  return (
    <div className="flex items-center justify-center gap-1.5" role="group" aria-label="Tour progress">
      {Array.from({ length: totalSteps }, (_, index) => (
        <span
          key={index}
          className={clsx(
            'h-2 w-2 rounded-full transition-colors duration-200',
            index === currentStep
              ? 'bg-blue-500 dark:bg-blue-400'
              : index < currentStep
                ? 'bg-blue-300 dark:bg-blue-600'
                : 'bg-gray-300 dark:bg-gray-600'
          )}
          aria-label={
            index === currentStep
              ? `Step ${index + 1} of ${totalSteps} (current)`
              : `Step ${index + 1} of ${totalSteps}`
          }
          aria-current={index === currentStep ? 'step' : undefined}
        />
      ))}
    </div>
  );
}

/**
 * Onboarding tour dialog with step-by-step guidance.
 *
 * Features:
 * - Modal dialog with accessible focus management
 * - Step progress indicator
 * - Keyboard navigation (arrow keys, escape)
 * - Skip and complete options
 * - Optional element highlighting (for future enhancement)
 */
export function OnboardingTour({
  isOpen,
  onClose,
  onComplete,
  steps = onboardingSteps,
  initialStep = 0,
}: OnboardingTourProps) {
  const [currentStep, setCurrentStep] = React.useState(initialStep);

  // Reset step when tour opens
  React.useEffect(() => {
    if (isOpen) {
      setCurrentStep(initialStep);
    }
  }, [isOpen, initialStep]);

  const step = steps[currentStep];
  const isFirstStep = currentStep === 0;
  const isLastStep = currentStep === steps.length - 1;

  const goToNextStep = () => {
    if (isLastStep) {
      onComplete?.();
      onClose();
    } else {
      setCurrentStep((prev) => prev + 1);
    }
  };

  const goToPreviousStep = () => {
    if (!isFirstStep) {
      setCurrentStep((prev) => prev - 1);
    }
  };

  const handleSkip = () => {
    onClose();
  };

  // Keyboard navigation
  const handleKeyDown = (event: React.KeyboardEvent) => {
    switch (event.key) {
      case 'ArrowRight':
      case 'ArrowDown':
        event.preventDefault();
        goToNextStep();
        break;
      case 'ArrowLeft':
      case 'ArrowUp':
        event.preventDefault();
        goToPreviousStep();
        break;
      case 'Escape':
        event.preventDefault();
        handleSkip();
        break;
    }
  };

  if (!step) {
    return null;
  }

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
            'w-full max-w-md rounded-lg',
            'bg-white dark:bg-gray-800',
            'shadow-xl',
            'p-6',
            'data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95 data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%]',
            'data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%]',
            'focus:outline-none'
          )}
          onKeyDown={handleKeyDown}
          aria-describedby="tour-step-description"
        >
          {/* Header */}
          <Dialog.Title className="text-xl font-semibold text-gray-900 dark:text-gray-100">
            {step.title}
          </Dialog.Title>

          {/* Description */}
          <Dialog.Description
            id="tour-step-description"
            className="mt-3 text-gray-600 dark:text-gray-300"
          >
            {step.description}
          </Dialog.Description>

          {/* Illustration placeholder for steps with target elements */}
          {step.targetSelector && (
            <div className="mt-4 rounded-lg bg-gray-100 dark:bg-gray-700 p-4 text-center text-sm text-gray-500 dark:text-gray-400">
              <span aria-hidden="true">
                Look for the highlighted element on the page
              </span>
            </div>
          )}

          {/* Step indicator */}
          <div className="mt-6">
            <StepIndicator currentStep={currentStep} totalSteps={steps.length} />
          </div>

          {/* Navigation buttons */}
          <div className="mt-6 flex items-center justify-between">
            {/* Skip button */}
            <button
              type="button"
              onClick={handleSkip}
              className={clsx(
                'text-sm text-gray-500 hover:text-gray-700',
                'dark:text-gray-400 dark:hover:text-gray-200',
                'focus:outline-none focus:underline',
                'transition-colors'
              )}
              aria-label="Skip tour"
            >
              Skip tour
            </button>

            {/* Navigation */}
            <div className="flex items-center gap-3">
              {/* Back button */}
              {!isFirstStep && (
                <button
                  type="button"
                  onClick={goToPreviousStep}
                  className={clsx(
                    'rounded-md px-4 py-2 text-sm font-medium',
                    'border border-gray-300 dark:border-gray-600',
                    'text-gray-700 dark:text-gray-300',
                    'hover:bg-gray-100 dark:hover:bg-gray-700',
                    'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2',
                    'dark:focus:ring-offset-gray-800',
                    'transition-colors'
                  )}
                  aria-label="Go to previous step"
                >
                  Back
                </button>
              )}

              {/* Next/Complete button */}
              <button
                type="button"
                onClick={goToNextStep}
                className={clsx(
                  'rounded-md px-4 py-2 text-sm font-medium',
                  'bg-blue-500 text-white',
                  'hover:bg-blue-600',
                  'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2',
                  'dark:focus:ring-offset-gray-800',
                  'transition-colors'
                )}
                aria-label={isLastStep ? 'Complete tour' : 'Go to next step'}
              >
                {isLastStep ? 'Get Started' : 'Next'}
              </button>
            </div>
          </div>

          {/* Keyboard hint */}
          <p className="mt-4 text-center text-xs text-gray-400 dark:text-gray-500">
            Use arrow keys to navigate, Escape to skip
          </p>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

/**
 * Hook to manage onboarding tour state.
 *
 * Checks localStorage to determine if the user has completed the tour,
 * and provides functions to show/hide and mark as complete.
 *
 * @param storageKey - localStorage key for storing completion state
 * @returns Object with tour state and control functions
 */
export function useOnboardingTour(storageKey = 'unamentis_onboarding_complete') {
  const [isOpen, setIsOpen] = React.useState(false);
  const [isFirstVisit, setIsFirstVisit] = React.useState(false);

  // Check if this is a first visit on mount
  React.useEffect(() => {
    if (typeof window !== 'undefined') {
      const completed = localStorage.getItem(storageKey);
      if (!completed) {
        setIsFirstVisit(true);
        setIsOpen(true);
      }
    }
  }, [storageKey]);

  const openTour = () => setIsOpen(true);
  const closeTour = () => setIsOpen(false);

  const completeTour = () => {
    if (typeof window !== 'undefined') {
      localStorage.setItem(storageKey, 'true');
    }
    setIsFirstVisit(false);
    setIsOpen(false);
  };

  const resetTour = () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem(storageKey);
    }
    setIsFirstVisit(true);
  };

  return {
    isOpen,
    isFirstVisit,
    openTour,
    closeTour,
    completeTour,
    resetTour,
  };
}

export default OnboardingTour;
