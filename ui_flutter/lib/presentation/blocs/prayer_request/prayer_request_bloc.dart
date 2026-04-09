import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/prayer_request_model.dart';
import '../../../data/repositories/prayer_request_repository.dart';

part 'prayer_request_event.dart';
part 'prayer_request_state.dart';

class PrayerRequestBloc extends Bloc<PrayerRequestEvent, PrayerRequestState> {
  final PrayerRequestRepository _repository;

  PrayerRequestBloc({PrayerRequestRepository? repository})
      : _repository = repository ?? PrayerRequestRepository(),
        super(PrayerRequestInitial()) {
    on<PrayerRequestLoadMy>(_onLoadMy);
    on<PrayerRequestLoadList>(_onLoadList);
    on<PrayerRequestLoadMapMarkers>(_onLoadMapMarkers);
    on<PrayerRequestLoadStats>(_onLoadStats);
    on<PrayerRequestLoadDetails>(_onLoadDetails);
    on<PrayerRequestCreate>(_onCreate);
    on<PrayerRequestUpdate>(_onUpdate);
    on<PrayerRequestDelete>(_onDelete);
    on<PrayerRequestUpdateStatus>(_onUpdateStatus);
    on<PrayerRequestAssignPreacher>(_onAssignPreacher);
    on<PrayerRequestComplete>(_onComplete);
    on<PrayerRequestRefresh>(_onRefresh);
  }

  Future<void> _onLoadMy(PrayerRequestLoadMy event, Emitter<PrayerRequestState> emit) async {
    emit(PrayerRequestLoading());

    final result = await _repository.getMyPrayerRequests(
      page: event.page,
      pageSize: event.pageSize,
    );

    result.when(
      success: (response) {
        emit(PrayerRequestLoaded(
          prayerRequests: response.prayerRequests,
          total: response.total,
          page: response.page,
          pageSize: response.pageSize,
          totalPages: response.totalPages,
        ));
      },
      failure: (message, statusCode) {
        emit(PrayerRequestError(message: message));
      },
    );
  }

  Future<void> _onLoadList(PrayerRequestLoadList event, Emitter<PrayerRequestState> emit) async {
    emit(PrayerRequestLoading());

    final result = await _repository.listPrayerRequests(
      teamId: event.teamId,
      territoryId: event.territoryId,
      status: event.status,
      requestType: event.requestType,
      category: event.category,
      urgency: event.urgency,
      page: event.page,
      pageSize: event.pageSize,
    );

    result.when(
      success: (response) {
        final currentState = state;
        if (currentState is PrayerRequestLoaded) {
          emit(currentState.copyWith(
            prayerRequests: response.prayerRequests,
            total: response.total,
            page: response.page,
            pageSize: response.pageSize,
            totalPages: response.totalPages,
          ));
        } else {
          emit(PrayerRequestLoaded(
            prayerRequests: response.prayerRequests,
            total: response.total,
            page: response.page,
            pageSize: response.pageSize,
            totalPages: response.totalPages,
          ));
        }
      },
      failure: (message, statusCode) {
        emit(PrayerRequestError(message: message));
      },
    );
  }

  Future<void> _onLoadMapMarkers(PrayerRequestLoadMapMarkers event, Emitter<PrayerRequestState> emit) async {
    final result = await _repository.getMapMarkers(
      teamId: event.teamId,
      territoryId: event.territoryId,
      status: event.status,
      requestType: event.requestType,
    );

    result.when(
      success: (markers) {
        final currentState = state;
        if (currentState is PrayerRequestLoaded) {
          emit(currentState.copyWith(mapMarkers: markers));
        } else {
          emit(PrayerRequestLoaded(mapMarkers: markers));
        }
      },
      failure: (message, statusCode) {
        // Don't emit error, just keep current state
      },
    );
  }

  Future<void> _onLoadStats(PrayerRequestLoadStats event, Emitter<PrayerRequestState> emit) async {
    final result = await _repository.getStats(
      teamId: event.teamId,
      territoryId: event.territoryId,
    );

    result.when(
      success: (stats) {
        final currentState = state;
        if (currentState is PrayerRequestLoaded) {
          emit(currentState.copyWith(stats: stats));
        } else {
          emit(PrayerRequestLoaded(stats: stats));
        }
      },
      failure: (message, statusCode) {
        // Don't emit error for stats
      },
    );
  }

  Future<void> _onLoadDetails(PrayerRequestLoadDetails event, Emitter<PrayerRequestState> emit) async {
    final result = await _repository.getPrayerRequest(event.id);

    result.when(
      success: (prayerRequest) {
        final currentState = state;
        if (currentState is PrayerRequestLoaded) {
          emit(currentState.copyWith(currentPrayerRequest: prayerRequest));
        } else {
          emit(PrayerRequestLoaded(currentPrayerRequest: prayerRequest));
        }
      },
      failure: (message, statusCode) {
        emit(PrayerRequestError(message: message));
      },
    );
  }

