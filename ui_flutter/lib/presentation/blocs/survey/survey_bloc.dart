import 'package:flutter/foundation.dart';
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

    final answers = <AnswerInput>[];
    for (final a in event.answers) {
      // Skip answers without a valid question_id
      final questionId = a['question_id'];
      if (questionId == null || questionId is! String || questionId.isEmpty) {
        continue;
      }

      answers.add(AnswerInput(
        questionId: questionId,
        value: a['value']?.toString(),
        selectedOptions: (a['selected_options'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList(),
        photoUrls: (a['photo_urls'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList(),
        signatureUrl: a['signature_url']?.toString(),
      ));
    }

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

    debugPrint('SurveyBloc: _onRefresh called, isLeader: ${event.isLeader}');

    // Team leaders see ALL surveys (created by admins)
    // Workers see only their assigned surveys
    if (event.isLeader) {
      // Leaders fetch all surveys from /api/surveys
      debugPrint('SurveyBloc: Fetching all surveys for leader...');
      final allSurveysResult = await _surveyRepository.getAllSurveys();
      allSurveysResult.when(
        success: (data) {
          surveys = data;
          debugPrint('SurveyBloc: Leader - loaded ${surveys.length} surveys');
        },
        failure: (msg, _) {
          debugPrint('SurveyBloc: Leader - failed to fetch surveys: $msg');
        },
      );
    } else {
      // Workers fetch their assigned surveys
      debugPrint('SurveyBloc: Fetching available surveys for worker...');
      final surveysResult = await _surveyRepository.getAvailableSurveys();
      surveysResult.when(
        success: (data) {
          surveys = data;
          debugPrint('SurveyBloc: Worker - loaded ${surveys.length} available surveys');
        },
        failure: (msg, _) {
          debugPrint('SurveyBloc: Worker - failed to fetch available surveys: $msg');
          // For workers, also try fetching all surveys as fallback
        },
      );

      // If worker has no assignments, try fetching all published surveys
      if (surveys.isEmpty) {
        debugPrint('SurveyBloc: Worker has no assignments, trying to fetch all surveys...');
        final allSurveysResult = await _surveyRepository.getAllSurveys();
        allSurveysResult.when(
          success: (data) {
            // Filter to only published surveys for workers
            surveys = data.where((s) => s.isPublished).toList();
            debugPrint('SurveyBloc: Worker - found ${surveys.length} published surveys');
          },
          failure: (msg, _) {
            debugPrint('SurveyBloc: Worker - failed to fetch all surveys: $msg');
          },
        );
      }
    }

    // Workers also load their responses (leaders don't need this)
    if (!event.isLeader) {
      debugPrint('SurveyBloc: Fetching worker responses...');
      final responsesResult = await _surveyRepository.getMyResponses();
      responsesResult.when(
        success: (data) {
          responses = data;
          debugPrint('SurveyBloc: Worker - loaded ${responses.length} responses');
        },
        failure: (msg, _) {
          debugPrint('SurveyBloc: Worker - failed to fetch responses: $msg');
        },
      );
    }

    debugPrint('SurveyBloc: Emitting SurveyLoaded with ${surveys.length} surveys, ${responses.length} responses');
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
