/**
 * Centralized help content for the UnaMentis web client.
 *
 * This file contains all help text, tooltips, and onboarding content
 * used throughout the application. Centralizing this content makes it
 * easier to maintain, update, and localize.
 *
 * @module lib/help/content
 */

/**
 * Help content for a single topic.
 */
export interface HelpContent {
  /** Short title for the help topic */
  title: string;
  /** Detailed description or explanation */
  description: string;
  /** Optional keyboard shortcut associated with this action */
  shortcut?: string;
  /** Optional tips for using this feature */
  tips?: string[];
}

/**
 * Keyboard shortcut definition.
 */
export interface KeyboardShortcut {
  /** Keys to press (e.g., "Ctrl + S") */
  keys: string;
  /** Description of what the shortcut does */
  action: string;
  /** Category for grouping shortcuts */
  category: 'session' | 'navigation' | 'general';
}

/**
 * Onboarding step for the tour.
 */
export interface OnboardingStep {
  /** Unique identifier for the step */
  id: string;
  /** Title shown in the tour modal */
  title: string;
  /** Description of the feature being introduced */
  description: string;
  /** CSS selector for the element to highlight (optional) */
  targetSelector?: string;
  /** Position of the tooltip relative to the target */
  position?: 'top' | 'bottom' | 'left' | 'right';
}

// =============================================================================
// Session Controls Help Content
// =============================================================================

export const sessionControlsHelp: Record<string, HelpContent> = {
  startSession: {
    title: 'Start Session',
    description:
      'Begin a new voice learning session. Make sure your microphone is connected and you have selected a curriculum topic.',
    shortcut: 'Space',
    tips: [
      'Grant microphone permissions when prompted',
      'Use headphones for the best experience',
      'Speak naturally, the AI will adapt to your pace',
    ],
  },
  pauseSession: {
    title: 'Pause Session',
    description:
      'Temporarily pause the session. The AI will stop listening and responding until you resume. Your progress is saved automatically.',
    shortcut: 'Space',
    tips: [
      'Use pause when you need a break',
      'The timer stops while paused',
      'You can resume at any time',
    ],
  },
  resumeSession: {
    title: 'Resume Session',
    description: 'Continue the paused session from where you left off.',
    shortcut: 'Space',
  },
  endSession: {
    title: 'End Session',
    description:
      'Finish the current session and save your progress. You will see a summary of what you learned.',
    shortcut: 'Escape',
    tips: [
      'Your conversation history is saved',
      'You can review past sessions in History',
      'Progress toward learning goals is tracked',
    ],
  },
  muteAudio: {
    title: 'Mute Audio',
    description: "Silence the AI's voice output. The AI will continue listening to you.",
    shortcut: 'M',
  },
  unmuteAudio: {
    title: 'Unmute Audio',
    description: "Restore the AI's voice output.",
    shortcut: 'M',
  },
  muteMicrophone: {
    title: 'Mute Microphone',
    description:
      'Stop sending your voice to the AI. Use this when you need to speak to someone else or take a private moment.',
    shortcut: 'Shift + M',
    tips: ["The AI won't hear you while muted", 'A visual indicator shows when you are muted'],
  },
  unmuteMicrophone: {
    title: 'Unmute Microphone',
    description: 'Resume sending your voice to the AI.',
    shortcut: 'Shift + M',
  },
};

// =============================================================================
// Curriculum Browser Help Content
// =============================================================================

export const curriculumHelp: Record<string, HelpContent> = {
  browse: {
    title: 'Browse Curricula',
    description:
      'Explore available learning topics organized by subject and difficulty. Each curriculum contains structured lessons designed for voice-based learning.',
    tips: [
      'Use filters to narrow down subjects',
      'Check the estimated time for each topic',
      'Prerequisites are listed for advanced topics',
    ],
  },
  selectTopic: {
    title: 'Select Topic',
    description:
      'Choose a specific topic to study in your next session. The AI will guide you through the material at your pace.',
    tips: [
      'Start with fundamentals if new to a subject',
      'You can switch topics mid-session if needed',
      'Recent topics appear in your history',
    ],
  },
  curriculumCard: {
    title: 'Curriculum Card',
    description:
      'Shows key information about a curriculum including subject, difficulty level, estimated duration, and a brief description.',
  },
  difficulty: {
    title: 'Difficulty Level',
    description:
      'Curricula are rated from beginner to advanced. Choose a level that matches your current knowledge.',
  },
  prerequisites: {
    title: 'Prerequisites',
    description:
      'Some advanced topics require understanding of foundational concepts. Review prerequisites before starting.',
  },
};

