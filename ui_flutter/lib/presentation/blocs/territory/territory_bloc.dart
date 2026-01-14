import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/territory_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';

part 'territory_event.dart';
part 'territory_state.dart';

class TerritoryBloc extends Bloc<TerritoryEvent, TerritoryState> {
  ApiClient? _apiClient;
  LocalStorage? _localStorage;
  bool _isInitialized = false;
  CancelToken? _searchCancelToken;

  TerritoryBloc() : super(TerritoryInitial()) {
    on<TerritoryLoadAssignments>(_onLoadAssignments);
    on<TerritoryLoadAvailable>(_onLoadAvailable);
    on<TerritorySearch>(_onSearch);
    on<TerritoryRequestAssignment>(_onRequestAssignment);
    on<TerritoryAssignToWorker>(_onAssignToWorker);
    on<TerritoryLoadNearby>(_onLoadNearby);
    on<TerritoryLoadUnionStats>(_onLoadUnionStats);
    on<TerritoryLoadChurches>(_onLoadChurches);
    on<TerritoryRefresh>(_onRefresh);
    on<TerritoryLoadMyAllocations>(_onLoadMyAllocations);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _localStorage = await LocalStorage.getInstance();
    _isInitialized = true;
  }

  // Getters that assert initialization
  ApiClient get _api => _apiClient!;
  LocalStorage get _local => _localStorage!;

  Future<void> _onLoadAssignments(
    TerritoryLoadAssignments event,
    Emitter<TerritoryState> emit,
  ) async {
    emit(TerritoryLoading());

    try {
      await _initialize();

      // Get user's worker_id from stored user data
      final userData = _local.getUserData();
      final workerId = userData?['id'] ?? userData?['worker_id'];

      if (workerId == null) {
        // No worker ID available, return empty list
        emit(const TerritoryAssignmentsLoaded(
          assignments: [],
          activeCount: 0,
          completedCount: 0,
        ));
        return;
      }

      final response = await _api.get(
        ApiConstants.myAssignments,
        queryParameters: {'worker_id': workerId},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : response.data['assignments'] ?? [];
        final assignments = data.map((json) => TerritoryAssignment.fromJson(json)).toList();

        // Cache for offline
        await _local.saveTerritoryAssignments(data);

        emit(TerritoryAssignmentsLoaded(
          assignments: assignments,
          activeCount: assignments.where((a) => a.isActive).length,
          completedCount: assignments.where((a) => a.isCompleted).length,
        ));
      } else {
        // Return empty list instead of error
        emit(const TerritoryAssignmentsLoaded(
          assignments: [],
          activeCount: 0,
          completedCount: 0,
        ));
      }
    } catch (e) {
      // Try loading from cache first
      final cached = _localStorage?.getTerritoryAssignments();
      if (cached != null && cached.isNotEmpty) {
        final assignments = cached.map((json) => TerritoryAssignment.fromJson(json)).toList();
        emit(TerritoryAssignmentsLoaded(
          assignments: assignments,
          activeCount: assignments.where((a) => a.isActive).length,
          completedCount: assignments.where((a) => a.isCompleted).length,
          isOffline: true,
        ));
      } else {
        // Return empty list instead of error to prevent UI crashes
        emit(const TerritoryAssignmentsLoaded(
          assignments: [],
          activeCount: 0,
          completedCount: 0,
        ));
      }
    }
  }

  Future<void> _onLoadAvailable(
    TerritoryLoadAvailable event,
    Emitter<TerritoryState> emit,
  ) async {
    // Don't show loading if appending
    if (event.offset == 0) {
      emit(TerritoryLoading());
    }

    try {
      await _initialize();

      final queryParams = <String, dynamic>{
        'limit': event.limit,
        'offset': event.offset,
        'include_geometry': true, // Request geometry data for map display
      };
      if (event.unionName != null) {
        queryParams['union_name'] = event.unionName;
      }
      if (event.conference != null) {
        queryParams['conference'] = event.conference;
      }
      if (event.searchQuery != null && event.searchQuery!.isNotEmpty) {
        queryParams['q'] = event.searchQuery;
      }

      final response = await _api.get(
        ApiConstants.geoTerritoriesList,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : response.data['territories'] ?? [];
        final newTerritories = data.map((json) => GeoTerritory.fromJson(json)).toList();
        final total = response.data is Map ? response.data['total'] ?? newTerritories.length : newTerritories.length;

        // Debug: Check if geometry is being returned
        final withGeometry = newTerritories.where((t) => t.geometry != null).length;
        debugPrint('Territories loaded: ${newTerritories.length}, with geometry: $withGeometry');

        // If appending (offset > 0), merge with existing
        List<GeoTerritory> allTerritories = newTerritories;
        if (event.offset > 0 && state is TerritoryAvailableLoaded) {
          final currentState = state as TerritoryAvailableLoaded;
          allTerritories = [...currentState.territories, ...newTerritories];
        }

        emit(TerritoryAvailableLoaded(
          territories: allTerritories,
          hasMore: newTerritories.length == event.limit,
          total: total,
          currentOffset: event.offset + newTerritories.length,
        ));
      } else {
        emit(TerritoryError(message: 'Failed to load available territories'));
      }
    } catch (e) {
      emit(TerritoryError(message: e.toString()));
    }
  }

