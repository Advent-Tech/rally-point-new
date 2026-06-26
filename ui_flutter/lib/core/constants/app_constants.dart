/// App-wide Constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Light Point';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String onboardingKey = 'onboarding_completed';
  static const String helpModeKey = 'help_mode_enabled';
  static const String lastSyncKey = 'last_sync';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Location Tracking
  static const int locationUpdateInterval = 10000; // 10 seconds
  static const int locationDistanceFilter = 10; // 10 meters
  static const double defaultLatitude = 39.8283; // US center
  static const double defaultLongitude = -98.5795;
  static const double defaultZoom = 10.0;

  // Animations
  static const int shortAnimationDuration = 200;
  static const int mediumAnimationDuration = 300;
  static const int longAnimationDuration = 500;

  // Cache
  static const int cacheMaxAge = 7; // days
  static const int offlineMaxAge = 30; // days

  // User Roles
  static const String roleAdmin = 'admin';
  static const String roleTeamLeader = 'team_leader';
  static const String roleWorker = 'worker';
  static const String roleMember = 'member';

  // Territory Status
  static const String statusActive = 'active';
  static const String statusCompleted = 'completed';
  static const String statusPaused = 'paused';
  static const String statusCancelled = 'cancelled';

  // Priority Levels
  static const String priorityHigh = 'high';
  static const String priorityMedium = 'medium';
  static const String priorityLow = 'low';
}
