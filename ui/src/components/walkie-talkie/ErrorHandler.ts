/**
 * Walkie-Talkie Error Handler
 * Centralized error handling with proper categorization and recovery strategies
 */

import { WalkieTalkieError, ErrorCode } from './types';

export class WalkieTalkieErrorHandler {
  private static instance: WalkieTalkieErrorHandler;
  private errorHistory: WalkieTalkieError[] = [];
  private maxHistorySize = 50;

  static getInstance(): WalkieTalkieErrorHandler {
    if (!WalkieTalkieErrorHandler.instance) {
      WalkieTalkieErrorHandler.instance = new WalkieTalkieErrorHandler();
    }
    return WalkieTalkieErrorHandler.instance;
  }

  /**
   * Create a standardized error object
   */
  createError(
    code: ErrorCode,
    message: string,
    details?: any,
    recoverable: boolean = true
  ): WalkieTalkieError {
    const error: WalkieTalkieError = {
      code,
      message,
      details,
      timestamp: new Date(),
      recoverable,
    };

    this.addToHistory(error);
    this.logError(error);

    return error;
  }

  /**
   * Handle different types of errors with appropriate responses
   */
  handleError(error: any): WalkieTalkieError {
    console.error('🚨 WalkieTalkie Error:', error);

    // Permission errors
    if (this.isPermissionError(error)) {
      return this.createError(
        'PERMISSION_DENIED',
        'Microphone permission is required for walkie-talkie functionality',
        error,
        true
      );
    }

    // Network errors
    if (this.isNetworkError(error)) {
      return this.createError(
        'NETWORK_ERROR',
        'Network connection failed. Please check your internet connection.',
        error,
        true
      );
    }

    // Audio/Recording errors
    if (this.isAudioError(error)) {
      return this.createError(
        'RECORDING_FAILED',
        'Failed to record audio. Please check your microphone.',
        error,
        true
      );
    }

    // Upload errors
    if (this.isUploadError(error)) {
      return this.createError(
        'UPLOAD_FAILED',
        'Failed to upload voice message. Please try again.',
        error,
        true
      );
    }

    // Playback errors
    if (this.isPlaybackError(error)) {
      return this.createError(
        'PLAYBACK_FAILED',
        'Failed to play voice message. Please check your audio settings.',
        error,
        true
      );
    }

    // Generic error
    return this.createError(
      'UNKNOWN_ERROR',
      error?.message || 'An unexpected error occurred',
      error,
      true
    );
  }

  /**
   * Get recovery suggestions for an error
   */
  getRecoverySuggestions(error: WalkieTalkieError): string[] {
    switch (error.code) {
      case 'PERMISSION_DENIED':
        return [
          'Go to Settings → Apps → Your App → Permissions',
          'Enable Microphone permission',
          'Restart the app',
        ];

      case 'MICROPHONE_UNAVAILABLE':
        return [
          'Close other apps that might be using the microphone',
          'Disconnect Bluetooth headphones temporarily',
          'Restart your device',
          'Check if microphone works in other apps',
        ];

      case 'NETWORK_ERROR':
        return [
          'Check your internet connection',
          'Try switching between WiFi and mobile data',
          'Wait a moment and try again',
        ];

      case 'UPLOAD_FAILED':
        return [
          'Check your internet connection',
          'Try recording a shorter message',
          'Wait a moment and try again',
        ];

      case 'PLAYBACK_FAILED':
        return [
          'Check your device volume',
          'Disconnect Bluetooth headphones',
          'Try using wired headphones',
          'Restart the app',
        ];

      case 'RECORDING_FAILED':
        return [
          'Check microphone permissions',
          'Close other apps using audio',
          'Try recording a shorter message',
          'Restart the app',
        ];

      case 'INITIALIZATION_FAILED':
        return [
          'Check microphone permissions',
          'Check internet connection',
          'Restart the app',
          'Clear app cache',
        ];

      default:
        return [
          'Try again in a moment',
          'Restart the app',
          'Check your internet connection',
        ];
    }
  }

  /**
   * Check if error is recoverable
   */
  isRecoverable(error: WalkieTalkieError): boolean {
    return error.recoverable;
  }

  /**
   * Get error history
   */
  getErrorHistory(): WalkieTalkieError[] {
    return [...this.errorHistory];
  }

  /**
   * Clear error history
   */
  clearHistory(): void {
    this.errorHistory = [];
  }

  // Private helper methods
  private addToHistory(error: WalkieTalkieError): void {
    this.errorHistory.unshift(error);
    if (this.errorHistory.length > this.maxHistorySize) {
      this.errorHistory = this.errorHistory.slice(0, this.maxHistorySize);
    }
  }

  private logError(error: WalkieTalkieError): void {
    console.group(`🚨 WalkieTalkie Error [${error.code}]`);
    console.error('Message:', error.message);
    console.error('Timestamp:', error.timestamp.toISOString());
    console.error('Recoverable:', error.recoverable);
    if (error.details) {
      console.error('Details:', error.details);
    }
    console.groupEnd();
  }

  // Error type detection methods
  private isPermissionError(error: any): boolean {
    const message = error?.message?.toLowerCase() || '';
    return (
      message.includes('permission') ||
      message.includes('denied') ||
      message.includes('not allowed') ||
      error?.code === 'PERMISSION_DENIED'
    );
  }

  private isNetworkError(error: any): boolean {
    const message = error?.message?.toLowerCase() || '';
    return (
      message.includes('network') ||
      message.includes('fetch') ||
      message.includes('timeout') ||
      message.includes('connection') ||
      error?.code === 'NETWORK_ERROR'
    );
  }

  private isAudioError(error: any): boolean {
    const message = error?.message?.toLowerCase() || '';
    return (
      message.includes('audio') ||
      message.includes('recording') ||
      message.includes('microphone') ||
      message.includes('no valid audio data') ||
      error?.code === 'RECORDING_FAILED'
    );
  }

  private isUploadError(error: any): boolean {
    const message = error?.message?.toLowerCase() || '';
    return (
      message.includes('upload') ||
      message.includes('storage') ||
      message.includes('supabase') ||
      error?.code === 'UPLOAD_FAILED'
    );
  }

  private isPlaybackError(error: any): boolean {
    const message = error?.message?.toLowerCase() || '';
    return (
      message.includes('playback') ||
      message.includes('exoplayer') ||
      message.includes('sound') ||
      message.includes('audio.sound') ||
      error?.code === 'PLAYBACK_FAILED'
    );
  }
}

// Export singleton instance
export const errorHandler = WalkieTalkieErrorHandler.getInstance();
