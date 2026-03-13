import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'command_center_event.dart';
import 'command_center_state.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../data/models/territory_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/models/donation_model.dart';
import '../../../../data/models/prayer_request_model.dart';
import '../../../../core/network/api_client.dart';

class CommandCenterBloc extends Bloc<CommandCenterEvent, CommandCenterState> {
  final ApiClient _apiClient;
  final SecureStorage _storage;

  CommandCenterBloc({
    required ApiClient apiClient,
    required SecureStorage storage,
  }) : _apiClient = apiClient,
       _storage = storage,
       super(const CommandCenterState()) {
    on<InitializeEvent>(_onInitialize);
    on<ChangeMapModeEvent>(_onChangeMapMode);
    on<RefreshDataEvent>(_onRefreshData);
    on<UpdateLiveLocationEvent>(_onUpdateLiveLocation);
    on<AddDonationEvent>(_onAddDonation);
    on<AddPrayerRequestEvent>(_onAddPrayerRequest);
    on<SelectTerritoryEvent>(_onSelectTerritory);
    on<FollowWorkerEvent>(_onFollowWorker);
    on<ToggleLayerEvent>(_onToggleLayer);
    on<UpdateWorkerPathEvent>(_onUpdateWorkerPath);
  }

  Future<void> _onInitialize(
    InitializeEvent event,
    Emitter<CommandCenterState> emit,
  ) async {
    emit(state.copyWith(mapMode: event.initialMode, isLoading: true));

    await _loadAllData(emit);
  }

  Future<void> _onChangeMapMode(
    ChangeMapModeEvent event,
    Emitter<CommandCenterState> emit,
  ) async {
    emit(state.copyWith(mapMode: event.mode));
  }

  Future<void> _onRefreshData(
    RefreshDataEvent event,
    Emitter<CommandCenterState> emit,
  ) async {
    await _loadAllData(emit);
  }

  Future<void> _loadAllData(Emitter<CommandCenterState> emit) async {
    try {
      final teamId = await _storage.read('team_id');
      if (teamId == null) {
        emit(state.copyWith(isLoading: false, error: 'No team ID found'));
        return;
      }

      // Parallel data loading with individual error handling
      final results = await Future.wait([
        _loadTerritories(),
        _loadDonations(teamId),
        _loadPrayerRequests(teamId),
        _loadWorkers(teamId),
      ], eagerError: false);

      final territories = results[0] as List<GeoTerritory>? ?? [];
      final donations = results[1] as List<DonationModel>? ?? [];
      final prayerRequests = results[2] as List<PrayerRequestModel>? ?? [];
      final workers = results[3] as List<TeamMember>? ?? [];

      emit(
        state.copyWith(
          territories: territories,
          donations: donations,
          prayerRequests: prayerRequests,
          workers: workers,
          isLoading: false,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<List<GeoTerritory>?> _loadTerritories() async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.territories}/my-allocations',
      );

      if (response.statusCode == 200) {
        final results = _extractList(
          response.data,
          keys: const [
            'results',
            'data',
            'allocations',
            'assignments',
            'territories',
          ],
        );

        return results.whereType<Map<String, dynamic>>().map((item) {
          final territory = item['territory'];
          if (territory is Map<String, dynamic>) {
            return GeoTerritory.fromJson(_sanitizeGeoTerritoryJson(territory));
          }
          return GeoTerritory.fromJson(_sanitizeGeoTerritoryJson(item));
        }).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error loading territories: $e');
      return null;
    }
  }

  Future<List<DonationModel>?> _loadDonations(String teamId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.donations}/team/$teamId',
      );

      if (response.statusCode == 200) {
        final results = _extractList(
          response.data,
          keys: const ['results', 'data', 'donations'],
        );

        return results
            .whereType<Map<String, dynamic>>()
            .map(DonationModel.fromJson)
            .toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error loading donations: $e');
      return null;
    }
  }

  Future<List<PrayerRequestModel>?> _loadPrayerRequests(String teamId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.prayerRequests}/team/$teamId',
      );

      if (response.statusCode == 200) {
        final results = _extractList(
          response.data,
          keys: const ['results', 'data', 'prayer_requests', 'prayers'],
        );

        return results
            .whereType<Map<String, dynamic>>()
            .map(PrayerRequestModel.fromJson)
            .toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error loading prayer requests: $e');
      return null;
    }
  }

  Future<List<TeamMember>?> _loadWorkers(String teamId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.teams}/$teamId/workers',
      );

      if (response.statusCode == 200) {
        final results = _extractList(
          response.data,
          keys: const ['results', 'data', 'workers', 'members', 'users'],
        );

        return results
            .whereType<Map<String, dynamic>>()
            .map(TeamMember.fromUserJson)
            .toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error loading workers: $e');
      return null;
    }
  }

  void _onUpdateLiveLocation(
    UpdateLiveLocationEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    final updatedLocations = Map<String, Position>.from(state.liveLocations);
    updatedLocations[event.workerId] = Position(
      latitude: event.latitude,
      longitude: event.longitude,
    );

    emit(state.copyWith(liveLocations: updatedLocations));
  }

  void _onAddDonation(
    AddDonationEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    emit(state.copyWith(donations: [...state.donations, event.donation]));
  }

  void _onAddPrayerRequest(
    AddPrayerRequestEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    emit(
      state.copyWith(
        prayerRequests: [...state.prayerRequests, event.prayerRequest],
      ),
    );
  }

  void _onSelectTerritory(
    SelectTerritoryEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    emit(state.copyWith(selectedTerritoryId: event.territoryId));
  }

  void _onFollowWorker(
    FollowWorkerEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    emit(state.copyWith(followTarget: event.workerId));
  }

  void _onToggleLayer(
    ToggleLayerEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    switch (event.layer) {
      case 'territories':
        emit(state.copyWith(showTerritories: !state.showTerritories));
        break;
      case 'workers':
        emit(state.copyWith(showWorkers: !state.showWorkers));
        break;
      case 'activities':
        emit(state.copyWith(showActivities: !state.showActivities));
        break;
      case 'trails':
        emit(state.copyWith(showTrails: !state.showTrails));
        break;
    }
  }

  void _onUpdateWorkerPath(
    UpdateWorkerPathEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    final updatedPaths = Map<String, List<Position>>.from(state.workerPaths);
    updatedPaths[event.workerId] = event.path;

    emit(state.copyWith(workerPaths: updatedPaths));
  }

  List<dynamic> _extractList(dynamic data, {required List<String> keys}) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in keys) {
        final v = data[key];
        if (v is List) return v;
      }
    }
    return const [];
  }

  Map<String, dynamic> _sanitizeGeoTerritoryJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final solid = json['solid']?.toString() ?? 'false';

    final entityName =
        json['entity_name']?.toString() ?? json['entityName']?.toString() ?? '';
    final entityId =
        json['entity_id']?.toString() ?? json['entityId']?.toString() ?? '';

    return <String, dynamic>{
      ...json,
      'id': id,
      'solid': solid,
      'entity_name': entityName,
      'entity_id': entityId,
    };
  }
}
