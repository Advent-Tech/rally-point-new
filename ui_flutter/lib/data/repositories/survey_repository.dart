import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../models/survey_model.dart';

class SurveyRepository {
  final ApiClient _apiClient;

  SurveyRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // Get available surveys for the current worker (assigned surveys)
  // Uses JWT token for user identification - backend returns assignments for authenticated user
  Future<ApiResult<List<SurveyModel>>> getAvailableSurveys() async {
    try {
      // Backend route: GET /api/users/assignments
      // Returns survey assignments for the authenticated user (from JWT token)
      final response = await _apiClient.dio.get(
        ApiConstants.userSurveyAssignments,
      );

      final List<dynamic> data = response.data is List
          ? response.data
          : (response.data['assignments'] ?? []);

      // Extract surveys from assignments
      final surveys = <SurveyModel>[];
      for (final assignment in data) {
        if (assignment['survey'] != null) {
          surveys.add(SurveyModel.fromJson(assignment['survey']));
        } else if (assignment['survey_id'] != null) {
          // If only survey_id is provided, create a placeholder that will be fetched later
          // Or try to fetch the survey details
          try {
            final surveyResult = await getSurveyById(assignment['survey_id'].toString());
            if (surveyResult is ApiSuccess<SurveyModel>) {
              surveys.add(surveyResult.data);
            }
          } catch (_) {
            // Skip if we can't fetch the survey
          }
        }
      }

      return ApiResult.success(surveys);
    } on DioException catch (e) {
      // Return empty list on 404 (no surveys assigned)
      if (e.response?.statusCode == 404) {
        return const ApiResult.success([]);
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch surveys: $e');
    }
  }

  // Get survey by ID with questions
  Future<ApiResult<SurveyModel>> getSurveyById(String id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConstants.surveys}/$id');

      final survey = SurveyModel.fromJson(response.data);
      return ApiResult.success(survey);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch survey: $e');
    }
  }

  // Get user's survey responses
  // Backend route: GET /api/users/responses
  Future<ApiResult<List<SurveyResponse>>> getMyResponses() async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.userSurveyResponses,
      );

      final List<dynamic> data = response.data is List
          ? response.data
          : (response.data['responses'] ?? []);
      final responses = data.map((e) => SurveyResponse.fromJson(e)).toList();

      return ApiResult.success(responses);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const ApiResult.success([]);
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch responses: $e');
    }
  }

  // Submit survey response
  Future<ApiResult<SurveyResponse>> submitSurvey(SubmitSurveyRequest request) async {
    try {
      // Backend endpoint is POST /api/surveys/:id/responses
      final response = await _apiClient.dio.post(
        '${ApiConstants.surveys}/${request.surveyId}/responses',
        data: request.toJson(),
      );

      final surveyResponse = SurveyResponse.fromJson(response.data);
      return ApiResult.success(surveyResponse);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to submit survey: $e');
    }
  }

  // Create a new survey (for team leaders)
  Future<ApiResult<SurveyModel>> createSurvey(CreateSurveyRequest request) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiConstants.surveys}/',
        data: request.toJson(),
      );

      final survey = SurveyModel.fromJson(response.data);
      return ApiResult.success(survey);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to create survey: $e');
    }
  }

  // Get team surveys (for team leaders)
  // Backend route: GET /api/teams/:teamId/surveys
  Future<ApiResult<List<SurveyModel>>> getTeamSurveys(String teamId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.teams}/$teamId/surveys',
      );

      final List<dynamic> data = response.data is List
          ? response.data
          : (response.data['surveys'] ?? []);
      final surveys = data.map((e) => SurveyModel.fromJson(e)).toList();

      return ApiResult.success(surveys);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const ApiResult.success([]);
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch team surveys: $e');
    }
  }

  // Get survey responses (for leaders)
  Future<ApiResult<List<SurveyResponse>>> getSurveyResponses(String surveyId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.surveys}/$surveyId/responses',
      );

      final List<dynamic> data = response.data is List
          ? response.data
          : (response.data['responses'] ?? []);
      final responses = data.map((e) => SurveyResponse.fromJson(e)).toList();

      return ApiResult.success(responses);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const ApiResult.success([]);
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to fetch survey responses: $e');
    }
  }

  // Assign survey to workers
  Future<ApiResult<bool>> assignSurvey({
    required String surveyId,
    required List<String> workerIds,
    DateTime? dueDate,
  }) async {
    try {
      await _apiClient.dio.post(
        '${ApiConstants.surveys}/$surveyId/assignments',
        data: {
          'worker_ids': workerIds,
          if (dueDate != null) 'due_date': dueDate.toIso8601String(),
        },
      );

      return const ApiResult.success(true);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Failed to assign survey: $e');
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
