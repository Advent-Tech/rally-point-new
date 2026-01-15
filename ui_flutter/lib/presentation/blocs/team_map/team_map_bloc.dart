import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

part 'team_map_event.dart';
part 'team_map_state.dart';

class TeamMapBloc extends Bloc<TeamMapEvent, TeamMapState> {
  ApiClient? _apiClient;
  String? _currentTeamId;
  bool _isInitialized = false;

  TeamMapBloc() : super(TeamMapInitial()) {
    on<TeamMapLoad>(_onLoad);
    on<TeamMapRefresh>(_onRefresh);
    on<TeamMapRefreshMarkers>(_onRefreshMarkers);
    on<TeamMapUpdateFilters>(_onUpdateFilters);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _isInitialized = true;
  }

  Future<void> _onLoad(TeamMapLoad event, Emitter<TeamMapState> emit) async {
    emit(TeamMapLoading());
    _currentTeamId = event.teamId;

    try {
      await _initialize();

      // Fetch all data in parallel
      final results = await Future.wait([
        _fetchActiveWorkers(event.teamId),
        _fetchDeliveries(event.teamId),
        _fetchReceipts(event.teamId),
        _fetchDonations(event.teamId),
        _fetchTerritoryBoundaries(event.teamId),
      ]);

      emit(TeamMapLoaded(
        activeWorkers: results[0] as List<ActiveWorkerLocation>,
        deliveries: results[1] as List<MapDeliveryMarker>,
        receipts: results[2] as List<MapReceiptMarker>,
        donations: results[3] as List<MapDonationMarker>,
        territoryBoundaries: results[4] as List<TerritoryBoundary>,
        teamId: event.teamId,
      ));
    } catch (e) {
      emit(TeamMapError(message: e.toString()));
    }
  }

  Future<List<ActiveWorkerLocation>> _fetchActiveWorkers(String teamId) async {
    try {
      // Fetch active workers from geofence endpoint
      final response = await _apiClient!.get(
        '/api/geofence/teams/$teamId/workers/active',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['active_sessions'] ?? response.data['workers'] ?? [];
        return data.map((json) => ActiveWorkerLocation.fromJson(json)).toList();
      }
    } catch (e) {
      // Return empty list on error
    }
    return [];
  }

  Future<List<MapDeliveryMarker>> _fetchDeliveries(String teamId) async {
    try {
      // Use team-specific endpoint
      final response = await _apiClient!.get(
        '/api/teams/$teamId/deliveries',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['deliveries'] ?? [];

        // API returns nested structure: { "delivery": {...}, "items": [...] }
        // Extract the delivery object from each item
        return data.map((json) {
          final deliveryData = json is Map && json.containsKey('delivery')
              ? json['delivery'] as Map<String, dynamic>
              : json as Map<String, dynamic>;
          return MapDeliveryMarker.fromJson(deliveryData);
        }).where((d) => d.latitude != 0 && d.longitude != 0).toList();
      }
    } catch (_) {
      // Silent fail - return empty list
    }
    return [];
  }

  Future<List<MapReceiptMarker>> _fetchReceipts(String teamId) async {
    try {
      // Use team-specific endpoint
      final response = await _apiClient!.get(
        '/api/receipts/team/$teamId',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['receipts'] ?? [];
        return data
            .map((json) => MapReceiptMarker.fromJson(json))
            .where((r) => r.latitude != 0 && r.longitude != 0)
            .toList();
      }
    } catch (e) {
      // Return empty list on error
    }
    return [];
  }

  Future<List<MapDonationMarker>> _fetchDonations(String teamId) async {
    try {
      // Use team-specific endpoint
      final response = await _apiClient!.get(
        '/api/donations/team/$teamId',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['donations'] ?? [];
        return data
            .map((json) => MapDonationMarker.fromJson(json))
            .where((d) => d.latitude != 0 && d.longitude != 0)
            .toList();
      }
    } catch (e) {
      // Return empty list on error
    }
    return [];
  }

  Future<List<TerritoryBoundary>> _fetchTerritoryBoundaries(String teamId) async {
    try {
      // Try the GeoJSON endpoint first (returns proper GeoJSON FeatureCollection)
      final response = await _apiClient!.get(
        '/api/geo/assignments/team/$teamId/geojson',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // GeoJSON FeatureCollection format
        if (data['type'] == 'FeatureCollection' && data['features'] != null) {
          final features = data['features'] as List;
          final territories = <TerritoryBoundary>[];
          for (final f in features) {
            final territory = TerritoryBoundary.fromGeoJsonFeature(f as Map<String, dynamic>);
            if (territory.coordinates.isNotEmpty) {
              territories.add(territory);
            }
          }
          return territories;
        }
      }

      // Fallback: Try the assignments endpoint (same as delivery screen)
      final fallbackResponse = await _apiClient!.get(
        ApiConstants.myAssignments,
        queryParameters: {'team_id': teamId},
      );

      if (fallbackResponse.statusCode == 200) {
        final List<dynamic> data = fallbackResponse.data is List
            ? fallbackResponse.data
            : fallbackResponse.data['assignments'] ?? [];

        final territories = <TerritoryBoundary>[];
        for (final json in data) {
          final territory = TerritoryBoundary.fromAssignment(json as Map<String, dynamic>);
          if (territory.coordinates.isNotEmpty) {
            territories.add(territory);
          }
        }
        return territories;
      }
    } catch (_) {
      // Silent fail - return empty list
    }
    return [];
  }

  Future<void> _onRefresh(TeamMapRefresh event, Emitter<TeamMapState> emit) async {
    if (_currentTeamId != null) {
      add(TeamMapLoad(teamId: _currentTeamId!));
    }
  }

  /// Lightweight refresh that only updates dynamic markers (workers, deliveries, receipts, donations)
  /// without reloading territory boundaries
  Future<void> _onRefreshMarkers(TeamMapRefreshMarkers event, Emitter<TeamMapState> emit) async {
    final currentState = state;
    if (currentState is! TeamMapLoaded || _currentTeamId == null) return;

    try {
      await _initialize();

      // Only fetch dynamic data, keep existing territories
      final results = await Future.wait([
        _fetchActiveWorkers(_currentTeamId!),
        _fetchDeliveries(_currentTeamId!),
        _fetchReceipts(_currentTeamId!),
        _fetchDonations(_currentTeamId!),
      ]);

      emit(currentState.copyWith(
        activeWorkers: results[0] as List<ActiveWorkerLocation>,
        deliveries: results[1] as List<MapDeliveryMarker>,
        receipts: results[2] as List<MapReceiptMarker>,
        donations: results[3] as List<MapDonationMarker>,
      ));
    } catch (e) {
      // On error, keep existing state - don't disrupt the map
    }
  }

  void _onUpdateFilters(TeamMapUpdateFilters event, Emitter<TeamMapState> emit) {
    final currentState = state;
    if (currentState is TeamMapLoaded) {
      emit(currentState.copyWith(
        showWorkers: event.showWorkers,
        showDeliveries: event.showDeliveries,
        showReceipts: event.showReceipts,
        showDonations: event.showDonations,
        showTerritories: event.showTerritories,
      ));
    }
  }
}
