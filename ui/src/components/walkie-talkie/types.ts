/**
 * Walkie-Talkie Service Types
 * Clean, type-safe interfaces for the walkie-talkie system
 */

// Core State Types
export type WalkieTalkieState = 
  | 'idle'
  | 'initializing'
  | 'ready'
  | 'recording'
  | 'processing'
  | 'uploading'
  | 'error';

export type ConnectionState = 
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'error';

export type AudioState = 
  | 'idle'
  | 'playing'
  | 'paused'
  | 'error';

// Error Types
export interface WalkieTalkieError {
  code: string;
  message: string;
  details?: any;
  timestamp: Date;
  recoverable: boolean;
}

export type ErrorCode = 
  | 'PERMISSION_DENIED'
  | 'MICROPHONE_UNAVAILABLE'
  | 'NETWORK_ERROR'
  | 'UPLOAD_FAILED'
  | 'PLAYBACK_FAILED'
  | 'INITIALIZATION_FAILED'
  | 'RECORDING_FAILED'
  | 'UNKNOWN_ERROR';

// Audio Recording Types
export interface RecordingConfig {
  maxDuration: number; // seconds
  quality: 'low' | 'medium' | 'high';
  format: 'mp3' | 'm4a' | '3gp';
  sampleRate: number;
  bitRate: number;
}

export interface RecordingResult {
  id: string;
  uri: string;
  duration: number;
  size: number;
  format: string;
  timestamp: Date;
}

// Message Types
export interface VoiceMessage {
  id: string;
  senderId: string;
  senderName: string;
  teamId: string;
  audioUrl: string;
  duration: number;
  timestamp: Date;
  isOwn: boolean;
}

// Service State
export interface WalkieTalkieServiceState {
  // Connection
  connectionState: ConnectionState;
  isInitialized: boolean;
  
  // Audio
  state: WalkieTalkieState;
  audioState: AudioState;
  
  // Recording
  isRecording: boolean;
  recordingDuration: number;
  canRecord: boolean;
  audioLevel: number; // Real-time audio level (0-1)
  
  // Processing
  isProcessing: boolean;
  isUploading: boolean;
  uploadProgress: number;
  
  // Messages
  messages: VoiceMessage[];
  unreadCount: number;
  
  // Playback
  isPlayingMessage: boolean;
  currentPlayingMessageId: string | null;
  currentPlayingSender: string | null;
  
  // Error handling
  error: WalkieTalkieError | null;
  lastError: WalkieTalkieError | null;
  
  // Statistics
  totalMessagesSent: number;
  totalMessagesReceived: number;
}

// Service Configuration
export interface WalkieTalkieConfig {
  teamId: string;
  userId: string;
  userName: string;
  
  // Audio settings
  recording: RecordingConfig;
  autoPlay: boolean;
  speakerMode: boolean;
  
  // Network settings
  uploadTimeout: number;
  retryAttempts: number;
  
  // UI settings
  vibrationEnabled: boolean;
  soundEnabled: boolean;
}

// Event Types
export type WalkieTalkieEvent = 
  | { type: 'STATE_CHANGED'; payload: { state: WalkieTalkieState } }
  | { type: 'CONNECTION_CHANGED'; payload: { connectionState: ConnectionState } }
  | { type: 'RECORDING_STARTED'; payload: { recordingId: string } }
  | { type: 'RECORDING_STOPPED'; payload: { recordingId: string; duration: number } }
  | { type: 'MESSAGE_RECEIVED'; payload: { message: VoiceMessage } }
  | { type: 'MESSAGE_SENT'; payload: { message: VoiceMessage } }
  | { type: 'PLAYBACK_STARTED'; payload: { messageId: string; senderName?: string } }
  | { type: 'PLAYBACK_STOPPED'; payload: {} }
  | { type: 'ERROR_OCCURRED'; payload: { error: WalkieTalkieError } }
  | { type: 'ERROR_CLEARED'; payload: {} }
  | { type: 'UPLOAD_PROGRESS'; payload: { progress: number } };

// Service Interface
export interface IWalkieTalkieService {
  // State
  getState(): WalkieTalkieServiceState;
  
  // Lifecycle
  initialize(config: WalkieTalkieConfig): Promise<void>;
  destroy(): Promise<void>;
  
  // Recording
  startRecording(): Promise<string>;
  stopRecording(): Promise<RecordingResult>;
  
  // Playback
  playMessage(messageId: string): Promise<void>;
  stopPlayback(): Promise<void>;
  
  // Messages
  sendMessage(recording: RecordingResult): Promise<VoiceMessage>;
  getMessages(): VoiceMessage[];
  markAsRead(messageId: string): void;
  
  // Error handling
  clearError(): void;
  retry(): Promise<void>;
  
  // Events
  on(event: string, callback: (data: any) => void): void;
  off(event: string, callback: (data: any) => void): void;
  emit(event: WalkieTalkieEvent): void;
}

// Hook Return Type
export interface UseWalkieTalkieReturn {
  // State
  state: WalkieTalkieServiceState;
  
  // Actions
  initialize: (config: WalkieTalkieConfig) => Promise<void>;
  startRecording: () => void; // Non-blocking
  stopRecording: () => void; // Non-blocking
  playMessage: (messageId: string) => Promise<void>;
  clearError: () => void;
  retry: () => Promise<void>;
  
  // Computed
  isReady: boolean;
  canStartRecording: boolean;
  hasError: boolean;
  isConnected: boolean;
}
