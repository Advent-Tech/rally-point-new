/// API Constants for Rally Point Backend
class ApiConstants {
  ApiConstants._();

  // Base URLs
  static const String prodBaseUrl = 'https://api.rallypoint.app';
  static const String devBaseUrl = 'http://10.0.2.2:8080'; // Android emulator
  static const String devBaseUrlIOS = 'http://localhost:8080'; // iOS simulator

  // Service Ports (for direct connection in dev)
  static const int apiGatewayPort = 8080;
  static const int userServicePort = 8081;
  static const int locationServicePort = 8082;
  static const int territoryServicePort = 8083;
  static const int surveyServicePort = 8084;
  static const int deliveryServicePort = 8085;
  static const int walkieServicePort = 8086;
  static const int ministryServicePort = 8087;

  // Auth Endpoints
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String refreshToken = '/api/auth/refresh';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String verifyEmail = '/api/auth/verify-email';

  // User Endpoints
  static const String userMe = '/api/users/me';
  static const String currentUser = '/api/users/me';
  static const String userProfile = '/api/users/profile';
  static const String updateProfile = '/api/users/profile';
  static const String userLogout = '/api/users/logout';
  static const String logout = '/api/users/logout';

  // Team Endpoints
  static const String teams = '/api/teams';
  static const String myTeams = '/api/teams/my';
  static const String teamsSearch = '/api/teams/search';
  static const String teamsJoin = '/api/teams/join';
  static const String teamsLeave = '/api/teams/leave';
  static const String teamStats = '/api/teams'; // + /{id}/stats
  static const String teamWorkerStats = '/api/teams'; // + /{id}/worker-stats

  // Work Session Endpoints
  static const String workSessions = '/api/geofence';
  static const String workerSessions = '/api/geofence/worker'; // + /{workerId}/sessions
  static const String workerCurrentSession = '/api/geofence/worker'; // + /{workerId}/current

  // Activity Endpoints
  static const String teamActivity = '/api/teams'; // + /{id}/activity
  static const String assignmentVisit = '/api/geo/assignments'; // + /{id}/visit

  // Location Endpoints
  static const String locationUpdate = '/api/location/update';
  static const String locationTrack = '/api/location/track';
  static const String locationBatch = '/api/location/batch';
  static const String locationHistory = '/api/location/history';
  static const String locationStats = '/api/location/stats';
  static const String locationSessions = '/api/sessions';
  static const String sessionsStart = '/api/sessions/start';
  static const String sessionsActive = '/api/sessions/active';
  static const String workersActive = '/api/workers/active';
  static const String workersNearby = '/api/workers/nearby';
  static const String geofenceCheckin = '/api/geofence/checkin';
  static const String geofenceCheckout = '/api/geofence/checkout';

  // Territory Endpoints
  static const String territories = '/api/territories';
  static const String territoriesNearby = '/api/territories/nearby';
  static const String territoriesSearch = '/api/territories/search';
  static const String geoTerritories = '/api/geo/territories';
  static const String geoTerritoriesSearch = '/api/geo/territories/search';
  static const String geoTerritoriesList = '/api/geo/territories/list';
  static const String geoTerritoriesAt = '/api/geo/territories/at';
  static const String geoChurches = '/api/geo/churches';
  static const String churchLocations = '/api/geo/churches';
  static const String geoStatsUnions = '/api/geo/stats/unions';
  static const String unionStats = '/api/geo/stats/unions';
  static const String geoStatsConferences = '/api/geo/stats/conferences';
  static const String geoAssignments = '/api/geo/assignments';
  static const String assignments = '/api/geo/assignments';
  // Note: /api/geo/assignments/my doesn't exist, use /api/geo/assignments instead
  // Backend should filter by authenticated user from JWT token
  static const String myAssignments = '/api/geo/assignments';
  static const String requestTerritory = '/api/geo/assignments/request';
  static const String geofenceCheck = '/api/geofence/check';
  static const String geofenceLocationUpdate = '/api/geofence/location-update';

  // Survey Endpoints
  static const String surveys = '/api/surveys';
  static const String surveyResponses = '/api/responses';
  static const String surveyAssignments = '/api/assignments';
  static const String userSurveys = '/api/users/surveys';
  static const String userSurveyResponses = '/api/users/responses';
  static const String userSurveyAssignments = '/api/users/assignments';

  // Delivery Endpoints
  // Note: Use trailing slash for POST to avoid 307 redirect from Gin router
  static const String deliveries = '/api/deliveries';
  static const String deliveriesCreate = '/api/deliveries/';
  static const String workerDeliveries = '/api/workers'; // + /{workerId}/deliveries
  static const String routes = '/api/routes';

  // Payment Endpoints
  static const String createPaymentIntent = '/api/payments/create-intent';
  static const String verifyPayment = '/api/payments/verify';
  static const String sendPaymentLink = '/api/payments/send-link';
  static const String paymentStatus = '/api/payments/status'; // + /{sessionId}
  static const String receipts = '/api/receipts';

  // Walkie Endpoints
  static const String walkieStart = '/api/walkie/start';
  static const String walkieEnd = '/api/walkie/end';
  static const String walkieMessages = '/api/walkie/messages';

  // Ministry Contacts
  static const String ministryContacts = '/api/ministry-contacts';

  // WebSocket Endpoints
  static const String wsLocation = '/ws/location';
  static const String wsTerritory = '/ws/territory';
  static const String wsWalkie = '/ws/walkie';
  static const String wsChat = '/ws/chat';
  static const String wsGeneric = '/ws';

  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
}