// =============================================================================
// Settings Page Help Content
// =============================================================================

export const settingsHelp: Record<string, HelpContent> = {
  voiceSettings: {
    title: 'Voice Settings',
    description: "Configure the AI's voice, speed, and language preferences.",
    tips: [
      'Try different voices to find one you like',
      'Adjust speed if the AI speaks too fast or slow',
      'Language settings affect both input and output',
    ],
  },
  audioInput: {
    title: 'Audio Input',
    description: 'Select which microphone to use and adjust input sensitivity.',
    tips: [
      'Test your microphone before starting a session',
      'Use a headset for clearer audio in noisy environments',
      'Adjust sensitivity if the AI has trouble hearing you',
    ],
  },
  audioOutput: {
    title: 'Audio Output',
    description: "Select which speakers or headphones to use for the AI's voice.",
    tips: [
      'Use headphones to prevent echo',
      'Adjust volume to a comfortable level',
      'Test output before starting a session',
    ],
  },
  sessionPreferences: {
    title: 'Session Preferences',
    description: 'Customize how sessions work, including auto-pause behavior and notification preferences.',
  },
  displaySettings: {
    title: 'Display Settings',
    description:
      'Configure visual preferences including theme, font size, and layout options.',
    tips: [
      'Dark mode reduces eye strain in low light',
      'Larger fonts improve readability',
      'Choose split-pane or full-screen transcript view',
    ],
  },
  notifications: {
    title: 'Notifications',
    description:
      'Control when and how you receive notifications about sessions, progress, and updates.',
  },
  privacy: {
    title: 'Privacy Settings',
    description:
      'Manage your data, conversation history, and privacy preferences.',
    tips: [
      'Conversation data is encrypted at rest',
      'You can delete your history at any time',
      'Voice recordings are not stored by default',
    ],
  },
  providerSettings: {
    title: 'Voice Provider',
    description:
      'Advanced settings for voice processing providers. Most users can leave these at defaults.',
    tips: [
      'OpenAI Realtime provides the lowest latency',
      'Fallback providers activate automatically if needed',
      'Cost tracking shows usage by provider',
    ],
  },
};

// =============================================================================
// Authentication Help Content
// =============================================================================

export const authHelp: Record<string, HelpContent> = {
  email: {
    title: 'Email Address',
    description: 'Enter the email address associated with your account. This is used for login and password recovery.',
    tips: ['Use an email you check regularly', 'You can change your email in settings after registration'],
  },
  password: {
    title: 'Password',
    description:
      'Your password must be at least 8 characters and include a mix of letters, numbers, and symbols.',
    tips: [
      'Use a unique password for this account',
      'Consider using a password manager',
      'Never share your password with others',
    ],
  },
  confirmPassword: {
    title: 'Confirm Password',
    description: 'Re-enter your password to ensure it was typed correctly.',
  },
  rememberMe: {
    title: 'Remember Me',
    description:
      'Keep you signed in on this device. Uncheck this on shared or public computers.',
    tips: ['Your session will expire after 30 days of inactivity', 'You can sign out manually at any time'],
  },
  forgotPassword: {
    title: 'Forgot Password',
    description:
      'Reset your password via email. A link will be sent to your registered email address.',
    tips: ['Check your spam folder if you do not see the email', 'Links expire after 1 hour'],
  },
  termsOfService: {
    title: 'Terms of Service',
    description: 'By creating an account, you agree to our terms of service and privacy policy.',
  },
};

// =============================================================================
// Keyboard Shortcuts
// =============================================================================

