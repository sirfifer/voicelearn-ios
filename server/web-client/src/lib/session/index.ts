/**
 * Session Layer
 *
 * XState-based session state machine and React hooks for managing
 * voice learning sessions. Provides the same session states as iOS.
 */

// State machine
export {
  sessionMachine,
  type SessionMachine,
  type SessionMachineContext,
  type SessionMachineEvent,
} from './machine';

// React hooks
export {
  useSession,
  useSessionState,
  type UseSessionOptions,
  type UseSessionReturn,
  type UseSessionStateReturn,
} from './hooks';