  Future<void> _onSearch(
    TerritorySearch event,
    Emitter<TerritoryState> emit,
  ) async {
    // Cancel any previous search request
    _searchCancelToken?.cancel('New search initiated');
    _searchCancelToken = CancelToken();

    // Only show searching state if not paginating
    if (event.offset == 0) {
      emit(TerritorySearching());
    }

    try {
      await _initialize();

      final response = await _api.get(
        ApiConstants.geoTerritoriesSearch,
        queryParameters: {
          'q': event.query,
          'limit': event.limit,
          'offset': event.offset,
          'include_geometry': true, // Request geometry data for map display
        },
        cancelToken: _searchCancelToken,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : response.data['territories'] ?? [];
        final newTerritories = data.map((json) => GeoTerritory.fromJson(json)).toList();
        final total = response.data is Map ? response.data['total'] ?? newTerritories.length : newTerritories.length;

        // If paginating (offset > 0), merge with existing results
        List<GeoTerritory> allTerritories = newTerritories;
        if (event.offset > 0 && state is TerritorySearchResults) {
          final currentState = state as TerritorySearchResults;
          if (currentState.query == event.query) {
            allTerritories = [...currentState.territories, ...newTerritories];
          }
        }

        emit(TerritorySearchResults(
          territories: allTerritories,
          query: event.query,
          hasMore: newTerritories.length == event.limit,
          total: total,
        ));
      } else {
        emit(TerritoryError(message: 'Search failed'));
      }
    } on DioException catch (e) {
      // Ignore cancelled requests - don't show error
      if (e.type == DioExceptionType.cancel) {
        return;
      }
      emit(TerritoryError(message: e.message ?? 'Search failed'));
    } catch (e) {
      emit(TerritoryError(message: e.toString()));
    }
  }

