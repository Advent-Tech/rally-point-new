// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'survey_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SurveyModel _$SurveyModelFromJson(Map<String, dynamic> json) => SurveyModel(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  teamId: json['team_id'] as String?,
  teamName: json['team_name'] as String?,
  creatorId: json['creator_id'] as String,
  requiresLocation: json['requires_location'] as bool? ?? false,
  isActive: json['is_active'] as bool? ?? true,
  startDate: json['start_date'] == null
      ? null
      : DateTime.parse(json['start_date'] as String),
  endDate: json['end_date'] == null
      ? null
      : DateTime.parse(json['end_date'] as String),
  responseCount: (json['response_count'] as num?)?.toInt() ?? 0,
  questions: (json['questions'] as List<dynamic>?)
      ?.map((e) => SurveyQuestion.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$SurveyModelToJson(SurveyModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'team_id': instance.teamId,
      'team_name': instance.teamName,
      'creator_id': instance.creatorId,
      'requires_location': instance.requiresLocation,
      'is_active': instance.isActive,
      'start_date': instance.startDate?.toIso8601String(),
      'end_date': instance.endDate?.toIso8601String(),
      'response_count': instance.responseCount,
      'questions': instance.questions,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

SurveyQuestion _$SurveyQuestionFromJson(Map<String, dynamic> json) =>
    SurveyQuestion(
      id: json['id'] as String,
      surveyId: json['survey_id'] as String,
      questionText: json['question_text'] as String,
      questionType: json['question_type'] as String,
      placeholder: json['placeholder'] as String?,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      validation: json['validation'] as Map<String, dynamic>?,
      isRequired: json['is_required'] as bool? ?? false,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SurveyQuestionToJson(SurveyQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'survey_id': instance.surveyId,
      'question_text': instance.questionText,
      'question_type': instance.questionType,
      'placeholder': instance.placeholder,
      'options': instance.options,
      'validation': instance.validation,
      'is_required': instance.isRequired,
      'order_index': instance.orderIndex,
    };

SurveyResponse _$SurveyResponseFromJson(Map<String, dynamic> json) =>
    SurveyResponse(
      id: json['id'] as String,
      surveyId: json['survey_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      answers: (json['answers'] as List<dynamic>?)
          ?.map((e) => SurveyAnswer.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SurveyResponseToJson(SurveyResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'survey_id': instance.surveyId,
      'user_id': instance.userId,
      'user_name': instance.userName,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'answers': instance.answers,
      'created_at': instance.createdAt?.toIso8601String(),
    };

SurveyAnswer _$SurveyAnswerFromJson(Map<String, dynamic> json) => SurveyAnswer(
  id: json['id'] as String,
  responseId: json['response_id'] as String,
  questionId: json['question_id'] as String,
  answer: json['answer'] as String?,
  selectedOptions: (json['selected_options'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  photoUrls: (json['photo_urls'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  signatureUrl: json['signature_url'] as String?,
);

Map<String, dynamic> _$SurveyAnswerToJson(SurveyAnswer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'response_id': instance.responseId,
      'question_id': instance.questionId,
      'answer': instance.answer,
      'selected_options': instance.selectedOptions,
      'photo_urls': instance.photoUrls,
      'signature_url': instance.signatureUrl,
    };

SurveyAnalytics _$SurveyAnalyticsFromJson(Map<String, dynamic> json) =>
    SurveyAnalytics(
      surveyId: json['survey_id'] as String,
      totalResponses: (json['total_responses'] as num?)?.toInt() ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0,
      questionAnalytics: (json['question_analytics'] as List<dynamic>?)
          ?.map((e) => QuestionAnalytics.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SurveyAnalyticsToJson(SurveyAnalytics instance) =>
    <String, dynamic>{
      'survey_id': instance.surveyId,
      'total_responses': instance.totalResponses,
      'completion_rate': instance.completionRate,
      'question_analytics': instance.questionAnalytics,
    };

QuestionAnalytics _$QuestionAnalyticsFromJson(Map<String, dynamic> json) =>
    QuestionAnalytics(
      questionId: json['question_id'] as String,
      questionText: json['question_text'] as String,
      responseCount: (json['response_count'] as num?)?.toInt() ?? 0,
      optionCounts: (json['option_counts'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ),
    );

Map<String, dynamic> _$QuestionAnalyticsToJson(QuestionAnalytics instance) =>
    <String, dynamic>{
      'question_id': instance.questionId,
      'question_text': instance.questionText,
      'response_count': instance.responseCount,
      'option_counts': instance.optionCounts,
    };
