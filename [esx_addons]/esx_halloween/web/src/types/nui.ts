/**
 * NUI event message structure sent from game client
 * @template T - Type of data payload
 */
export interface NuiMessage<T = unknown> {
  /** Event type identifier */
  type: string;
  /** Event data payload (merged with root for some events) */
  [key: string]: any;
}

/**
 * Response structure for NUI callbacks
 * @template T - Type of response data
 */
export interface NuiCallbackResponse<T = unknown> {
  /** Indicates if the request was successful */
  ok: boolean;
  /** Response data if successful */
  data?: T;
  /** Error message if unsuccessful */
  error?: string;
}

/**
 * UI visibility state
 */
export interface VisibilityState {
  /** Current visibility state */
  visible: boolean;
}

/**
 * Configuration options for debug mode
 */
export interface DebugOptions {
  /** Whether debug mode is enabled */
  enabled: boolean;
  /** Delay in milliseconds before triggering debug events */
  delay?: number;
}

/**
 * Event handler function for NUI events
 * @template T - Type of event data
 */
export type NuiEventHandler<T = unknown> = (data: T) => void;

/**
 * Checks if the code is running in a browser environment (not FiveM)
 * @returns {boolean} True if running in browser, false if in FiveM
 * @example
 * if (isEnvBrowser()) {
 *   console.log('Running in browser for development');
 * }
 */
export const isEnvBrowser = (): boolean => !(window as any).invokeNative;

/**
 * Gets the name of the parent FiveM resource
 * Falls back to 'nui-frame-app' in browser environment
 * @returns {string} Resource name
 * @example
 * const resource = getResourceName(); // Returns 'halloween' in FiveM
 */
export const getResourceName = (): string => {
  if (isEnvBrowser()) {
    return 'nui-frame-app';
  }
  return (window as any).GetParentResourceName
    ? (window as any).GetParentResourceName()
    : 'unknown';
};

/**
 * Position where notification should appear
 */
export type NotificationPosition = 'top-left' | 'top-right' | 'top-center' | 'bottom-center';

/**
 * Size variant for notification cards
 */
export type NotificationSize = 'small' | 'large';

/**
 * Notification data structure sent from FiveM client
 */
export interface NotificationData {
  /** Size of the notification card */
  size: NotificationSize;
  /** Screen position where notification appears */
  position: NotificationPosition;
  /** Header/title text */
  header: string;
  /** Description/body text */
  description: string;
  /** Duration in milliseconds before auto-dismiss (default: 5000) */
  duration?: number;
}

/**
 * Internal notification with unique ID for queue management
 */
export interface QueuedNotification extends NotificationData {
  /** Unique identifier for this notification instance */
  id: string;
}

// ============================================================================
// TRICK-OR-TREAT NUI EVENTS & TYPES
// ============================================================================

/**
 * Trick-or-Treat round start data sent from server
 */
export interface TrickOrTreatRoundStartData {
  /** Total number of active houses in this round */
  totalHouses: number;
  /** Duration of the round in milliseconds */
  duration: number;
  /** Array of house IDs that are active this round */
  activeHouseIds: string[];
}

/**
 * Trick-or-Treat candy collection response from server
 */
export interface TrickOrTreatCollectData {
  /** Whether collection was successful */
  success: boolean;
  /** Type of reward: 'treat' or 'trick' */
  rewardType: 'treat' | 'trick';
  /** Item name collected (e.g., 'halloween_candy') */
  rewardItem: string;
  /** Amount of item collected */
  rewardAmount: number;
  /** Number of remaining active houses in round */
  remainingHouses: number;
  /** Error message if unsuccessful */
  error?: string;
}

/**
 * Trick-or-Treat round progress update from server
 */
export interface TrickOrTreatProgressData {
  /** Houses collected so far in this round */
  currentHouses: number;
  /** Total houses in this round */
  totalHouses: number;
  /** Time remaining in round (milliseconds) */
  timeRemaining: number;
}

/**
 * Trick-or-Treat round end data from server
 */
export interface TrickOrTreatRoundEndData {
  /** Total houses that were collected */
  totalCollected: number;
  /** Total houses available */
  totalHouses: number;
}
