# Walkie-Talkie Service

A clean, modern walkie-talkie system with proper error handling, loading states, and state management.

## Features

- 🎤 **Audio Recording**: High-quality voice recording with configurable settings
- 🔊 **Audio Playback**: Reliable playback with proper audio routing
- 🔄 **State Management**: Centralized state with proper event handling
- ❌ **Error Handling**: Comprehensive error handling with recovery suggestions
- 📱 **React Integration**: Easy-to-use React hooks and components
- 🎯 **TypeScript**: Full type safety throughout the system
- 🔧 **Configurable**: Flexible configuration for different use cases

## Quick Start

### Basic Usage

```tsx
import React from 'react';
import { WalkieTalkiePanel } from './components/walkie-talkie';

function MyComponent() {
  return (
    <WalkieTalkiePanel
      teamId="team_123"
      userId="user_456"
      userName="John Doe"
      onRecordingStart={() => console.log('Recording started')}
      onRecordingStop={() => console.log('Recording stopped')}
      onError={(error) => console.error('Error:', error)}
    />
  );
}
```

### Using the Hook

```tsx
import React, { useEffect } from 'react';
import { useWalkieTalkie } from './components/walkie-talkie';

function CustomWalkieTalkie() {
  const {
    state,
    initialize,
    startRecording,
    stopRecording,
    isReady,
    hasError,
  } = useWalkieTalkie();

  useEffect(() => {
    initialize({
      teamId: 'team_123',
      userId: 'user_456',
      userName: 'John Doe',
      recording: {
        maxDuration: 60,
        quality: 'high',
        format: 'm4a',
        sampleRate: 44100,
        bitRate: 128000,
      },
      autoPlay: true,
      speakerMode: true,
      uploadTimeout: 30000,
      retryAttempts: 3,
      vibrationEnabled: true,
      soundEnabled: true,
    });
  }, []);

  return (
    <div>
      <p>Status: {state.connectionState}</p>
      <p>Ready: {isReady ? 'Yes' : 'No'}</p>
      <p>Error: {hasError ? state.error?.message : 'None'}</p>
      
      <button
        onMouseDown={startRecording}
        onMouseUp={stopRecording}
        disabled={!isReady}
      >
        Hold to Talk
      </button>
    </div>
  );
}
```

### Using Individual Components

```tsx
import React from 'react';
import { 
  WalkieTalkieButton, 
  MessageList, 
  useWalkieTalkie 
} from './components/walkie-talkie';

function CustomLayout() {
  const { state } = useWalkieTalkie();

  const config = {
    teamId: 'team_123',
    userId: 'user_456',
    userName: 'John Doe',
    // ... other config
  };

  return (
    <div>
      <MessageList maxHeight={200} />
      
      <WalkieTalkieButton
        config={config}
        size="large"
        onRecordingStart={() => console.log('Started')}
        onRecordingStop={() => console.log('Stopped')}
      />
      
      <p>Messages: {state.messages.length}</p>
    </div>
  );
}
```

## Configuration

### WalkieTalkieConfig

```typescript
interface WalkieTalkieConfig {
  teamId: string;           // Team/channel identifier
  userId: string;           // Current user ID
  userName: string;         // Current user display name
  
  // Audio settings
  recording: {
    maxDuration: number;    // Max recording duration (seconds)
    quality: 'low' | 'medium' | 'high';
    format: 'mp3' | 'm4a' | '3gp';
    sampleRate: number;     // Audio sample rate
    bitRate: number;        // Audio bit rate
  };
  
  // Playback settings
  autoPlay: boolean;        // Auto-play received messages
  speakerMode: boolean;     // Use speaker for playback
  
  // Network settings
  uploadTimeout: number;    // Upload timeout (ms)
  retryAttempts: number;    // Number of retry attempts
  
  // UI settings
  vibrationEnabled: boolean; // Haptic feedback
  soundEnabled: boolean;     // Sound effects
}
```

## State Management

The system uses a centralized state manager that tracks:

