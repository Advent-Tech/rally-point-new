part of 'survey_bloc.dart';

abstract class SurveyState extends Equatable {
  const SurveyState();

  @override
  List<Object?> get props => [];
}

class SurveyInitial extends SurveyState {}

class SurveyLoading extends SurveyState {}

class SurveyLoaded extends SurveyState {
  final List<SurveyModel> availableSurveys;
  final List<SurveyResponse> myResponses;
  final SurveyModel? currentSurvey;

  const SurveyLoaded({
    this.availableSurveys = const [],
    this.myResponses = const [],
    this.currentSurvey,
  });

  SurveyLoaded copyWith({
    List<SurveyModel>? availableSurveys,
    List<SurveyResponse>? myResponses,
    SurveyModel? currentSurvey,
  }) {
    return SurveyLoaded(
      availableSurveys: availableSurveys ?? this.availableSurveys,
      myResponses: myResponses ?? this.myResponses,
      currentSurvey: currentSurvey ?? this.currentSurvey,
    );
  }

  @override
  List<Object?> get props => [availableSurveys, myResponses, currentSurvey];
}

class SurveySubmitting extends SurveyState {}

class SurveySubmitSuccess extends SurveyState {
  final SurveyResponse response;

  const SurveySubmitSuccess({required this.response});

  @override
  List<Object?> get props => [response];
}

class SurveyError extends SurveyState {
  final String message;

  const SurveyError({required this.message});

  @override
  List<Object?> get props => [message];
}
