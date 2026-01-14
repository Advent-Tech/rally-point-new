import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

      List<dynamic> data = [];
      final responseData = response.data;

      if (responseData is List) {
        data = responseData;
      } else if (responseData is Map<String, dynamic>) {
        // Handle various nested structures
        data = responseData['responses'] as List<dynamic>? ??
            responseData['data'] as List<dynamic>? ??
            [];
      }

      final responses = <SurveyResponse>[];
      for (final item in data) {
        try {
          // Handle nested response structure if present
          if (item is Map<String, dynamic>) {
            Map<String, dynamic> responseJson;

            if (item.containsKey('response') && item['response'] is Map<String, dynamic>) {
              // Nested structure from backend
              responseJson = Map<String, dynamic>.from(item['response'] as Map<String, dynamic>);
              // Merge answers into response for parsing
              if (item.containsKey('answers') && item['answers'] != null) {
                responseJson['answers'] = item['answers'];
              }
            } else {
              // Flat structure
              responseJson = item;
            }

            responses.add(SurveyResponse.fromJson(responseJson));
          }
        } catch (e) {
          debugPrint('Error parsing response item: $e');
        }
      }

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

      // Handle nested response structure from backend
      // API returns: {"response": {...}, "answers": [...]}
      final responseData = response.data;
      Map<String, dynamic> surveyResponseData;

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('response')) {
          // Nested structure - extract the response object
          surveyResponseData = responseData['response'] as Map<String, dynamic>;
          // Merge answers if provided separately
          if (responseData.containsKey('answers')) {
            surveyResponseData['answers'] = responseData['answers'];
          }
        } else {
          // Flat structure - use as is
          surveyResponseData = responseData;
        }
      } else {
        return ApiResult.failure('Invalid response format');
      }

      final surveyResponse = SurveyResponse.fromJson(surveyResponseData);
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

  // Get all surveys (for team leaders to see admin-created surveys)
  // Backend route: GET /api/surveys
  Future<ApiResult<List<SurveyModel>>> getAllSurveys() async {
    try {
      debugPrint('SurveyRepository: Fetching all surveys from /api/surveys');
      final response = await _apiClient.dio.get(ApiConstants.surveys);

      debugPrint('SurveyRepository: Response data type: ${response.data.runtimeType}');

      List<dynamic> data = [];
      if (response.data is List) {
        data = response.data;
      } else if (response.data is Map<String, dynamic>) {
        data = response.data['surveys'] ?? [];
      }

      debugPrint('SurveyRepository: Found ${data.length} surveys');

      final surveys = <SurveyModel>[];
      for (final item in data) {
        try {
          surveys.add(SurveyModel.fromJson(item));
        } catch (e) {
          debugPrint('SurveyRepository: Error parsing survey: $e');
        }
      }

      return ApiResult.success(surveys);
    } on DioException catch (e) {
      debugPrint('SurveyRepository: DioError fetching all surveys: ${e.message}');
      if (e.response?.statusCode == 404) {
        return const ApiResult.success([]);
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      debugPrint('SurveyRepository: Exception fetching all surveys: $e');
      return ApiResult.failure('Failed to fetch surveys: $e');
    }
  }

  // Get team surveys (for team leaders) - legacy endpoint
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
      debugPrint('SurveyRepository: Fetching responses for survey $surveyId');
      final response = await _apiClient.dio.get(
        '${ApiConstants.surveys}/$surveyId/responses',
      );

      debugPrint('SurveyRepository: Response data: ${response.data}');

      final List<dynamic> data = response.data is List
          ? response.data
          : (response.data['responses'] ?? []);

      debugPrint('SurveyRepository: Found ${data.length} response items');

      final responses = <SurveyResponse>[];
      for (final item in data) {
        try {
          // Handle nested structure: { "response": {...}, "answers": [...] }
          if (item is Map<String, dynamic>) {
            Map<String, dynamic> responseJson;

            if (item.containsKey('response') && item['response'] is Map<String, dynamic>) {
              // Nested structure from backend
              responseJson = Map<String, dynamic>.from(item['response'] as Map<String, dynamic>);
              // Merge answers into response for parsing
              if (item.containsKey('answers') && item['answers'] != null) {
                responseJson['answers'] = item['answers'];
              }
              debugPrint('SurveyRepository: Parsing nested response with ${(item['answers'] as List?)?.length ?? 0} answers');
            } else {
              // Flat structure
              responseJson = item;
              debugPrint('SurveyRepository: Parsing flat response');
            }

            responses.add(SurveyResponse.fromJson(responseJson));
          }
        } catch (e) {
          debugPrint('SurveyRepository: Error parsing response item: $e');
        }
      }

      debugPrint('SurveyRepository: Successfully parsed ${responses.length} responses');
      return ApiResult.success(responses);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const ApiResult.success([]);
      }
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      debugPrint('SurveyRepository: Error fetching responses: $e');
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
