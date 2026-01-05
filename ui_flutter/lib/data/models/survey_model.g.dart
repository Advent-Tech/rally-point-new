// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'survey_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SurveyModel _$SurveyModelFromJson(Map<String, dynamic> json) => SurveyModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      responseCount: (json['response_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      requiresLocation: json['requires_location'] as bool? ?? true,
      startDate: json['start_date'] == null
          ? null
          : DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      questions: (json['questions'] as List<dynamic>?)
          ?.map((e) => SurveyQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SurveyModelToJson(SurveyModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'status': instance.status,
      'question_count': instance.questionCount,
      'response_count': instance.responseCount,
      'is_active': instance.isActive,
      'requires_location': instance.requiresLocation,
      'start_date': instance.startDate?.toIso8601String(),
      'end_date': instance.endDate?.toIso8601String(),
      'created_by': instance.createdBy,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'questions': instance.questions,
    };

SurveyQuestion _$SurveyQuestionFromJson(Map<String, dynamic> json) =>
    SurveyQuestion(
      id: json['id'] as String,
      surveyId: json['survey_id'] as String,
      text: json['question_text'] as String,
      questionType: json['question_type'] as String,
      placeholder: json['placeholder'] as String?,
      isRequired: json['is_required'] as bool? ?? false,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      options:
          (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      validation: json['validation'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$SurveyQuestionToJson(SurveyQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'survey_id': instance.surveyId,
      'question_text': instance.text,
      'question_type': instance.questionType,
      'placeholder': instance.placeholder,
      'is_required': instance.isRequired,
      'order_index': instance.orderIndex,
      'options': instance.options,
      'validation': instance.validation,
    };

SurveyResponse _$SurveyResponseFromJson(Map<String, dynamic> json) =>
    SurveyResponse(
      id: json['id'] as String,
      surveyId: json['survey_id'] as String,
      respondentId: json['respondent_id'] as String?,
      territoryId: json['territory_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      answers: (json['answers'] as List<dynamic>?)
          ?.map((e) => SurveyAnswer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SurveyResponseToJson(SurveyResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'survey_id': instance.surveyId,
      'respondent_id': instance.respondentId,
      'territory_id': instance.territoryId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'completed_at': instance.completedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'answers': instance.answers,
    };

SurveyAnswer _$SurveyAnswerFromJson(Map<String, dynamic> json) => SurveyAnswer(
      id: json['id'] as String,
      responseId: json['response_id'] as String,
      questionId: json['question_id'] as String,
      value: json['answer'] as String?,
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
      'answer': instance.value,
      'selected_options': instance.selectedOptions,
      'photo_urls': instance.photoUrls,
      'signature_url': instance.signatureUrl,
    };

SubmitSurveyRequest _$SubmitSurveyRequestFromJson(Map<String, dynamic> json) =>
    SubmitSurveyRequest(
      surveyId: json['survey_id'] as String,
      territoryId: json['territory_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      answers: (json['answers'] as List<dynamic>)
          .map((e) => AnswerInput.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SubmitSurveyRequestToJson(
        SubmitSurveyRequest instance) =>
    <String, dynamic>{
      'survey_id': instance.surveyId,
      'territory_id': instance.territoryId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'answers': instance.answers,
    };

AnswerInput _$AnswerInputFromJson(Map<String, dynamic> json) => AnswerInput(
      questionId: json['question_id'] as String,
      value: json['answer'] as String?,
      selectedOptions: (json['selected_options'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      photoUrls: (json['photo_urls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      signatureUrl: json['signature_url'] as String?,
    );

Map<String, dynamic> _$AnswerInputToJson(AnswerInput instance) =>
    <String, dynamic>{
      'question_id': instance.questionId,
      'answer': instance.value,
      'selected_options': instance.selectedOptions,
      'photo_urls': instance.photoUrls,
      'signature_url': instance.signatureUrl,
    };

CreateSurveyRequest _$CreateSurveyRequestFromJson(Map<String, dynamic> json) =>
    CreateSurveyRequest(
      title: json['title'] as String,
      description: json['description'] as String?,
      teamId: json['team_id'] as String,
      requiresLocation: json['requires_location'] as bool? ?? true,
      startDate: json['start_date'] == null
          ? null
          : DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      questions: (json['questions'] as List<dynamic>)
          .map((e) => CreateQuestionRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CreateSurveyRequestToJson(
        CreateSurveyRequest instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'team_id': instance.teamId,
      'requires_location': instance.requiresLocation,
      'start_date': instance.startDate?.toIso8601String(),
      'end_date': instance.endDate?.toIso8601String(),
      'questions': instance.questions,
    };

CreateQuestionRequest _$CreateQuestionRequestFromJson(
        Map<String, dynamic> json) =>
    CreateQuestionRequest(
      text: json['question_text'] as String,
      questionType: json['question_type'] as String,
      placeholder: json['placeholder'] as String?,
      isRequired: json['is_required'] as bool? ?? false,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      options:
          (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      validation: json['validation'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$CreateQuestionRequestToJson(
        CreateQuestionRequest instance) =>
    <String, dynamic>{
      'question_text': instance.text,
      'question_type': instance.questionType,
      'placeholder': instance.placeholder,
      'is_required': instance.isRequired,
      'order_index': instance.orderIndex,
      'options': instance.options,
      'validation': instance.validation,
    };