  Future<void> _onRequestAssignment(
    TerritoryRequestAssignment event,
    Emitter<TerritoryState> emit,
  ) async {
    emit(TerritoryRequesting());

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.requestTerritory,
        data: {
          'territory_id': event.territoryId,
          if (event.notes != null) 'notes': event.notes,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        emit(TerritoryRequestSuccess(
          message: 'Territory request submitted successfully',
        ));
        // Reload assignments
        add(const TerritoryLoadAssignments());
      } else {
        emit(TerritoryError(message: 'Failed to request territory'));
      }
    } catch (e) {
      emit(TerritoryError(message: e.toString()));
    }
  }

  Future<void> _onAssignToWorker(
    TerritoryAssignToWorker event,
    Emitter<TerritoryState> emit,
  ) async {
    emit(TerritoryRequesting());

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.assignments,
        data: {
          'territory_id': event.territoryId,
          'territory_solid': event.territorySolid,
          'assigned_worker_id': event.workerId,
          'team_id': event.teamId,
          'assigned_by': event.assignedBy,
          'priority': event.priority,
          if (event.notes != null) 'notes': event.notes,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        emit(const TerritoryAssignSuccess(
          message: 'Territory assigned successfully',
        ));
      } else {
        // Check for duplicate assignment error in response
        final errorMessage = response.data is Map
            ? response.data['error']?.toString() ?? 'Failed to assign territory'
            : 'Failed to assign territory';

        if (errorMessage.contains('duplicate key') ||
            errorMessage.contains('already assigned') ||
            errorMessage.contains('unique constraint')) {
          emit(const TerritoryError(
            message: 'This territory is already assigned to your team. To reassign it to a different worker, please update the existing assignment.',
          ));
        } else {
          emit(TerritoryError(message: errorMessage));
        }
      }
    } on DioException catch (e) {
      // Parse the error response for duplicate key constraint
      String errorMessage = 'Failed to assign territory';

      if (e.response?.data != null) {
        final responseData = e.response!.data;
        if (responseData is Map && responseData['error'] != null) {
          final apiError = responseData['error'].toString();

          // Check for duplicate key / unique constraint error
          if (apiError.contains('duplicate key') ||
              apiError.contains('already assigned') ||
              apiError.contains('unique constraint')) {
            errorMessage = 'This territory is already assigned to your team. To reassign it to a different worker, please update the existing assignment.';
          } else {
            errorMessage = apiError;
          }
        }
      } else if (e.message != null) {
        errorMessage = e.message!;
      }

      emit(TerritoryError(message: errorMessage));
    } catch (e) {
      emit(TerritoryError(message: e.toString()));
    }
  }

  Future<void> _onLoadNearby(
    TerritoryLoadNearby event,
    Emitter<TerritoryState> emit,
  ) async {
    emit(TerritoryLoading());

    try {
      await _initialize();

      final response = await _api.get(
        ApiConstants.territoriesNearby,
        queryParameters: {
          'lat': event.latitude,
          'lng': event.longitude,
          'radius': event.radiusKm,
          'include_geometry': true,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : response.data['territories'] ?? [];
        final territories = data.map((json) => GeoTerritory.fromJson(json)).toList();

        emit(TerritoryNearbyLoaded(
          territories: territories,
          latitude: event.latitude,
          longitude: event.longitude,
        ));
      } else {
        emit(TerritoryError(message: 'Failed to load nearby territories'));
      }
    } catch (e) {
      emit(TerritoryError(message: e.toString()));
    }
  }

  Future<void> _onLoadUnionStats(
    TerritoryLoadUnionStats event,
    Emitter<TerritoryState> emit,
  ) async {
    try {
      await _initialize();

      final response = await _api.get(ApiConstants.unionStats);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : response.data['unions'] ?? [];
        final stats = data.map((json) => UnionStats.fromJson(json)).toList();

        emit(TerritoryUnionStatsLoaded(stats: stats));
      }
    } catch (e) {
      // Silent fail - stats are not critical
    }
  }

  Future<void> _onLoadChurches(
    TerritoryLoadChurches event,
    Emitter<TerritoryState> emit,
  ) async {
    try {
      await _initialize();

      final response = await _api.get(
        ApiConstants.churchLocations,
        queryParameters: {
          if (event.unionName != null) 'union_name': event.unionName,
          'limit': 50,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : response.data['churches'] ?? [];
        final churches = data.map((json) => ChurchLocation.fromJson(json)).toList();

        emit(TerritoryChurchesLoaded(churches: churches));
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _onRefresh(
    TerritoryRefresh event,
    Emitter<TerritoryState> emit,
  ) async {
    add(const TerritoryLoadAssignments());
  }

  /// Load territories allocated to the current team leader by admin
  Future<void> _onLoadMyAllocations(
    TerritoryLoadMyAllocations event,
    Emitter<TerritoryState> emit,
  ) async {
    emit(TerritoryLoading());

    try {
      await _initialize();

      final response = await _api.get(
        ApiConstants.myTerritoryAllocations,
        queryParameters: {
          'include_geometry': true,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['allocations'] ?? response.data['territories'] ?? [];

        debugPrint('Allocation response: ${data.length} items');

        // Convert allocation data to GeoTerritory
        // The backend returns LeaderTerritoryAllocationWithDetails which has:
        // - territory_id (UUID of the territory)
        // - territory_solid (SOLID code)
        // - entity_name, entity_id, city, state, etc.
        // We need to map these to GeoTerritory fields
        final territories = <GeoTerritory>[];
        for (final json in data) {
          try {
            // If nested territory object exists, use it
            if (json['territory'] != null) {
              territories.add(GeoTerritory.fromJson(json['territory']));
            } else {
              // Map allocation fields to GeoTerritory fields
              final territoryJson = <String, dynamic>{
                'id': json['territory_id']?.toString() ?? json['id']?.toString() ?? '',
                'solid': json['territory_solid'] ?? json['solid'] ?? '',
                'entity_name': json['entity_name'] ?? '',
                'entity_id': json['entity_id'] ?? '',
                'city': json['city'],
                'state': json['state'],
                'county': json['county'],
                'zipcode': json['zipcode'],
                'population': json['population'],
                'housing_units': json['housing_units'],
                'union_name': json['union_name'],
                'conference': json['conference'],
                'geometry': json['geometry'],
                'address': json['address'],
                'geoid': json['geoid'],
              };
              territories.add(GeoTerritory.fromJson(territoryJson));
            }
          } catch (e) {
            debugPrint('Error parsing allocation: $e');
          }
        }

        final total = response.data is Map
            ? response.data['total'] ?? territories.length
            : territories.length;

        debugPrint('Leader allocations loaded: ${territories.length}');

        emit(TerritoryAllocationsLoaded(
          territories: territories,
          total: total,
        ));
      } else {
        emit(const TerritoryAllocationsLoaded(
          territories: [],
          total: 0,
        ));
      }
    } catch (e) {
      debugPrint('Error loading leader allocations: $e');
      emit(TerritoryError(message: 'Failed to load allocated territories: ${e.toString()}'));
    }
  }
}
