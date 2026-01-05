import 'package:json_annotation/json_annotation.dart';

part 'survey_model.g.dart';

/// Question types supported by the survey system
class QuestionType {
  static const String text = 'text';
  static const String textarea = 'textarea';
  static const String number = 'number';
  static const String date = 'date';
  static const String select = 'select';
  static const String radio = 'radio';
  static const String checkbox = 'checkbox';
  static const String photo = 'photo';
  static const String signature = 'signature';
  static const String rating = 'rating';
  static const String boolean = 'boolean';

  // Legacy types
  static const String multipleChoice = 'multiple_choice';
  static const String yesNo = 'yes_no';

  static List<String> get allTypes => [
        text,
        textarea,
        number,
        date,
        select,
        radio,
        checkbox,
        photo,
        signature,
        rating,
        boolean,
      ];

  static String getDisplayName(String type) {
    switch (type) {
      case text:
        return 'Short Text';
      case textarea:
        return 'Long Text';
      case number:
        return 'Number';
      case date:
        return 'Date';
      case select:
        return 'Dropdown';
      case radio:
        return 'Single Choice';
      case checkbox:
        return 'Multiple Choice';
      case photo:
        return 'Photo';
      case signature:
        return 'Signature';
      case rating:
        return 'Rating';
      case boolean:
        return 'Yes/No';
      default:
        return type;
    }
  }
}

