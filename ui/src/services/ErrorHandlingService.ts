import { Alert } from 'react-native';

export interface ErrorInfo {
  code: string;
  message: string;
  details?: any;
  timestamp: number;
  context?: string;
}

export type ErrorType = 
  | 'LOCATION_PERMISSION_DENIED'
  | 'LOCATION_UNAVAILABLE'
  | 'LOCATION_TIMEOUT'
  | 'FIREBASE_CONNECTION_ERROR'
  | 'FIREBASE_PERMISSION_ERROR'
  | 'NETWORK_ERROR'
  | 'TERRITORY_NOT_ASSIGNED'
  | 'TRACKING_START_FAILED'
  | 'TRACKING_STOP_FAILED'
  | 'UNKNOWN_ERROR';

class ErrorHandlingService {
  private static instance: ErrorHandlingService;
  private errorLog: ErrorInfo[] = [];
  private maxLogSize = 100;

  private constructor() {}

  static getInstance(): ErrorHandlingService {
    if (!ErrorHandlingService.instance) {
      ErrorHandlingService.instance = new ErrorHandlingService();
    }
    return ErrorHandlingService.instance;
  }

  /**
   * Log an error with context
   */
  logError(type: ErrorType, error: any, context?: string): ErrorInfo {
    const errorInfo: ErrorInfo = {
      code: type,
      message: this.getErrorMessage(type, error),
      details: error,
      timestamp: Date.now(),
      context
    };

    // Add to log
    this.errorLog.unshift(errorInfo);
    
    // Keep log size manageable
    if (this.errorLog.length > this.maxLogSize) {
      this.errorLog = this.errorLog.slice(0, this.maxLogSize);
    }

    console.error(`[${type}] ${errorInfo.message}`, error);
    return errorInfo;
  }

  /**
   * Handle location-related errors
   */
  handleLocationError(error: any, context?: string): ErrorInfo {
    let errorType: ErrorType = 'UNKNOWN_ERROR';

    if (error.code) {
      switch (error.code) {
        case 1:
          errorType = 'LOCATION_PERMISSION_DENIED';
          break;
        case 2:
          errorType = 'LOCATION_UNAVAILABLE';
          break;
        case 3:
          errorType = 'LOCATION_TIMEOUT';
          break;
        default:
          errorType = 'UNKNOWN_ERROR';
      }
    } else if (error.message) {
      if (error.message.includes('permission')) {
        errorType = 'LOCATION_PERMISSION_DENIED';
      } else if (error.message.includes('timeout')) {
        errorType = 'LOCATION_TIMEOUT';
      } else if (error.message.includes('unavailable')) {
        errorType = 'LOCATION_UNAVAILABLE';
      }
    }

    return this.logError(errorType, error, context);
  }

  /**
   * Handle Firebase-related errors
   */
  handleFirebaseError(error: any, context?: string): ErrorInfo {
    let errorType: ErrorType = 'FIREBASE_CONNECTION_ERROR';

    if (error.code) {
      switch (error.code) {
        case 'permission-denied':
          errorType = 'FIREBASE_PERMISSION_ERROR';
          break;
        case 'network-request-failed':
        case 'unavailable':
          errorType = 'NETWORK_ERROR';
          break;
        default:
          errorType = 'FIREBASE_CONNECTION_ERROR';
      }
    }

    return this.logError(errorType, error, context);
  }

  /**
   * Handle tracking-related errors
   */
  handleTrackingError(error: any, isStarting: boolean, context?: string): ErrorInfo {
    const errorType: ErrorType = isStarting ? 'TRACKING_START_FAILED' : 'TRACKING_STOP_FAILED';
    return this.logError(errorType, error, context);
  }

