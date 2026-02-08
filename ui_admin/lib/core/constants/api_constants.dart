class ApiConstants {
  // Base URL - change this based on environment
  //static const String baseUrl = 'http://localhost:8080';
  static const String baseUrl = 'http://18.188.1.122:8080';

  // Auth endpoints
  static const String login = '/api/auth/login';
  static const String refreshToken = '/api/auth/refresh';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';

  // Superadmin endpoints
  static const String superadminAdmins = '/api/superadmin/admins';

  // Admin endpoints
  static const String adminStats = '/api/admin/stats';
  static const String adminTeamLeaders = '/api/admin/team-leaders';
  static const String adminTeams = '/api/admin/teams';
  static const String adminWorkers = '/api/admin/workers';
  static const String adminWorkersPending = '/api/admin/workers/pending';
  static const String adminWorkersVerified = '/api/admin/workers/verified';
  static const String adminTerritoryAllocate =
      '/api/admin/territories/allocate';
  static const String adminTerritoryAllocations =
      '/api/admin/territories/allocations';

  // User management (via admin proxy)
  static const String adminUsers = '/api/admin/users';

  // Territory endpoints
  static const String territories = '/api/geo/territories';
  static const String territoriesList = '/api/geo/territories/list';
  static const String territoriesSearch = '/api/geo/territories/search';
  static const String territoriesInBounds =
      '/api/geo/territories'; // ?bounds=minLng,minLat,maxLng,maxLat
  static const String unionStats = '/api/geo/stats/unions';

  // Survey endpoints
  static const String surveys = '/api/surveys';
  static const String surveyResponses = '/api/surveys'; // + /{id}/responses
  static const String surveyAnalytics = '/api/surveys'; // + /{id}/analytics

  // Donation endpoints
  static const String donations = '/api/donations';
  static const String donationsAll = '/api/donations/all';
  static const String donationStats = '/api/donations/stats';

  // Receipt endpoints
  static const String receipts = '/api/receipts';
  static const String receiptStats = '/api/receipts/stats';

  // Team endpoints
  static const String teams = '/api/teams/';

  // Blog endpoints
  static const String blogs = '/api/blogs';
  static const String blogUploadImage = '/api/blogs/upload-image';

  // Prayer request endpoints
  static const String prayerRequests = '/api/prayer-requests/';
  static const String prayerRequestStats = '/api/prayer-requests/stats';
  static const String prayerRequestMap = '/api/prayer-requests/map';

  // Geofence & Worker tracking endpoints
  static const String activeWorkers = '/api/geofence/workers/active';
  static const String workerSessions =
      '/api/geofence/worker'; // + /{workerId}/sessions
  static const String teamActiveWorkers =
      '/api/geofence/teams'; // + /{teamId}/workers/active

  // Church locations
  static const String churches = '/api/geo/churches';

  // Delivery stats endpoints
  static const String teamDeliveryStats = '/api/teams'; // + /{teamId}/stats
  static const String teamWorkerStats =
      '/api/teams'; // + /{teamId}/worker-stats

  // Conference stats
  static const String conferenceStats = '/api/geo/stats/conferences';

  // Territory validation
  static const String validateGeometry = '/api/geo/territories/validate';
}