export const keyboardShortcuts: KeyboardShortcut[] = [
  // Session shortcuts
  { keys: 'Space', action: 'Start/Pause/Resume session', category: 'session' },
  { keys: 'Escape', action: 'End session', category: 'session' },
  { keys: 'M', action: 'Toggle audio mute', category: 'session' },
  { keys: 'Shift + M', action: 'Toggle microphone mute', category: 'session' },
  { keys: 'Ctrl + R', action: 'Repeat last AI response', category: 'session' },

  // Navigation shortcuts
  { keys: 'Ctrl + 1', action: 'Go to Session tab', category: 'navigation' },
  { keys: 'Ctrl + 2', action: 'Go to Curriculum tab', category: 'navigation' },
  { keys: 'Ctrl + 3', action: 'Go to History tab', category: 'navigation' },
  { keys: 'Ctrl + 4', action: 'Go to Settings tab', category: 'navigation' },
  { keys: 'Ctrl + /', action: 'Open keyboard shortcuts', category: 'navigation' },

  // General shortcuts
  { keys: 'Ctrl + ?', action: 'Open help', category: 'general' },
  { keys: 'Ctrl + K', action: 'Open command palette', category: 'general' },
  { keys: 'Ctrl + Shift + T', action: 'Toggle theme (dark/light)', category: 'general' },
];

// =============================================================================
// Onboarding Tour Steps
// =============================================================================

export const onboardingSteps: OnboardingStep[] = [
  {
    id: 'welcome',
    title: 'Welcome to UnaMentis',
    description:
      'UnaMentis is your personal AI learning assistant for voice-based learning. Let us show you around.',
  },
  {
    id: 'curriculum',
    title: 'Choose What to Learn',
    description:
      'Browse our curriculum library to find topics that interest you. Each curriculum is designed for voice-based learning.',
    targetSelector: '[data-tour="curriculum-browser"]',
    position: 'bottom',
  },
  {
    id: 'session-controls',
    title: 'Start a Session',
    description:
      'Once you have selected a topic, click the Start button or press Space to begin a voice learning session.',
    targetSelector: '[data-tour="session-controls"]',
    position: 'top',
  },
  {
    id: 'transcript',
    title: 'View Your Conversation',
    description:
      'The transcript panel shows your conversation in real-time. You can scroll back to review what was discussed.',
    targetSelector: '[data-tour="transcript-panel"]',
    position: 'left',
  },
  {
    id: 'visual-panel',
    title: 'Visual Learning',
    description:
      'When relevant, the AI will display formulas, diagrams, maps, and other visuals to enhance your learning.',
    targetSelector: '[data-tour="visual-panel"]',
    position: 'left',
  },
  {
    id: 'settings',
    title: 'Customize Your Experience',
    description:
      'Visit Settings to adjust voice, display, and session preferences to match your learning style.',
    targetSelector: '[data-tour="settings"]',
    position: 'bottom',
  },
  {
    id: 'help',
    title: 'Get Help Anytime',
    description:
      'Click the help button in the header or press Ctrl + ? to access help, keyboard shortcuts, and this tour.',
    targetSelector: '[data-tour="help-button"]',
    position: 'bottom',
  },
  {
    id: 'complete',
    title: 'You are Ready!',
    description:
      'That is the basics! Start a session whenever you are ready. The AI will guide you through the material.',
  },
];

// =============================================================================
// General Help Content
// =============================================================================

export const generalHelp: Record<string, HelpContent> = {
  voiceLearning: {
    title: 'Voice-Based Learning',
    description:
      'UnaMentis uses voice as the primary interface for learning. Speak naturally to ask questions, request explanations, or discuss concepts with the AI.',
    tips: [
      'Speak clearly and at a natural pace',
      'You can interrupt the AI to ask questions',
      'Request examples or analogies for difficult concepts',
    ],
  },
  visualAssets: {
    title: 'Visual Assets',
    description:
      'The AI can display various visual aids including mathematical formulas, diagrams, maps, charts, and images to support your learning.',
    tips: [
      'Ask the AI to show a diagram or formula',
      'Visuals appear in the right panel on desktop',
      'Tap on visuals to enlarge them on mobile',
    ],
  },
  sessionDuration: {
    title: 'Session Duration',
    description:
      'Sessions are designed for extended learning periods of 60-90 minutes. You can pause or end at any time, and your progress is saved automatically.',
  },
  progressTracking: {
    title: 'Progress Tracking',
    description:
      'Your learning progress is tracked across sessions. Review your history to see completed topics, time spent, and concepts mastered.',
  },
  latency: {
    title: 'Response Latency',
    description:
      'UnaMentis is optimized for natural conversation with less than 500ms response latency. If you experience delays, check your internet connection.',
  },
  accessibility: {
    title: 'Accessibility',
    description:
      'UnaMentis supports keyboard navigation, screen readers, and high contrast modes. Visit Settings to configure accessibility options.',
    tips: [
      'All interactive elements are keyboard accessible',
      'ARIA labels are provided for screen readers',
      'Transcript can be navigated with arrow keys',
    ],
  },
  onboarding: {
    title: 'Welcome to UnaMentis',
    description:
      'This app lets you learn through voice conversations with the AI. Get started by selecting a curriculum, configuring your audio settings, and starting a session.',
    tips: [
      'Go to Settings to configure your audio devices',
      'Import or browse available curricula',
      'Start a lesson or free conversation',
    ],
  },
};

