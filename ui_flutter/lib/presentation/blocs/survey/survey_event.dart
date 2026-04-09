part of 'survey_bloc.dart';

abstract class SurveyEvent extends Equatable {
  const SurveyEvent();

  @override
  List<Object?> get props => [];
}

class SurveyLoadAvailable extends SurveyEvent {
  const SurveyLoadAvailable();
}

class SurveyLoadResponses extends SurveyEvent {
  const SurveyLoadResponses();
}

class SurveyLoadDetails extends SurveyEvent {
  final String surveyId;

  const SurveyLoadDetails({required this.surveyId});

  @override
  List<Object?> get props => [surveyId];
}

class SurveySubmit extends SurveyEvent {
  final String surveyId;
  final String? territoryId;
  final double? latitude;
  final double? longitude;
  final List<Map<String, dynamic>> answers;

  const SurveySubmit({
    required this.surveyId,
    this.territoryId,
    this.latitude,
    this.longitude,
    required this.answers,
  });

  @override
  List<Object?> get props => [surveyId, territoryId, latitude, longitude, answers];
}

class SurveyRefresh extends SurveyEvent {
  final bool isLeader;
  final String? teamId;

  const SurveyRefresh({this.isLeader = false, this.teamId});

  @override
  List<Object?> get props => [isLeader, teamId];
}

class SurveyLoadTeamSurveys extends SurveyEvent {
  final String teamId;

  const SurveyLoadTeamSurveys({required this.teamId});

  @override
  List<Object?> get props => [teamId];
}
