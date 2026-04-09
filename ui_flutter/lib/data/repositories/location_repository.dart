import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../models/location_model.dart';

class LocationRepository {
  final ApiClient _apiClient;

  LocationRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // Start tracking session
  Future<ApiResult<LocationSession>> startSession({
    String? territoryId,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.locationSessions,
        data: {
          if (territoryId != null) 'territoryId': territoryId,
          if (notes != null) 'notes': notes,
        },
      );

      final session = LocationSession.fromJson(response.data);
      return ApiResult.success(session);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to start session: $e');
    }
  }

  // End tracking session
  Future<ApiResult<LocationSession>> endSession(String sessionId) async {
    try {
      final response = await _apiClient.dio.put(
        '${ApiConstants.locationSessions}/$sessionId/end',
      );

      final session = LocationSession.fromJson(response.data);
      return ApiResult.success(session);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to end session: $e');
    }
  }

  // Update location
  Future<ApiResult<LocationTrack>> updateLocation({
    required String sessionId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.locationTrack,
        data: {
          'sessionId': sessionId,
          'latitude': latitude,
          'longitude': longitude,
          if (accuracy != null) 'accuracy': accuracy,
          if (altitude != null) 'altitude': altitude,
          if (speed != null) 'speed': speed,
          if (heading != null) 'heading': heading,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final track = LocationTrack.fromJson(response.data);
      return ApiResult.success(track);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to update location: $e');
    }
  }

  // Batch update locations (for offline sync)
  Future<ApiResult<void>> batchUpdateLocations(
      List<LocationUpdate> updates) async {
    try {
      await _apiClient.dio.post(
        ApiConstants.locationBatch,
        data: {
          'locations': updates.map((e) => e.toJson()).toList(),
        },
      );

      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to sync locations: $e');
    }
  }

  // Get active sessions
  Future<ApiResult<List<LocationSession>>> getActiveSessions() async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.locationSessions,
        queryParameters: {'status': 'active'},
      );

      final List<dynamic> data = response.data['sessions'] ?? response.data;
      final sessions = data.map((e) => LocationSession.fromJson(e)).toList();

      return ApiResult.success(sessions);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch sessions: $e');
    }
  }

  // Get session history
  Future<ApiResult<List<LocationSession>>> getSessionHistory({
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final response = await _apiClient.dio.get(
        ApiConstants.locationHistory,
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data['sessions'] ?? response.data;
      final sessions = data.map((e) => LocationSession.fromJson(e)).toList();

      return ApiResult.success(sessions);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch session history: $e');
    }
  }

  // Get location statistics
  Future<ApiResult<LocationStats>> getLocationStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final response = await _apiClient.dio.get(
        ApiConstants.locationStats,
        queryParameters: queryParams,
      );

      final stats = LocationStats.fromJson(response.data);
      return ApiResult.success(stats);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch location stats: $e');
    }
  }

  // Get nearby workers
  Future<ApiResult<List<WorkerLocation>>> getNearbyWorkers({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.workersNearby,
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'radius': radiusKm,
        },
      );

      final List<dynamic> data = response.data['workers'] ?? response.data;
      final workers = data.map((e) => WorkerLocation.fromJson(e)).toList();

      return ApiResult.success(workers);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch nearby workers: $e');
    }
  }

  // Check into geofence
  Future<ApiResult<void>> checkIntoGeofence({
    required String geofenceId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _apiClient.dio.post(
        ApiConstants.geofenceCheckin,
        data: {
          'geofenceId': geofenceId,
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to check in: $e');
    }
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;

        if (data is Map && data['message'] != null) {
          return data['message'];
        }
        return 'Server error (Status: $statusCode)';
      case DioExceptionType.connectionError:
        return 'No internet connection';
      default:
        return 'An unexpected error occurred';
    }
  }
}
