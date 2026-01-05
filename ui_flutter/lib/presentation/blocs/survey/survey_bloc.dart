import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/survey_model.dart';
import '../../../data/repositories/survey_repository.dart';

part 'survey_event.dart';
part 'survey_state.dart';

class SurveyBloc extends Bloc<SurveyEvent, SurveyState> {
  final SurveyRepository _surveyRepository;

  SurveyBloc({SurveyRepository? surveyRepository})
      : _surveyRepository = surveyRepository ?? SurveyRepository(),
        super(SurveyInitial()) {
    on<SurveyLoadAvailable>(_onLoadAvailable);
    on<SurveyLoadResponses>(_onLoadResponses);
    on<SurveyLoadDetails>(_onLoadDetails);
    on<SurveySubmit>(_onSubmit);
    on<SurveyRefresh>(_onRefresh);
    on<SurveyLoadTeamSurveys>(_onLoadTeamSurveys);
  }

  Future<void> _onLoadAvailable(SurveyLoadAvailable event, Emitter<SurveyState> emit) async {
    emit(SurveyLoading());

    final result = await _surveyRepository.getAvailableSurveys();

    result.when(
      success: (surveys) {
        final currentState = state;
        if (currentState is SurveyLoaded) {
          emit(currentState.copyWith(availableSurveys: surveys));
        } else {
          emit(SurveyLoaded(availableSurveys: surveys));
        }
      },
      failure: (message, statusCode) {
        emit(SurveyError(message: message));
      },
    );
  }

  Future<void> _onLoadResponses(SurveyLoadResponses event, Emitter<SurveyState> emit) async {
    final result = await _surveyRepository.getMyResponses();

    result.when(
      success: (responses) {
        final currentState = state;
        if (currentState is SurveyLoaded) {
          emit(currentState.copyWith(myResponses: responses));
        } else {
          emit(SurveyLoaded(myResponses: responses));
        }
      },
      failure: (message, statusCode) {
        // Don't emit error for responses, just keep current state
      },
    );
  }

  Future<void> _onLoadDetails(SurveyLoadDetails event, Emitter<SurveyState> emit) async {
    final result = await _surveyRepository.getSurveyById(event.surveyId);

    result.when(
      success: (survey) {
        final currentState = state;
        if (currentState is SurveyLoaded) {
          emit(currentState.copyWith(currentSurvey: survey));
        } else {
          emit(SurveyLoaded(currentSurvey: survey));
        }
      },
      failure: (message, statusCode) {
        emit(SurveyError(message: message));
      },
    );
  }

  Future<void> _onSubmit(SurveySubmit event, Emitter<SurveyState> emit) async {
    emit(SurveySubmitting());

    final answers = event.answers.map((a) => AnswerInput(
      questionId: a['question_id'] as String,
      value: a['value'] as String?,
      selectedOptions: (a['selected_options'] as List<dynamic>?)?.cast<String>(),
      photoUrls: (a['photo_urls'] as List<dynamic>?)?.cast<String>(),
      signatureUrl: a['signature_url'] as String?,
    )).toList();

    final request = SubmitSurveyRequest(
      surveyId: event.surveyId,
      territoryId: event.territoryId,
      latitude: event.latitude,
      longitude: event.longitude,
      answers: answers,
    );

    final result = await _surveyRepository.submitSurvey(request);

    result.when(
      success: (response) {
        emit(SurveySubmitSuccess(response: response));
        // Reload data after submission
        add(const SurveyRefresh());
      },
      failure: (message, statusCode) {
        emit(SurveyError(message: message));
      },
    );
  }

  Future<void> _onRefresh(SurveyRefresh event, Emitter<SurveyState> emit) async {
    emit(SurveyLoading());

    List<SurveyModel> surveys = [];
    List<SurveyResponse> responses = [];

    // Both leaders and workers load team surveys if teamId is available
    if (event.teamId != null) {
      final teamSurveysResult = await _surveyRepository.getTeamSurveys(event.teamId!);
      teamSurveysResult.when(
        success: (data) => surveys = data,
        failure: (_, __) {},
      );
    } else {
      // Fallback to assignments if no teamId
      final surveysResult = await _surveyRepository.getAvailableSurveys();
      surveysResult.when(
        success: (data) => surveys = data,
        failure: (_, __) {},
      );
    }

    final responsesResult = await _surveyRepository.getMyResponses();
    responsesResult.when(
      success: (data) => responses = data,
      failure: (_, __) {},
    );

    emit(SurveyLoaded(
      availableSurveys: surveys,
      myResponses: responses,
    ));
  }

  Future<void> _onLoadTeamSurveys(SurveyLoadTeamSurveys event, Emitter<SurveyState> emit) async {
    emit(SurveyLoading());

    final result = await _surveyRepository.getTeamSurveys(event.teamId);

    result.when(
      success: (surveys) {
        final currentState = state;
        if (currentState is SurveyLoaded) {
          emit(currentState.copyWith(availableSurveys: surveys));
        } else {
          emit(SurveyLoaded(availableSurveys: surveys));
        }
      },
      failure: (message, statusCode) {
        emit(SurveyError(message: message));
      },
    );
  }
}
