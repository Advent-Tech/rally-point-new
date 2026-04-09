import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../models/prayer_request_model.dart';

class PrayerRequestRepository {
  final ApiClient _apiClient;

  PrayerRequestRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // Create a new prayer request
  Future<ApiResult<PrayerRequestModel>> createPrayerRequest(
      CreatePrayerRequestRequest request) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.prayerRequestsCreate,
        data: request.toJson(),
      );

      final prayerRequest = PrayerRequestModel.fromJson(response.data);
      return ApiResult.success(prayerRequest);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to create prayer request: $e');
    }
  }

  // Get prayer request by ID
  Future<ApiResult<PrayerRequestModel>> getPrayerRequest(String id) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.prayerRequests}/$id',
      );

      final prayerRequest = PrayerRequestModel.fromJson(response.data);
      return ApiResult.success(prayerRequest);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch prayer request: $e');
    }
  }

  // Update prayer request
  Future<ApiResult<PrayerRequestModel>> updatePrayerRequest(
      String id, UpdatePrayerRequestRequest request) async {
    try {
      final response = await _apiClient.dio.put(
        '${ApiConstants.prayerRequests}/$id',
        data: request.toJson(),
      );

      final prayerRequest = PrayerRequestModel.fromJson(response.data);
      return ApiResult.success(prayerRequest);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to update prayer request: $e');
    }
  }

  // Delete prayer request
  Future<ApiResult<bool>> deletePrayerRequest(String id) async {
    try {
      await _apiClient.dio.delete('${ApiConstants.prayerRequests}/$id');
      return const ApiResult.success(true);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to delete prayer request: $e');
    }
  }

  // Get my prayer requests (for workers)
  Future<ApiResult<PrayerRequestListResponse>> getMyPrayerRequests({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.prayerRequestsMe,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );

      final listResponse = PrayerRequestListResponse.fromJson(response.data);
      return ApiResult.success(listResponse);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ApiResult.success(const PrayerRequestListResponse(
          prayerRequests: [],
          total: 0,
          page: 1,
          pageSize: 20,
          totalPages: 0,
        ));
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch prayer requests: $e');
    }
  }

  // List all prayer requests with filters
  Future<ApiResult<PrayerRequestListResponse>> listPrayerRequests({
    String? teamId,
    String? territoryId,
    String? status,
    String? requestType,
    String? category,
    String? urgency,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };

      if (teamId != null) queryParams['team_id'] = teamId;
      if (territoryId != null) queryParams['territory_id'] = territoryId;
      if (status != null) queryParams['status'] = status;
      if (requestType != null) queryParams['request_type'] = requestType;
      if (category != null) queryParams['category'] = category;
      if (urgency != null) queryParams['urgency'] = urgency;

      final response = await _apiClient.dio.get(
        ApiConstants.prayerRequests,
        queryParameters: queryParams,
      );

      final listResponse = PrayerRequestListResponse.fromJson(response.data);
      return ApiResult.success(listResponse);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ApiResult.success(const PrayerRequestListResponse(
          prayerRequests: [],
          total: 0,
          page: 1,
          pageSize: 20,
          totalPages: 0,
        ));
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch prayer requests: $e');
    }
  }

  // Get map markers for prayer requests
  Future<ApiResult<List<PrayerRequestMapMarker>>> getMapMarkers({
    String? teamId,
    String? territoryId,
    String? status,
    String? requestType,
  }) async {
    try {
      final queryParams = <String, dynamic>{};

      if (teamId != null) queryParams['team_id'] = teamId;
      if (territoryId != null) queryParams['territory_id'] = territoryId;
      if (status != null) queryParams['status'] = status;
      if (requestType != null) queryParams['request_type'] = requestType;

      final response = await _apiClient.dio.get(
        ApiConstants.prayerRequestsMap,
        queryParameters: queryParams,
      );

      final List<dynamic> markersData = response.data['markers'] ?? [];
      final markers = markersData
          .map((e) => PrayerRequestMapMarker.fromJson(e))
          .toList();

      return ApiResult.success(markers);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const ApiResult.success([]);
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch map markers: $e');
    }
  }

  // Get prayer request statistics
  Future<ApiResult<PrayerRequestStats>> getStats({
    String? teamId,
    String? territoryId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};

      if (teamId != null) queryParams['team_id'] = teamId;
      if (territoryId != null) queryParams['territory_id'] = territoryId;

      final response = await _apiClient.dio.get(
        ApiConstants.prayerRequestsStats,
        queryParameters: queryParams,
      );

      final stats = PrayerRequestStats.fromJson(response.data);
      return ApiResult.success(stats);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch stats: $e');
    }
  }

  // Get prayer requests by worker
  Future<ApiResult<PrayerRequestListResponse>> getWorkerPrayerRequests(
    String workerId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.prayerRequestsWorker}/$workerId',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );

      final listResponse = PrayerRequestListResponse.fromJson(response.data);
      return ApiResult.success(listResponse);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ApiResult.success(const PrayerRequestListResponse(
          prayerRequests: [],
          total: 0,
          page: 1,
          pageSize: 20,
          totalPages: 0,
        ));
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch worker prayer requests: $e');
    }
  }

  // Get prayer requests by team
  Future<ApiResult<PrayerRequestListResponse>> getTeamPrayerRequests(
    String teamId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.prayerRequestsTeam}/$teamId',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );

      final listResponse = PrayerRequestListResponse.fromJson(response.data);
      return ApiResult.success(listResponse);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ApiResult.success(const PrayerRequestListResponse(
          prayerRequests: [],
          total: 0,
          page: 1,
          pageSize: 20,
          totalPages: 0,
        ));
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch team prayer requests: $e');
    }
  }

  // Get prayer requests by territory
  Future<ApiResult<PrayerRequestListResponse>> getTerritoryPrayerRequests(
    String territoryId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.prayerRequestsTerritory}/$territoryId',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );

      final listResponse = PrayerRequestListResponse.fromJson(response.data);
      return ApiResult.success(listResponse);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ApiResult.success(const PrayerRequestListResponse(
          prayerRequests: [],
          total: 0,
          page: 1,
          pageSize: 20,
          totalPages: 0,
        ));
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch territory prayer requests: $e');
    }
  }

  // Update prayer request status
  Future<ApiResult<bool>> updateStatus(
    String id, {
    required String status,
    String? completionNotes,
  }) async {
    try {
      await _apiClient.dio.put(
        '${ApiConstants.prayerRequests}/$id/status',
        data: UpdatePrayerStatusRequest(
          status: status,
          completionNotes: completionNotes,
        ).toJson(),
      );
      return const ApiResult.success(true);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to update status: $e');
    }
  }

  // Assign preacher to home visit
  Future<ApiResult<bool>> assignPreacher(
    String id, {
    required String preacherId,
    String? scheduledAt,
    String? notes,
  }) async {
    try {
      await _apiClient.dio.put(
        '${ApiConstants.prayerRequests}/$id/assign-preacher',
        data: AssignPreacherRequest(
          preacherId: preacherId,
          scheduledAt: scheduledAt,
          notes: notes,
        ).toJson(),
      );
      return const ApiResult.success(true);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to assign preacher: $e');
    }
  }

  // Complete prayer request
  Future<ApiResult<bool>> completePrayerRequest(
    String id, {
    String? notes,
  }) async {
    try {
      await _apiClient.dio.put(
        '${ApiConstants.prayerRequests}/$id/complete',
        data: notes != null ? {'notes': notes} : {},
      );
      return const ApiResult.success(true);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to complete prayer request: $e');
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

        if (data is Map && data['error'] != null) {
          return data['error'];
        }
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
