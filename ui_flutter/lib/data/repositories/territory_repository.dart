import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../models/territory_model.dart';

class TerritoryRepository {
  final ApiClient _apiClient;

  TerritoryRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // Get territories near a location
  Future<ApiResult<List<GeoTerritory>>> getTerritoriesNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.territoriesNearby,
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'radius': radiusKm,
          'limit': limit,
        },
      );

      final List<dynamic> data = response.data['territories'] ?? response.data;
      final territories = data.map((e) => GeoTerritory.fromJson(e)).toList();

      return ApiResult.success(territories);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch territories: $e');
    }
  }

  // Get territory by ID
  Future<ApiResult<GeoTerritory>> getTerritoryById(String id) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.territories}/$id',
      );

      final territory = GeoTerritory.fromJson(response.data);
      return ApiResult.success(territory);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch territory: $e');
    }
  }

  // Get union statistics
  Future<ApiResult<List<UnionStats>>> getUnionStats({
    String? district,
    String? upazila,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (district != null) queryParams['district'] = district;
      if (upazila != null) queryParams['upazila'] = upazila;

      final response = await _apiClient.dio.get(
        ApiConstants.unionStats,
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data['stats'] ?? response.data;
      final stats = data.map((e) => UnionStats.fromJson(e)).toList();

      return ApiResult.success(stats);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch union stats: $e');
    }
  }

  // Get territory assignments for user
  // Backend requires either team_id or worker_id as query parameter
  Future<ApiResult<List<TerritoryAssignment>>> getMyAssignments({
    String? teamId,
    String? workerId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (teamId != null) queryParams['team_id'] = teamId;
      if (workerId != null) queryParams['worker_id'] = workerId;

      final response = await _apiClient.dio.get(
        ApiConstants.myAssignments,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final List<dynamic> data = response.data['assignments'] ?? response.data;
      final assignments =
          data.map((e) => TerritoryAssignment.fromJson(e)).toList();

      return ApiResult.success(assignments);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch assignments: $e');
    }
  }

  // Request territory assignment
  Future<ApiResult<TerritoryAssignment>> requestTerritory({
    required String territoryId,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.requestTerritory,
        data: {
          'territoryId': territoryId,
          if (notes != null) 'notes': notes,
        },
      );

      final assignment = TerritoryAssignment.fromJson(response.data);
      return ApiResult.success(assignment);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to request territory: $e');
    }
  }

  // Complete territory assignment
  Future<ApiResult<TerritoryAssignment>> completeAssignment({
    required String assignmentId,
    String? notes,
    int? householdsVisited,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        '${ApiConstants.assignments}/$assignmentId/complete',
        data: {
          if (notes != null) 'notes': notes,
          if (householdsVisited != null) 'householdsVisited': householdsVisited,
        },
      );

      final assignment = TerritoryAssignment.fromJson(response.data);
      return ApiResult.success(assignment);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to complete assignment: $e');
    }
  }

  // Search territories
  Future<ApiResult<List<GeoTerritory>>> searchTerritories({
    String? query,
    String? district,
    String? upazila,
    String? unionName,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (query != null) queryParams['q'] = query;
      if (district != null) queryParams['district'] = district;
      if (upazila != null) queryParams['upazila'] = upazila;
      if (unionName != null) queryParams['union'] = unionName;

      final response = await _apiClient.dio.get(
        ApiConstants.territoriesSearch,
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data['territories'] ?? response.data;
      final territories = data.map((e) => GeoTerritory.fromJson(e)).toList();

      return ApiResult.success(territories);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to search territories: $e');
    }
  }

  // Get church locations
  Future<ApiResult<List<ChurchLocation>>> getChurchLocations({
    double? latitude,
    double? longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'radius': radiusKm,
      };
      if (latitude != null) queryParams['lat'] = latitude;
      if (longitude != null) queryParams['lng'] = longitude;

      final response = await _apiClient.dio.get(
        ApiConstants.churchLocations,
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data['locations'] ?? response.data;
      final locations = data.map((e) => ChurchLocation.fromJson(e)).toList();

      return ApiResult.success(locations);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch church locations: $e');
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
