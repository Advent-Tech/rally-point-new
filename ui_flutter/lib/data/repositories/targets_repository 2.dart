import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../models/target_models.dart';

class TargetsRepository {
  ApiClient? _apiClient;

  TargetsRepository();

  Future<ApiClient> get apiClient async {
    _apiClient ??= await ApiClient.getInstance();
    return _apiClient!;
  }

  Future<ApiResult<List<TargetDefinition>>> getLeaderTargetTemplates() async {
    try {
      final client = await apiClient;
      final response = await client.dio.get('/api/teams/targets');

      final raw = response.data;
      final List<dynamic> list = raw is List
          ? raw
          : (raw['data'] ?? raw['targets'] ?? []);
      final targets = list
          .whereType<Map>()
          .map((e) => TargetDefinition.fromJson(e.cast<String, dynamic>()))
          .toList();

      return ApiResult.success(targets);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to load target templates: $e');
    }
  }

  Future<ApiResult<List<AssignedTargetWithProgress>>> getLeaderAssignedTargets({
    String? teamId,
  }) async {
    try {
      final client = await apiClient;
      final response = await client.dio.get(
        '/api/teams/targets/assigned',
        queryParameters: {
          if (teamId != null && teamId.isNotEmpty) 'team_id': teamId,
        },
      );

      final raw = response.data;
      final List<dynamic> list = raw is List
          ? raw
          : (raw['data'] ?? raw['targets'] ?? []);
      final targets = list
          .whereType<Map>()
          .map(
            (e) =>
                AssignedTargetWithProgress.fromJson(e.cast<String, dynamic>()),
          )
          .toList();

      return ApiResult.success(targets);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to load assigned targets: $e');
    }
  }

  Future<ApiResult<TargetDefinition>> createTargetTemplate({
    required String name,
    required String description,
    required String targetType,
    required String targetUnit,
    required double targetValue,
    required String periodType,
  }) async {
    try {
      final client = await apiClient;
      final response = await client.dio.post(
        '/api/teams/targets',
        data: {
          'name': name,
          'description': description,
          'target_type': targetType,
          'target_unit': targetUnit,
          'target_value': targetValue,
          'period_type': periodType,
        },
      );

      final data = response.data is Map
          ? (response.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      return ApiResult.success(TargetDefinition.fromJson(data));
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to create target: $e');
    }
  }

  Future<ApiResult<void>> updateTargetTemplate({
    required String targetId,
    required String name,
    required String description,
    required String targetType,
    required String targetUnit,
    required double targetValue,
    required String periodType,
  }) async {
    try {
      final client = await apiClient;
      await client.dio.put(
        '/api/teams/targets/$targetId',
        data: {
          'name': name,
          'description': description,
          'target_type': targetType,
          'target_unit': targetUnit,
          'target_value': targetValue,
          'period_type': periodType,
        },
      );
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to update target: $e');
    }
  }

  Future<ApiResult<void>> deleteTargetTemplate(String targetId) async {
    try {
      final client = await apiClient;
      await client.dio.delete('/api/teams/targets/$targetId');
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to delete target: $e');
    }
  }

  Future<ApiResult<void>> assignTargetToTeam({
    required String targetId,
    required String teamId,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    try {
      final client = await apiClient;
      await client.dio.post(
        '/api/teams/targets/$targetId/assign-team',
        data: {
          'team_id': teamId,
          if (periodStart != null)
            'period_start': periodStart.toIso8601String(),
          if (periodEnd != null) 'period_end': periodEnd.toIso8601String(),
        },
      );
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to assign to team: $e');
    }
  }

  Future<ApiResult<void>> assignTargetToWorker({
    required String targetId,
    required String workerId,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    try {
      final client = await apiClient;
      await client.dio.post(
        '/api/teams/targets/$targetId/assign-worker',
        data: {
          'worker_id': workerId,
          if (periodStart != null)
            'period_start': periodStart.toIso8601String(),
          if (periodEnd != null) 'period_end': periodEnd.toIso8601String(),
        },
      );
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to assign to worker: $e');
    }
  }

  Future<ApiResult<void>> deleteAssignment(String assignmentId) async {
    try {
      final client = await apiClient;
      await client.dio.delete('/api/teams/assignments/$assignmentId');
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to delete assignment: $e');
    }
  }

  Future<ApiResult<String?>> getLeaderTeamId(String leaderId) async {
    try {
      final client = await apiClient;
      final response = await client.dio.get('/api/teams?leader_id=$leaderId');

      final raw = response.data;
      final List<dynamic> teams = raw is List
          ? raw
          : (raw['teams'] ?? raw['data'] ?? []);
      if (teams.isEmpty) return const ApiResult.success(null);

      final first = teams.first;
      if (first is Map) {
        return ApiResult.success(first['id']?.toString());
      }
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to resolve team id: $e');
    }
  }

  /// Best-effort worker list for assignment UI.
  ///
  /// The backend team-members endpoint is team-scoped; in the Flutter app
  /// there are older routes like `/api/teams/my/workers`. We try a couple
  /// options so the UI can function without additional backend work.
  Future<ApiResult<List<TeamMemberLite>>> getAssignableWorkers({
    String? teamId,
  }) async {
    try {
      final client = await apiClient;

      Response<dynamic> response;
      try {
        response = await client.dio.get('/api/teams/my/workers');
      } on DioException {
        if (teamId == null || teamId.isEmpty) rethrow;
        response = await client.dio.get('/api/teams/$teamId/workers');
      }

      final raw = response.data;
      final List<dynamic> list = raw is List
          ? raw
          : (raw['data'] ?? raw['workers'] ?? raw['members'] ?? []);
      final workers = list
          .whereType<Map>()
          .map((e) => TeamMemberLite.fromJson(e.cast<String, dynamic>()))
          .where((w) => w.id.isNotEmpty)
          .toList();

      return ApiResult.success(workers);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to load workers: $e');
    }
  }

  String _handleDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    if (data is Map && data['message'] != null)
      return data['message'].toString();

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        return 'Server error (Status: ${e.response?.statusCode})';
      case DioExceptionType.connectionError:
        return 'No internet connection';
      default:
        return 'An unexpected error occurred';
    }
  }
}