@JsonSerializable()
class SurveyModel {
  final String id;
  final String title;
  final String? description;
  final String status;
  @JsonKey(name: 'question_count')
  final int questionCount;
  @JsonKey(name: 'response_count')
  final int responseCount;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'requires_location')
  final bool requiresLocation;
  @JsonKey(name: 'start_date')
  final DateTime? startDate;
  @JsonKey(name: 'end_date')
  final DateTime? endDate;
  @JsonKey(name: 'created_by')
  final String? createdBy;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  final List<SurveyQuestion>? questions;

  const SurveyModel({
    required this.id,
    required this.title,
    this.description,
    this.status = 'published',
    this.questionCount = 0,
    this.responseCount = 0,
    this.isActive = true,
    this.requiresLocation = true,
    this.startDate,
    this.endDate,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.questions,
  });

  factory SurveyModel.fromJson(Map<String, dynamic> json) {
    // Handle nested response from create endpoint
    final surveyData = json.containsKey('survey') ? json['survey'] as Map<String, dynamic> : json;
    final questionsData = json['questions'] as List<dynamic>?;

    // Derive status from is_active if not provided
    String status = surveyData['status'] as String? ??
        (surveyData['is_active'] == true ? 'published' : 'draft');

    // Handle creator_id vs created_by
    String? createdBy = surveyData['created_by'] as String? ?? surveyData['creator_id'] as String?;

    return SurveyModel(
      id: surveyData['id'] as String,
      title: surveyData['title'] as String,
      description: surveyData['description'] as String?,
      status: status,
      questionCount: surveyData['question_count'] as int? ?? questionsData?.length ?? 0,
      responseCount: surveyData['response_count'] as int? ?? 0,
      isActive: surveyData['is_active'] as bool? ?? true,
      requiresLocation: surveyData['requires_location'] as bool? ?? false,
      startDate: surveyData['start_date'] != null ? DateTime.parse(surveyData['start_date'] as String) : null,
      endDate: surveyData['end_date'] != null ? DateTime.parse(surveyData['end_date'] as String) : null,
      createdBy: createdBy,
      createdAt: surveyData['created_at'] != null ? DateTime.parse(surveyData['created_at'] as String) : null,
      updatedAt: surveyData['updated_at'] != null ? DateTime.parse(surveyData['updated_at'] as String) : null,
      questions: questionsData?.map((q) => SurveyQuestion.fromJson(q as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => _$SurveyModelToJson(this);

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isClosed => status == 'closed';
}

@JsonSerializable()
class SurveyQuestion {
  final String id;
  @JsonKey(name: 'survey_id')
  final String surveyId;
  @JsonKey(name: 'question_text')
  final String text;
  @JsonKey(name: 'question_type')
  final String questionType;
  final String? placeholder;
  @JsonKey(name: 'is_required')
  final bool isRequired;
  @JsonKey(name: 'order_index')
  final int orderIndex;
  final List<String>? options;
  final Map<String, dynamic>? validation;

  const SurveyQuestion({
    required this.id,
    required this.surveyId,
    required this.text,
    required this.questionType,
    this.placeholder,
    this.isRequired = false,
    this.orderIndex = 0,
    this.options,
    this.validation,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    // Handle options as either JSON string or list
    List<String>? parsedOptions;
    if (json['options'] != null) {
      if (json['options'] is String) {
        try {
          final decoded = json['options'] as String;
          if (decoded.startsWith('[')) {
            parsedOptions = List<String>.from(
              (decoded.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(','))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty),
            );
          }
        } catch (_) {}
      } else if (json['options'] is List) {
        parsedOptions = List<String>.from(json['options']);
      }
    }

    return SurveyQuestion(
      id: json['id'] as String,
      surveyId: json['survey_id'] as String? ?? '',
      text: json['question_text'] as String? ?? json['text'] as String? ?? '',
      questionType: json['question_type'] as String,
      placeholder: json['placeholder'] as String?,
      isRequired: json['is_required'] as bool? ?? false,
      orderIndex: json['order_index'] as int? ?? json['display_order'] as int? ?? 0,
      options: parsedOptions,
      validation: json['validation'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => _$SurveyQuestionToJson(this);

  bool get isTextQuestion => questionType == QuestionType.text || questionType == QuestionType.textarea;
  bool get isChoiceQuestion => questionType == QuestionType.radio ||
      questionType == QuestionType.checkbox ||
      questionType == QuestionType.select ||
      questionType == QuestionType.multipleChoice;
  bool get isNumberQuestion => questionType == QuestionType.number;
  bool get isDateQuestion => questionType == QuestionType.date;
  bool get isPhotoQuestion => questionType == QuestionType.photo;
  bool get isSignatureQuestion => questionType == QuestionType.signature;
  bool get isRatingQuestion => questionType == QuestionType.rating;
  bool get isBooleanQuestion => questionType == QuestionType.boolean || questionType == QuestionType.yesNo;
}

@JsonSerializable()
class SurveyResponse {
  final String id;
  @JsonKey(name: 'survey_id')
  final String surveyId;
  @JsonKey(name: 'respondent_id')
  final String? respondentId;
  @JsonKey(name: 'territory_id')
  final String? territoryId;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  final List<SurveyAnswer>? answers;

  const SurveyResponse({
    required this.id,
    required this.surveyId,
    this.respondentId,
    this.territoryId,
    this.latitude,
    this.longitude,
    this.completedAt,
    this.createdAt,
    this.answers,
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
  @JsonKey(name: 'answer')
  final String? value;
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
    this.value,
    this.selectedOptions,
    this.photoUrls,
    this.signatureUrl,
  });

  factory SurveyAnswer.fromJson(Map<String, dynamic> json) => _$SurveyAnswerFromJson(json);
  Map<String, dynamic> toJson() => _$SurveyAnswerToJson(this);
}

@JsonSerializable()
class SubmitSurveyRequest {
  @JsonKey(name: 'survey_id')
  final String surveyId;
  @JsonKey(name: 'territory_id')
  final String? territoryId;
  final double? latitude;
  final double? longitude;
  final List<AnswerInput> answers;

  const SubmitSurveyRequest({
    required this.surveyId,
    this.territoryId,
    this.latitude,
    this.longitude,
    required this.answers,
  });

  factory SubmitSurveyRequest.fromJson(Map<String, dynamic> json) => _$SubmitSurveyRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SubmitSurveyRequestToJson(this);
}

@JsonSerializable()
class AnswerInput {
  @JsonKey(name: 'question_id')
  final String questionId;
  @JsonKey(name: 'answer')
  final String? value;
  @JsonKey(name: 'selected_options')
  final List<String>? selectedOptions;
  @JsonKey(name: 'photo_urls')
  final List<String>? photoUrls;
  @JsonKey(name: 'signature_url')
  final String? signatureUrl;

  const AnswerInput({
    required this.questionId,
    this.value,
    this.selectedOptions,
    this.photoUrls,
    this.signatureUrl,
  });

  factory AnswerInput.fromJson(Map<String, dynamic> json) => _$AnswerInputFromJson(json);
  Map<String, dynamic> toJson() => _$AnswerInputToJson(this);
}

@JsonSerializable()
class CreateSurveyRequest {
  final String title;
  final String? description;
  @JsonKey(name: 'team_id')
  final String teamId;
  @JsonKey(name: 'requires_location')
  final bool requiresLocation;
  @JsonKey(name: 'start_date')
  final DateTime? startDate;
  @JsonKey(name: 'end_date')
  final DateTime? endDate;
  final List<CreateQuestionRequest> questions;

  const CreateSurveyRequest({
    required this.title,
    this.description,
    required this.teamId,
    this.requiresLocation = true,
    this.startDate,
    this.endDate,
    required this.questions,
  });

  factory CreateSurveyRequest.fromJson(Map<String, dynamic> json) => _$CreateSurveyRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateSurveyRequestToJson(this);
}

@JsonSerializable()
class CreateQuestionRequest {
  @JsonKey(name: 'question_text')
  final String text;
  @JsonKey(name: 'question_type')
  final String questionType;
  final String? placeholder;
  @JsonKey(name: 'is_required')
  final bool isRequired;
  @JsonKey(name: 'order_index')
  final int orderIndex;
  final List<String>? options;
  final Map<String, dynamic>? validation;

  const CreateQuestionRequest({
    required this.text,
    required this.questionType,
    this.placeholder,
    this.isRequired = false,
    this.orderIndex = 0,
    this.options,
    this.validation,
  });

  factory CreateQuestionRequest.fromJson(Map<String, dynamic> json) => _$CreateQuestionRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateQuestionRequestToJson(this);
}