  Future<void> _onCreate(PrayerRequestCreate event, Emitter<PrayerRequestState> emit) async {
    emit(PrayerRequestSubmitting());

    final request = CreatePrayerRequestRequest(
      requesterName: event.requesterName,
      requesterPhone: event.requesterPhone,
      requesterEmail: event.requesterEmail,
      requesterAddress: event.requesterAddress,
      latitude: event.latitude,
      longitude: event.longitude,
      prayerSubject: event.prayerSubject,
      prayerDetails: event.prayerDetails,
      prayerCategory: event.prayerCategory,
      requestType: event.requestType,
      preferredVisitDate: event.preferredVisitDate,
      preferredVisitTime: event.preferredVisitTime,
      urgency: event.urgency,
      territoryId: event.territoryId,
      notes: event.notes,
    );

    final result = await _repository.createPrayerRequest(request);

    result.when(
      success: (prayerRequest) {
        emit(PrayerRequestSubmitSuccess(prayerRequest: prayerRequest));
        // Refresh the list
        add(const PrayerRequestRefresh());
      },
      failure: (message, statusCode) {
        emit(PrayerRequestError(message: message));
      },
    );
  }

  Future<void> _onUpdate(PrayerRequestUpdate event, Emitter<PrayerRequestState> emit) async {
    emit(PrayerRequestSubmitting());

    final request = UpdatePrayerRequestRequest(
      requesterName: event.requesterName,
      requesterPhone: event.requesterPhone,
      requesterEmail: event.requesterEmail,
      requesterAddress: event.requesterAddress,
      latitude: event.latitude,
      longitude: event.longitude,
      prayerSubject: event.prayerSubject,
      prayerDetails: event.prayerDetails,
      prayerCategory: event.prayerCategory,
      requestType: event.requestType,
      preferredVisitDate: event.preferredVisitDate,
      preferredVisitTime: event.preferredVisitTime,
      urgency: event.urgency,
      notes: event.notes,
    );

    final result = await _repository.updatePrayerRequest(event.id, request);

    result.when(
      success: (prayerRequest) {
        emit(PrayerRequestSubmitSuccess(prayerRequest: prayerRequest));
        add(const PrayerRequestRefresh());
      },
      failure: (message, statusCode) {
        emit(PrayerRequestError(message: message));
      },
    );
  }

  Future<void> _onDelete(PrayerRequestDelete event, Emitter<PrayerRequestState> emit) async {
    final result = await _repository.deletePrayerRequest(event.id);

    result.when(
      success: (_) {
        emit(const PrayerRequestActionSuccess(message: 'Prayer request deleted'));
        add(const PrayerRequestRefresh());
      },
      failure: (message, statusCode) {
        emit(PrayerRequestError(message: message));
      },
    );
  }

  Future<void> _onUpdateStatus(PrayerRequestUpdateStatus event, Emitter<PrayerRequestState> emit) async {
    final result = await _repository.updateStatus(
      event.id,
      status: event.status,
      completionNotes: event.completionNotes,
    );

    result.when(
      success: (_) {
        emit(const PrayerRequestActionSuccess(message: 'Status updated'));
        add(const PrayerRequestRefresh());
      },
      failure: (message, statusCode) {
        emit(PrayerRequestError(message: message));
      },
    );
  }

  Future<void> _onAssignPreacher(PrayerRequestAssignPreacher event, Emitter<PrayerRequestState> emit) async {
    final result = await _repository.assignPreacher(
      event.id,
      preacherId: event.preacherId,
      scheduledAt: event.scheduledAt,
      notes: event.notes,
    );

    result.when(
      success: (_) {
        emit(const PrayerRequestActionSuccess(message: 'Preacher assigned'));
        add(const PrayerRequestRefresh());
      },
      failure: (message, statusCode) {
        emit(PrayerRequestError(message: message));
      },
    );
  }

  Future<void> _onComplete(PrayerRequestComplete event, Emitter<PrayerRequestState> emit) async {
    final result = await _repository.completePrayerRequest(
      event.id,
      notes: event.notes,
    );

    result.when(
      success: (_) {
        emit(const PrayerRequestActionSuccess(message: 'Prayer request completed'));
        add(const PrayerRequestRefresh());
      },
      failure: (message, statusCode) {
        emit(PrayerRequestError(message: message));
      },
    );
  }

  Future<void> _onRefresh(PrayerRequestRefresh event, Emitter<PrayerRequestState> emit) async {
    emit(PrayerRequestLoading());

    List<PrayerRequestModel> prayerRequests = [];
    List<PrayerRequestMapMarker> markers = [];
    PrayerRequestStats? stats;

    if (event.isLeader && event.teamId != null) {
      // Leaders see team prayer requests
      final listResult = await _repository.getTeamPrayerRequests(event.teamId!);
      listResult.when(
        success: (response) => prayerRequests = response.prayerRequests,
        failure: (_, __) {},
      );

      final markersResult = await _repository.getMapMarkers(teamId: event.teamId);
      markersResult.when(
        success: (data) => markers = data,
        failure: (_, __) {},
      );

      final statsResult = await _repository.getStats(teamId: event.teamId);
      statsResult.when(
        success: (data) => stats = data,
        failure: (_, __) {},
      );
    } else {
      // Workers see their own prayer requests
      final listResult = await _repository.getMyPrayerRequests();
      listResult.when(
        success: (response) => prayerRequests = response.prayerRequests,
        failure: (_, __) {},
      );
    }

    emit(PrayerRequestLoaded(
      prayerRequests: prayerRequests,
      mapMarkers: markers,
      stats: stats,
    ));
  }
}