// =============================================================================
// Session View Help (matches iOS HelpContent.Session)
// =============================================================================

export const sessionViewHelp: Record<string, HelpContent> = {
  overview: {
    title: 'Session Overview',
    description: 'This is your voice conversation interface. Speak naturally and the AI will respond.',
  },
  statusIndicator: {
    title: 'Status Indicator',
    description: 'The status indicator shows the current state of your conversation.',
    tips: [
      'Gray (Idle): Ready to start',
      'Green (Listening): Hearing your voice',
      'Orange (Thinking): Processing your request',
      'Blue (Speaking): AI is responding',
      'Yellow (Interrupted): You interrupted the AI',
    ],
  },
  progressBar: {
    title: 'Progress Bar',
    description: 'Shows your progress through the current lesson. Each segment represents a topic or concept being covered.',
  },
  vuMeter: {
    title: 'Audio Level Meter',
    description: 'The audio level meter shows voice activity.',
    tips: [
      'Blue: AI is speaking',
      'Green: Your voice is detected',
      'Higher levels indicate louder audio',
    ],
  },
  interrupt: {
    title: 'Interruption',
    description: 'You can interrupt the AI at any time by simply speaking. The AI will pause and listen to your question or comment.',
  },
  pauseResume: {
    title: 'Pause/Resume',
    description: 'Pause to take a break without ending the session. Resume to continue where you left off.',
  },
  latencyMetric: {
    title: 'Response Latency',
    description: 'Response latency shows how quickly the system responds. Lower is better. Target: under 500ms.',
  },
  costMetric: {
    title: 'Session Cost',
    description: 'Estimated cost for this session based on API usage. On-device and self-hosted options are free.',
  },
};

// =============================================================================
// History View Help (matches iOS HelpContent.History)
// =============================================================================

export const historyHelp: Record<string, HelpContent> = {
  overview: {
    title: 'Session History',
    description: 'Review your past learning sessions. Each entry shows duration, turn count, and cost.',
  },
  turns: {
    title: 'Conversation Turns',
    description: 'A "turn" is one exchange: you speak, then the AI responds. More turns indicate a longer, more interactive conversation.',
  },
  avgLatency: {
    title: 'Average Latency',
    description: 'Average response time for this session. Lower latency means faster, more natural conversations.',
  },
  totalCost: {
    title: 'Total Cost',
    description: 'Total API costs for this session. Includes speech recognition, language model, and text-to-speech fees.',
  },
  export: {
    title: 'Export History',
    description: 'Export your session history as JSON for backup or analysis.',
  },
};

// =============================================================================
// Analytics Help (matches iOS HelpContent.Analytics)
// =============================================================================

export const analyticsHelp: Record<string, HelpContent> = {
  overview: {
    title: 'Analytics Overview',
    description: 'Track your learning progress and system performance metrics. Use this data to optimize your experience.',
  },
  sttLatency: {
    title: 'STT Latency',
    description: 'Speech-to-Text latency measures how long it takes to convert your speech to text. Target: under 150ms.',
  },
  llmTTFT: {
    title: 'LLM Time-To-First-Token',
    description: 'Measures how quickly the language model starts generating a response. Target: under 200ms.',
  },
  ttsTTFB: {
    title: 'TTS Time-To-First-Byte',
    description: 'Measures how quickly text-to-speech audio starts playing. Target: under 100ms.',
  },
  e2eLatency: {
    title: 'End-to-End Latency',
    description: 'Total time from when you stop speaking to when you hear a response. Target: under 500ms (median), under 1000ms (P99).',
  },
  medianVsP99: {
    title: 'Median vs P99',
    description: 'Median: The typical (50th percentile) response time. P99: The worst-case (99th percentile) response time. 99% of responses are faster than this.',
  },
  costPerHour: {
    title: 'Cost Per Hour',
    description: 'Estimated hourly cost based on your usage patterns. Use on-device or self-hosted providers to reduce costs.',
  },
  interruptions: {
    title: 'Interruptions',
    description: 'Times you interrupted the AI while it was speaking. Interruptions are normal and show active engagement.',
  },
};

