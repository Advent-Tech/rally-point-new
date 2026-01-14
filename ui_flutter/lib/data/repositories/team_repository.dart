import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../models/team_model.dart';

class TeamRepository {
  final ApiClient _apiClient;

  TeamRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // Get user's teams
  Future<ApiResult<List<TeamModel>>> getMyTeams() async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.myTeams);

      final List<dynamic> data = response.data['teams'] ?? response.data;
      final teams = data.map((e) => TeamModel.fromJson(e)).toList();

      return ApiResult.success(teams);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch teams: $e');
    }
  }

  // Get team by ID
  Future<ApiResult<TeamModel>> getTeamById(String teamId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.teams}/$teamId',
      );

      final team = TeamModel.fromJson(response.data);
      return ApiResult.success(team);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch team: $e');
    }
  }

  // Create team
  Future<ApiResult<TeamModel>> createTeam(CreateTeamRequest request) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.teams,
        data: request.toJson(),
      );

      final team = TeamModel.fromJson(response.data);
      return ApiResult.success(team);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to create team: $e');
    }
  }

  // Update team
  Future<ApiResult<TeamModel>> updateTeam({
    required String teamId,
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (avatarUrl != null) data['avatarUrl'] = avatarUrl;

      final response = await _apiClient.dio.put(
        '${ApiConstants.teams}/$teamId',
        data: data,
      );

      final team = TeamModel.fromJson(response.data);
      return ApiResult.success(team);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to update team: $e');
    }
  }

  // Delete team
  Future<ApiResult<void>> deleteTeam(String teamId) async {
    try {
      await _apiClient.dio.delete('${ApiConstants.teams}/$teamId');
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to delete team: $e');
    }
  }

  // Join team
  Future<ApiResult<TeamMember>> joinTeam(JoinTeamRequest request) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiConstants.teams}/${request.teamId}/join',
        data: request.toJson(),
      );

      final member = TeamMember.fromJson(response.data);
      return ApiResult.success(member);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to join team: $e');
    }
  }

  // Leave team
  Future<ApiResult<void>> leaveTeam(String teamId) async {
    try {
      await _apiClient.dio.post('${ApiConstants.teams}/$teamId/leave');
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to leave team: $e');
    }
  }

  // Get team members (workers)
  Future<ApiResult<List<TeamMember>>> getTeamMembers(String teamId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.teams}/$teamId/workers',
      );

      // Backend returns array of User objects directly
      final List<dynamic> data = response.data is List
          ? response.data
          : (response.data['workers'] ?? response.data['members'] ?? []);

      // Use fromUserJson since backend returns User objects, not TeamMember
      final members = data.map((e) => TeamMember.fromUserJson(e as Map<String, dynamic>)).toList();

      return ApiResult.success(members);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch team members: $e');
    }
  }

  // Add member to team
  Future<ApiResult<TeamMember>> addMember({
    required String teamId,
    required String userId,
    String role = 'member',
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiConstants.teams}/$teamId/members',
        data: {
          'userId': userId,
          'role': role,
        },
      );

      final member = TeamMember.fromJson(response.data);
      return ApiResult.success(member);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to add member: $e');
    }
  }

  // Remove member from team
  Future<ApiResult<void>> removeMember({
    required String teamId,
    required String userId,
  }) async {
    try {
      await _apiClient.dio.delete(
        '${ApiConstants.teams}/$teamId/members/$userId',
      );
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to remove member: $e');
    }
  }

  // Update member role
  Future<ApiResult<TeamMember>> updateMemberRole({
    required String teamId,
    required String userId,
    required String role,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        '${ApiConstants.teams}/$teamId/members/$userId',
        data: {'role': role},
      );

      final member = TeamMember.fromJson(response.data);
      return ApiResult.success(member);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to update member role: $e');
    }
  }

  // Search teams
  Future<ApiResult<List<TeamModel>>> searchTeams({
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (query != null) queryParams['q'] = query;

      final response = await _apiClient.dio.get(
        ApiConstants.teamsSearch,
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data['teams'] ?? response.data;
      final teams = data.map((e) => TeamModel.fromJson(e)).toList();

      return ApiResult.success(teams);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to search teams: $e');
    }
  }

  // ============ Join Request Methods (for multi-role system) ============

  /// Get pending join requests for a team (team leader only)
  Future<ApiResult<List<TeamJoinRequest>>> getJoinRequests(String teamId, {String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;

      final response = await _apiClient.dio.get(
        '${ApiConstants.teams}/$teamId/join-requests',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final List<dynamic> data = response.data is List
          ? response.data
          : (response.data['requests'] ?? response.data['join_requests'] ?? []);

      final requests = data.map((e) => TeamJoinRequest.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResult.success(requests);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const ApiResult.success([]);
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch join requests: $e');
    }
  }

  /// Approve a join request (team leader only)
  Future<ApiResult<void>> approveJoinRequest(String requestId) async {
    try {
      await _apiClient.dio.put(
        '${ApiConstants.approveJoinRequest}/$requestId/approve',
      );
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to approve join request: $e');
    }
  }

  /// Reject a join request (team leader only)
  Future<ApiResult<void>> rejectJoinRequest(String requestId, {String? reason}) async {
    try {
      await _apiClient.dio.put(
        '${ApiConstants.rejectJoinRequest}/$requestId/reject',
        data: reason != null ? {'rejection_reason': reason} : null,
      );
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to reject join request: $e');
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
