import { Platform } from 'react-native';

/**
 * Web-specific optimizations to prevent component vibrating/flickering
 */
export class WebOptimizations {
  
  /**
   * Get optimized animation config for web vs mobile
   */
  static getAnimationConfig(mobileConfig: any) {
    if (Platform.OS === 'web') {
      return {
        ...mobileConfig,
        useNativeDriver: false, // Disable native driver on web
        duration: Math.min(mobileConfig.duration || 300, 200), // Faster animations
        friction: (mobileConfig.friction || 8) * 1.5, // Less bouncy
        tension: (mobileConfig.tension || 40) * 1.5, // Stiffer springs
      };
    }
    return mobileConfig;
  }

  /**
   * Debounce function calls to prevent rapid re-renders
   */
  static debounce<T extends (...args: any[]) => any>(
    func: T,
    wait: number = Platform.OS === 'web' ? 100 : 50
  ): (...args: Parameters<T>) => void {
    let timeout: NodeJS.Timeout;
    return (...args: Parameters<T>) => {
      clearTimeout(timeout);
      timeout = setTimeout(() => func(...args), wait);
    };
  }

  /**
   * Throttle function calls to limit execution frequency
   */
  static throttle<T extends (...args: any[]) => any>(
    func: T,
    limit: number = Platform.OS === 'web' ? 200 : 100
  ): (...args: Parameters<T>) => void {
    let inThrottle: boolean;
    return (...args: Parameters<T>) => {
      if (!inThrottle) {
        func(...args);
        inThrottle = true;
        setTimeout(() => (inThrottle = false), limit);
      }
    };
  }

  /**
   * Check if we should use reduced animations for web
   */
  static shouldUseReducedAnimations(): boolean {
    return Platform.OS === 'web';
  }

  /**
   * Get web-safe style properties
   */
  static getWebSafeStyle(style: any) {
    if (Platform.OS === 'web') {
      // Remove properties that cause issues on web
      const { elevation, ...webSafeStyle } = style;
      return {
        ...webSafeStyle,
        // Replace elevation with box-shadow for web
        ...(elevation && {
          boxShadow: `0 ${elevation}px ${elevation * 2}px rgba(0,0,0,0.1)`,
        }),
      };
    }
    return style;
  }

  /**
   * Optimize useEffect dependencies for web
   */
  static optimizeEffectDeps(deps: any[]): any[] {
    if (Platform.OS === 'web') {
      // Stringify objects to prevent unnecessary re-renders
      return deps.map(dep => 
        typeof dep === 'object' && dep !== null 
          ? JSON.stringify(dep) 
          : dep
      );
    }
    return deps;
  }
}

export default WebOptimizations;