// =============================================================================
// Hands-Free Learning Help (matches iOS HandsFreeHelpView)
// =============================================================================

export const handsFreeHelp: Record<string, HelpContent> = {
  overview: {
    title: 'Hands-Free Learning',
    description: 'UnaMentis is designed for hands-free learning. Start a session and continue without touching your device.',
  },
  useCases: {
    title: 'Perfect For',
    description: 'Hands-free learning works great while multitasking.',
    tips: [
      'Walking: Learn during your daily walk or commute',
      'Exercise: Keep your mind active during workouts',
      'Housework: Learn while doing chores',
      'Working: Background learning while performing tasks',
    ],
  },
  bestPractices: {
    title: 'Best Practices',
    description: 'Optimize your hands-free learning experience.',
    tips: [
      'Use headphones for best audio quality',
      'Position your device within speaking distance',
      'Reduce background noise when possible',
      'Use keyboard shortcuts (Space to pause/resume)',
    ],
  },
};

// =============================================================================
// Help Modal Sections (matches iOS HelpView structure)
// =============================================================================

export const helpModalSections = [
  {
    id: 'getting-started',
    title: 'Getting Started',
    content: [
      generalHelp.onboarding,
      generalHelp.voiceLearning,
      curriculumHelp.browse,
      sessionControlsHelp.startSession,
    ],
  },
  {
    id: 'voice-conversations',
    title: 'Voice Conversations',
    content: [
      sessionViewHelp.overview,
      sessionViewHelp.statusIndicator,
      sessionViewHelp.interrupt,
      sessionViewHelp.vuMeter,
    ],
  },
  {
    id: 'curriculum-lessons',
    title: 'Curriculum Lessons',
    content: [
      curriculumHelp.browse,
      curriculumHelp.selectTopic,
      curriculumHelp.curriculumCard,
      curriculumHelp.difficulty,
      curriculumHelp.prerequisites,
    ],
  },
  {
    id: 'during-session',
    title: 'During a Session',
    content: [
      sessionControlsHelp.pauseSession,
      sessionControlsHelp.muteAudio,
      sessionControlsHelp.muteMicrophone,
      generalHelp.visualAssets,
      sessionViewHelp.progressBar,
    ],
  },
  {
    id: 'hands-free',
    title: 'Hands-Free Learning',
    content: [
      handsFreeHelp.overview,
      handsFreeHelp.useCases,
      handsFreeHelp.bestPractices,
    ],
  },
  {
    id: 'customization',
    title: 'Customization',
    content: [
      settingsHelp.voiceSettings,
      settingsHelp.audioInput,
      settingsHelp.audioOutput,
      settingsHelp.displaySettings,
      settingsHelp.sessionPreferences,
    ],
  },
  {
    id: 'analytics',
    title: 'Analytics & Metrics',
    content: [
      analyticsHelp.overview,
      analyticsHelp.e2eLatency,
      analyticsHelp.sttLatency,
      analyticsHelp.costPerHour,
    ],
  },
  {
    id: 'accessibility',
    title: 'Accessibility',
    content: [generalHelp.accessibility],
  },
];

// =============================================================================
// Utility Functions
// =============================================================================

/**
 * Get help content by key from any category.
 *
 * @param key - The key to look up
 * @returns The help content if found, undefined otherwise
 */
export function getHelpContent(key: string): HelpContent | undefined {
  return (
    sessionControlsHelp[key] ||
    curriculumHelp[key] ||
    settingsHelp[key] ||
    authHelp[key] ||
    generalHelp[key] ||
    sessionViewHelp[key] ||
    historyHelp[key] ||
    analyticsHelp[key] ||
    handsFreeHelp[key]
  );
}

/**
 * Get keyboard shortcuts by category.
 *
 * @param category - The category to filter by
 * @returns Array of shortcuts in that category
 */
export function getShortcutsByCategory(
  category: KeyboardShortcut['category']
): KeyboardShortcut[] {
  return keyboardShortcuts.filter((s) => s.category === category);
}

/**
 * Get all keyboard shortcut categories.
 *
 * @returns Array of unique category names
 */
export function getShortcutCategories(): KeyboardShortcut['category'][] {
  return [...new Set(keyboardShortcuts.map((s) => s.category))];
}