  /**
   * Show user-friendly error alert
   */
  showErrorAlert(errorInfo: ErrorInfo, onRetry?: () => void, onSettings?: () => void) {
    const { title, message, actions } = this.getErrorAlertConfig(errorInfo);

    const alertActions: any[] = [{ text: 'OK', style: 'cancel' }];

    if (actions.includes('retry') && onRetry) {
      alertActions.unshift({ text: 'Retry', onPress: onRetry });
    }

    if (actions.includes('settings') && onSettings) {
      alertActions.unshift({ text: 'Settings', onPress: onSettings });
    }

    Alert.alert(title, message, alertActions);
  }

  /**
   * Get error message for display
   */
  private getErrorMessage(type: ErrorType, error: any): string {
    switch (type) {
      case 'LOCATION_PERMISSION_DENIED':
        return 'Location permission denied. Please enable location access in settings.';
      case 'LOCATION_UNAVAILABLE':
        return 'Location services unavailable. Please check GPS and network connection.';
      case 'LOCATION_TIMEOUT':
        return 'Location request timed out. Please try again.';
      case 'FIREBASE_CONNECTION_ERROR':
        return 'Unable to connect to server. Please check your internet connection.';
      case 'FIREBASE_PERMISSION_ERROR':
        return 'Access denied. Please check your account permissions.';
      case 'NETWORK_ERROR':
        return 'Network error. Please check your internet connection and try again.';
      case 'TERRITORY_NOT_ASSIGNED':
        return 'No territory assigned. Please contact your administrator.';
      case 'TRACKING_START_FAILED':
        return 'Failed to start location tracking. Please try again.';
      case 'TRACKING_STOP_FAILED':
        return 'Failed to stop location tracking. Please try again.';
      default:
        return error?.message || 'An unexpected error occurred. Please try again.';
    }
  }

  /**
   * Get alert configuration for error type
   */
  private getErrorAlertConfig(errorInfo: ErrorInfo): {
    title: string;
    message: string;
    actions: string[];
  } {
    switch (errorInfo.code) {
      case 'LOCATION_PERMISSION_DENIED':
        return {
          title: '🔐 Location Permission Required',
          message: errorInfo.message,
          actions: ['settings', 'retry']
        };
      case 'LOCATION_UNAVAILABLE':
      case 'LOCATION_TIMEOUT':
        return {
          title: '📍 Location Error',
          message: errorInfo.message,
          actions: ['retry']
        };
      case 'FIREBASE_CONNECTION_ERROR':
      case 'NETWORK_ERROR':
        return {
          title: '🌐 Connection Error',
          message: errorInfo.message,
          actions: ['retry']
        };
      case 'FIREBASE_PERMISSION_ERROR':
        return {
          title: '🔒 Access Denied',
          message: errorInfo.message,
          actions: []
        };
      case 'TERRITORY_NOT_ASSIGNED':
        return {
          title: '🗺️ Territory Required',
          message: errorInfo.message,
          actions: []
        };
      case 'TRACKING_START_FAILED':
      case 'TRACKING_STOP_FAILED':
        return {
          title: '⚠️ Tracking Error',
          message: errorInfo.message,
          actions: ['retry']
        };
      default:
        return {
          title: '❌ Error',
          message: errorInfo.message,
          actions: ['retry']
        };
    }
  }

  /**
   * Get recent errors
   */
  getRecentErrors(limit: number = 10): ErrorInfo[] {
    return this.errorLog.slice(0, limit);
  }

  /**
   * Clear error log
   */
  clearErrorLog(): void {
    this.errorLog = [];
  }

  /**
   * Check if error is recoverable
   */
  isRecoverableError(errorType: ErrorType): boolean {
    const recoverableErrors: ErrorType[] = [
      'LOCATION_TIMEOUT',
      'FIREBASE_CONNECTION_ERROR',
      'NETWORK_ERROR',
      'TRACKING_START_FAILED',
      'TRACKING_STOP_FAILED'
    ];
    return recoverableErrors.includes(errorType);
  }
}

export default ErrorHandlingService;
