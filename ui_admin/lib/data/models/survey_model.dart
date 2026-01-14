import 'package:json_annotation/json_annotation.dart';

part 'survey_model.g.dart';

@JsonSerializable()
class SurveyModel {
  final String id;
  final String title;
  final String? description;
  @JsonKey(name: 'team_id')
  final String? teamId;
  @JsonKey(name: 'team_name')
  final String? teamName;
  @JsonKey(name: 'creator_id')
  final String creatorId;
  @JsonKey(name: 'requires_location')
  final bool requiresLocation;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'start_date')
  final DateTime? startDate;
  @JsonKey(name: 'end_date')
  final DateTime? endDate;
  @JsonKey(name: 'response_count')
  final int responseCount;
  final List<SurveyQuestion>? questions;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const SurveyModel({
    required this.id,
    required this.title,
    this.description,
    this.teamId,
    this.teamName,
    required this.creatorId,
    this.requiresLocation = false,
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.responseCount = 0,
    this.questions,
    this.createdAt,
    this.updatedAt,
  });

  factory SurveyModel.fromJson(Map<String, dynamic> json) {
    // Handle nested format {"survey": {...}, "questions": [...]}
    if (json.containsKey('survey')) {
      final surveyData = json['survey'] as Map<String, dynamic>;
      final questions = json['questions'] as List?;
      return SurveyModel(
        id: surveyData['id'] as String,
        title: surveyData['title'] as String,
        description: surveyData['description'] as String?,
        teamId: surveyData['team_id'] as String?,
        teamName: surveyData['team_name'] as String?,
        creatorId: surveyData['creator_id'] as String,
        requiresLocation: surveyData['requires_location'] as bool? ?? false,
        isActive: surveyData['is_active'] as bool? ?? true,
        startDate: surveyData['start_date'] != null
            ? DateTime.parse(surveyData['start_date'] as String)
            : null,
        endDate: surveyData['end_date'] != null
            ? DateTime.parse(surveyData['end_date'] as String)
            : null,
        responseCount: surveyData['response_count'] as int? ?? 0,
        questions: questions?.map((q) => SurveyQuestion.fromJson(q as Map<String, dynamic>)).toList(),
        createdAt: surveyData['created_at'] != null
            ? DateTime.parse(surveyData['created_at'] as String)
            : null,
        updatedAt: surveyData['updated_at'] != null
            ? DateTime.parse(surveyData['updated_at'] as String)
            : null,
      );
    }
    // Handle flat format
    return _$SurveyModelFromJson(json);
  }
  Map<String, dynamic> toJson() => _$SurveyModelToJson(this);
}

@JsonSerializable()
class SurveyQuestion {
  final String id;
  @JsonKey(name: 'survey_id')
  final String surveyId;
  @JsonKey(name: 'question_text')
  final String questionText;
  @JsonKey(name: 'question_type')
  final String questionType;
  final String? placeholder;
  final List<String>? options;
  final Map<String, dynamic>? validation;
  @JsonKey(name: 'is_required')
  final bool isRequired;
  @JsonKey(name: 'order_index')
  final int orderIndex;

  const SurveyQuestion({
    required this.id,
    required this.surveyId,
    required this.questionText,
    required this.questionType,
    this.placeholder,
    this.options,
    this.validation,
    this.isRequired = false,
    this.orderIndex = 0,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) => _$SurveyQuestionFromJson(json);
  Map<String, dynamic> toJson() => _$SurveyQuestionToJson(this);
}

@JsonSerializable()
class SurveyResponse {
  final String id;
  @JsonKey(name: 'survey_id')
  final String surveyId;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'user_name')
  final String? userName;
  final double? latitude;
  final double? longitude;
  final List<SurveyAnswer>? answers;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const SurveyResponse({
    required this.id,
    required this.surveyId,
    required this.userId,
    this.userName,
    this.latitude,
    this.longitude,
    this.answers,
    this.createdAt,
  });

  factory SurveyResponse.fromJson(Map<String, dynamic> json) => _$SurveyResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SurveyResponseToJson(this);
}

@JsonSerializable()
class SurveyAnswer {
  final String id;
  @JsonKey(name: 'response_id')
  final String responseId;
  @JsonKey(name: 'question_id')
  final String questionId;
  final String? answer;
  @JsonKey(name: 'selected_options')
  final List<String>? selectedOptions;
  @JsonKey(name: 'photo_urls')
  final List<String>? photoUrls;
  @JsonKey(name: 'signature_url')
  final String? signatureUrl;

  const SurveyAnswer({
    required this.id,
    required this.responseId,
    required this.questionId,
    this.answer,
    this.selectedOptions,
    this.photoUrls,
    this.signatureUrl,
  });

  factory SurveyAnswer.fromJson(Map<String, dynamic> json) => _$SurveyAnswerFromJson(json);
  Map<String, dynamic> toJson() => _$SurveyAnswerToJson(this);

  /// Get display value for the answer
  String get displayValue {
    if (selectedOptions != null && selectedOptions!.isNotEmpty) {
      return selectedOptions!.join(', ');
    }
    return answer ?? '';
  }
}

@JsonSerializable()
class SurveyAnalytics {
  @JsonKey(name: 'survey_id')
  final String surveyId;
  @JsonKey(name: 'total_responses')
  final int totalResponses;
  @JsonKey(name: 'completion_rate')
  final double completionRate;
  @JsonKey(name: 'question_analytics')
  final List<QuestionAnalytics>? questionAnalytics;

  const SurveyAnalytics({
    required this.surveyId,
    this.totalResponses = 0,
    this.completionRate = 0,
    this.questionAnalytics,
  });

  factory SurveyAnalytics.fromJson(Map<String, dynamic> json) => _$SurveyAnalyticsFromJson(json);
  Map<String, dynamic> toJson() => _$SurveyAnalyticsToJson(this);
}

@JsonSerializable()
class QuestionAnalytics {
  @JsonKey(name: 'question_id')
  final String questionId;
  @JsonKey(name: 'question_text')
  final String questionText;
  @JsonKey(name: 'response_count')
  final int responseCount;
  @JsonKey(name: 'option_counts')
  final Map<String, int>? optionCounts;

  const QuestionAnalytics({
    required this.questionId,
    required this.questionText,
    this.responseCount = 0,
    this.optionCounts,
  });

  factory QuestionAnalytics.fromJson(Map<String, dynamic> json) =>
      _$QuestionAnalyticsFromJson(json);
  Map<String, dynamic> toJson() => _$QuestionAnalyticsToJson(this);
}