- **Connection State**: `disconnected` | `connecting` | `connected` | `error`
- **Walkie-Talkie State**: `idle` | `initializing` | `ready` | `recording` | `processing` | `uploading` | `error`
- **Audio State**: `idle` | `playing` | `paused` | `error`
- **Messages**: Array of voice messages with metadata
- **Error Handling**: Current and last errors with recovery info

## Error Handling

The system includes comprehensive error handling:

```typescript
// Error codes
type ErrorCode = 
  | 'PERMISSION_DENIED'
  | 'MICROPHONE_UNAVAILABLE'
  | 'NETWORK_ERROR'
  | 'UPLOAD_FAILED'
  | 'PLAYBACK_FAILED'
  | 'INITIALIZATION_FAILED'
  | 'RECORDING_FAILED'
  | 'UNKNOWN_ERROR';

// Error object
interface WalkieTalkieError {
  code: ErrorCode;
  message: string;
  details?: any;
  timestamp: Date;
  recoverable: boolean;
}
```

### Error Recovery

```tsx
const { state, retry, clearError } = useWalkieTalkie();

if (state.error) {
  // Show error message
  console.log(state.error.message);
  
  // Get recovery suggestions
  const suggestions = errorHandler.getRecoverySuggestions(state.error);
  
  // Retry if recoverable
  if (state.error.recoverable) {
    await retry();
  }
  
  // Or clear error
  clearError();
}
```

## Events

The system emits events for important state changes:

```typescript
const service = WalkieTalkieService.getInstance();

// Listen to events
service.on('STATE_CHANGED', (event) => {
  console.log('State changed:', event.payload.state);
});

service.on('MESSAGE_RECEIVED', (event) => {
  console.log('New message:', event.payload.message);
});

service.on('ERROR_OCCURRED', (event) => {
  console.log('Error:', event.payload.error);
});
```

## Implementation Notes

### Audio Upload

The service includes a placeholder upload method. You need to implement your actual upload logic:

```typescript
// In WalkieTalkieService.ts
private async uploadRecording(recording: RecordingResult): Promise<string> {
  // TODO: Replace with your actual upload implementation
  // Example: Upload to Firebase Storage, AWS S3, etc.
  
  const formData = new FormData();
  formData.append('audio', {
    uri: recording.uri,
    type: 'audio/m4a',
    name: `${recording.id}.m4a`,
  } as any);
  
  const response = await fetch('YOUR_UPLOAD_ENDPOINT', {
    method: 'POST',
    body: formData,
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  });
  
  const result = await response.json();
  return result.audioUrl;
}
```

### Message Synchronization

You'll need to implement message synchronization with your backend:

```typescript
// Example: Listen to new messages from your backend
const subscribeToMessages = (teamId: string) => {
  // Your real-time subscription logic (WebSocket, Firebase, etc.)
  yourBackend.onMessage(teamId, (message) => {
    const voiceMessage: VoiceMessage = {
      id: message.id,
      senderId: message.senderId,
      senderName: message.senderName,
      teamId: message.teamId,
      audioUrl: message.audioUrl,
      duration: message.duration,
      timestamp: new Date(message.timestamp),
      isOwn: message.senderId === currentUserId,
    };
    
    // Add to state
    stateManager.addMessage(voiceMessage);
  });
};
```

## Architecture

```
┌─────────────────────────────────────────┐
│                UI Layer                 │
├─────────────────────────────────────────┤
│  WalkieTalkiePanel                      │
│  ├── WalkieTalkieButton                 │
│  └── MessageList                        │
├─────────────────────────────────────────┤
│                Hook Layer               │
├─────────────────────────────────────────┤
│  useWalkieTalkie                        │
├─────────────────────────────────────────┤
│              Service Layer              │
├─────────────────────────────────────────┤
│  WalkieTalkieService                    │
│  ├── StateManager                       │
│  ├── ErrorHandler                       │
│  └── Audio APIs (expo-av)               │
└─────────────────────────────────────────┘
```

## Dependencies

- `expo-av`: Audio recording and playback
- `expo-file-system`: File system operations
- `react`: React framework
- `react-native`: React Native framework

## License

This walkie-talkie system is part of your Rally Point application.
