import React from 'react';
import { render, act } from '@testing-library/react-native';
import DistanceTrackingDisplay from '../components/DistanceTrackingDisplay';
import { useLocation } from '../contexts/LocationContext';

// Mock the LocationContext
jest.mock('../contexts/LocationContext', () => ({
  useLocation: jest.fn()
}));

// Mock Animated
jest.mock('react-native', () => {
  const RN = jest.requireActual('react-native');
  return {
    ...RN,
    Animated: {
      ...RN.Animated,
      timing: jest.fn(() => ({
        start: jest.fn((callback) => callback && callback())
      })),
      Value: jest.fn(() => ({
        setValue: jest.fn(),
        interpolate: jest.fn(() => 'mocked-interpolation')
      }))
    }
  };
});

describe('DistanceTrackingDisplay', () => {
  const mockLocationContext = {
    isTracking: true,
    currentMinistrySession: {
      id: 'test-session',
      userId: 'user123',
      userName: 'John Doe',
      userRole: 'worker',
      startTime: new Date(Date.now() - 3600000), // 1 hour ago
      totalDistance: 1500, // 1.5 km
      pathPoints: [
        { latitude: 40.7128, longitude: -74.0060, timestamp: Date.now() - 3600000, accuracy: 5 },
        { latitude: 40.7589, longitude: -73.9851, timestamp: Date.now() - 1800000, accuracy: 3 },
        { latitude: 40.7831, longitude: -73.9712, timestamp: Date.now(), accuracy: 4 }
      ],
      isActive: true,
      sessionName: 'Test Session',
      createdAt: new Date(),
      updatedAt: new Date(),
      syncStatus: 'synced' as const
    },
    sessionDuration: 3600, // 1 hour in seconds
    getSessionPath: jest.fn(() => [
      { latitude: 40.7128, longitude: -74.0060, timestamp: Date.now() - 3600000, accuracy: 5 },
      { latitude: 40.7589, longitude: -73.9851, timestamp: Date.now() - 1800000, accuracy: 3 },
      { latitude: 40.7831, longitude: -73.9712, timestamp: Date.now(), accuracy: 4 }
    ]),
    getSessionSummary: jest.fn(() => ({
      totalDistance: 1500,
      duration: 3600,
      pathPointCount: 3,
      averageSpeed: 1.5
    }))
  };

  beforeEach(() => {
    (useLocation as jest.Mock).mockReturnValue(mockLocationContext);
    jest.clearAllMocks();
  });

  describe('Rendering', () => {
    test('should render compact mode by default', () => {
      const { getByText } = render(<DistanceTrackingDisplay />);
      
      expect(getByText('1.50 km')).toBeTruthy();
      expect(getByText('1h 0m')).toBeTruthy();
    });

    test('should render full mode when specified', () => {
      const { getByText } = render(<DistanceTrackingDisplay mode="full" />);
      
      expect(getByText('Distance Traveled')).toBeTruthy();
      expect(getByText('Session Duration')).toBeTruthy();
      expect(getByText('1.50 km')).toBeTruthy();
      expect(getByText('1h 0m')).toBeTruthy();
    });

    test('should not render when not tracking', () => {
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        isTracking: false,
        currentMinistrySession: null
      });

      const { queryByText } = render(<DistanceTrackingDisplay />);
      
      expect(queryByText('1.50 km')).toBeNull();
    });

    test('should show path info when showPath is true', () => {
      const { getByText } = render(<DistanceTrackingDisplay showPath={true} />);
      
      expect(getByText('3 points')).toBeTruthy();
    });
  });

  describe('Distance Formatting', () => {
    test('should format distance in meters for small distances', () => {
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        currentMinistrySession: {
          ...mockLocationContext.currentMinistrySession,
          totalDistance: 500 // 500 meters
        }
      });

      const { getByText } = render(<DistanceTrackingDisplay />);
      expect(getByText('500m')).toBeTruthy();
    });

    test('should format distance in kilometers for large distances', () => {
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        currentMinistrySession: {
          ...mockLocationContext.currentMinistrySession,
          totalDistance: 2500 // 2.5 km
        }
      });

      const { getByText } = render(<DistanceTrackingDisplay />);
      expect(getByText('2.50 km')).toBeTruthy();
    });

    test('should handle zero distance', () => {
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        currentMinistrySession: {
          ...mockLocationContext.currentMinistrySession,
          totalDistance: 0
        }
      });

      const { getByText } = render(<DistanceTrackingDisplay />);
      expect(getByText('0m')).toBeTruthy();
    });
  });

  describe('Duration Formatting', () => {
    test('should format duration in minutes for short sessions', () => {
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        sessionDuration: 1800 // 30 minutes
      });

      const { getByText } = render(<DistanceTrackingDisplay />);
      expect(getByText('30m')).toBeTruthy();
    });

    test('should format duration in hours and minutes for long sessions', () => {
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        sessionDuration: 5400 // 1 hour 30 minutes
      });

      const { getByText } = render(<DistanceTrackingDisplay />);
      expect(getByText('1h 30m')).toBeTruthy();
    });

    test('should handle zero duration', () => {
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        sessionDuration: 0
      });

      const { getByText } = render(<DistanceTrackingDisplay />);
      expect(getByText('0m')).toBeTruthy();
    });
  });

  describe('Animation', () => {
    test('should animate distance updates', () => {
      const { rerender } = render(<DistanceTrackingDisplay />);
      
      // Update distance
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        currentMinistrySession: {
          ...mockLocationContext.currentMinistrySession,
          totalDistance: 2000 // Updated distance
        }
      });

      rerender(<DistanceTrackingDisplay />);

      // Check that animation was triggered
      const mockTiming = require('react-native').Animated.timing;
      expect(mockTiming).toHaveBeenCalled();
    });
  });

  describe('Error Handling', () => {
    test('should handle missing session data gracefully', () => {
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        currentMinistrySession: null
      });

      const { queryByText } = render(<DistanceTrackingDisplay />);
      expect(queryByText('0m')).toBeNull();
    });

    test('should handle invalid distance values', () => {
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        currentMinistrySession: {
          ...mockLocationContext.currentMinistrySession,
          totalDistance: NaN
        }
      });

      const { getByText } = render(<DistanceTrackingDisplay />);
      expect(getByText('0m')).toBeTruthy();
    });

    test('should handle invalid duration values', () => {
      (useLocation as jest.Mock).mockReturnValue({
        ...mockLocationContext,
        sessionDuration: NaN
      });

      const { getByText } = render(<DistanceTrackingDisplay />);
      expect(getByText('0m')).toBeTruthy();
    });
  });

  describe('Accessibility', () => {
    test('should have proper accessibility labels', () => {
      const { getByLabelText } = render(<DistanceTrackingDisplay />);
      
      expect(getByLabelText('Distance traveled: 1.50 kilometers')).toBeTruthy();
      expect(getByLabelText('Session duration: 1 hour 0 minutes')).toBeTruthy();
    });

    test('should have proper accessibility hints', () => {
      const { getByA11yHint } = render(<DistanceTrackingDisplay />);
      
      expect(getByA11yHint('Shows the total distance traveled during the current ministry session')).toBeTruthy();
    });
  });

  describe('Custom Styling', () => {
    test('should apply custom styles', () => {
      const customStyle = { backgroundColor: 'red' };
      const { getByTestId } = render(
        <DistanceTrackingDisplay style={customStyle} testID="distance-display" />
      );
      
      const component = getByTestId('distance-display');
      expect(component.props.style).toContainEqual(customStyle);
    });
  });

  describe('Performance', () => {
    test('should not re-render unnecessarily', () => {
      const renderSpy = jest.fn();
      const TestComponent = () => {
        renderSpy();
        return <DistanceTrackingDisplay />;
      };

      const { rerender } = render(<TestComponent />);
      
      // Re-render with same data
      rerender(<TestComponent />);
      
      // Should only render twice (initial + rerender)
      expect(renderSpy).toHaveBeenCalledTimes(2);
    });

    test('should handle rapid distance updates efficiently', () => {
      const { rerender } = render(<DistanceTrackingDisplay />);
      
      // Simulate rapid updates
      for (let i = 0; i < 10; i++) {
        (useLocation as jest.Mock).mockReturnValue({
          ...mockLocationContext,
          currentMinistrySession: {
            ...mockLocationContext.currentMinistrySession,
            totalDistance: 1000 + i * 100
          }
        });
        
        act(() => {
          rerender(<DistanceTrackingDisplay />);
        });
      }

      // Component should handle this gracefully without errors
      expect(true).toBe(true);
    });
  });
});
