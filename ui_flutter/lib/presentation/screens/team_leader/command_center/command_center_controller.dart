import 'dart:async';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'command_center_bloc.dart';
import 'command_center_state.dart';
import 'layers/territory_layer.dart';
import 'layers/worker_layer.dart';
import 'layers/activity_layer.dart';
import 'layers/trail_layer.dart';
import 'layers/breach_layer.dart';
import 'services/camera_controller.dart';
import 'services/bounds_calculator.dart';
import 'command_center_event.dart';

class CommandCenterController {
  final MapboxMap mapController;
  final CommandCenterBloc bloc;

  late TerritoryLayer _territoryLayer;
  late WorkerLayer _workerLayer;
  late ActivityLayer _activityLayer;
  late TrailLayer _trailLayer;
  late BreachLayer _breachLayer;
  late CommandCenterCameraController _cameraController;

  StreamSubscription? _stateSubscription;
  CommandCenterState? _previousState;

  CommandCenterController({required this.mapController, required this.bloc}) {
    _initialize();
  }

  void _initialize() async {
    // Initialize layers
    _territoryLayer = TerritoryLayer(mapController: mapController);
    _workerLayer = WorkerLayer(mapController: mapController);
    _activityLayer = ActivityLayer(mapController: mapController);
    _trailLayer = TrailLayer(mapController: mapController);
    _breachLayer = BreachLayer(mapController: mapController);
    _cameraController = CommandCenterCameraController(
      mapController: mapController,
    );

    await _territoryLayer.initialize();
    await _workerLayer.initialize();
    await _activityLayer.initialize();
    await _trailLayer.initialize();
    await _breachLayer.initialize();

    // Listen to state changes
    _stateSubscription = bloc.stream.listen(_handleStateChange);
  }

  Future<void> handleMapTap(dynamic context) async {
    final Point? tapPoint = switch (context) {
      Point p => p,
      _ => () {
        try {
          final dynamic maybePoint = (context as dynamic).point;
          return maybePoint is Point ? maybePoint : null;
        } catch (_) {
          return null;
        }
      }(),
    };

    if (tapPoint == null) return;

    final territories = bloc.state.territories;
    if (territories.isEmpty) return;

    // 1. Check if tap is near any territory marker/centroid
    for (final territory in territories) {
      final annotations = _territoryLayer.getRegisteredAnnotations(
        territory.id,
      );
      for (final annotation in annotations) {
        if (annotation is CircleAnnotation) {
          final distance = _calculateDistance(
            tapPoint.coordinates.lat.toDouble(),
            tapPoint.coordinates.lng.toDouble(),
            annotation.geometry.coordinates.lat.toDouble(),
            annotation.geometry.coordinates.lng.toDouble(),
          );

          // Threshold for "near" marker (adjust based on zoom if needed)
          if (distance < 0.005) {
            bloc.add(SelectTerritoryEvent(territoryId: territory.id));
            return;
          }
        }
      }
    }

    // 2. Fallback: Check if point is inside any polygon (using basic hit testing)
    // For now, marker-based tapping is most reliable with annotations
  }

  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = lat2 - lat1;
    final dLng = lng2 - lng1;
    return (dLat * dLat +
        dLng * dLng); // squared distance is enough for comparison
  }

  void _handleStateChange(CommandCenterState state) {
    final previous = _previousState;

    // Clear layers when toggled off
    if (previous != null) {
      if (previous.showTerritories && !state.showTerritories) {
        _territoryLayer.clear();
      }
      if (previous.showWorkers && !state.showWorkers) {
        _workerLayer.clear();
      }
      if (previous.showActivities && !state.showActivities) {
        _activityLayer.clear();
      }
    }

    // Update territories if changed
    if ((state.territories != previous?.territories ||
            state.selectedTerritoryId != previous?.selectedTerritoryId ||
            (previous?.showTerritories == false && state.showTerritories)) &&
        state.showTerritories) {
      _territoryLayer.updateTerritories(
        state.territories,
        selectedId: state.selectedTerritoryId,
      );
    }

    // Update workers if changed or visibility toggled
    if ((state.liveLocations != previous?.liveLocations ||
            state.showWorkers != previous?.showWorkers) &&
        state.showWorkers) {
      _workerLayer.updateWorkers(state.workers, state.liveLocations);
    }

    // Update activities if changed
    if ((state.donations != previous?.donations ||
            state.prayerRequests != previous?.prayerRequests ||
            state.showActivities != previous?.showActivities) &&
        state.showActivities) {
      _activityLayer.updateActivities(state.donations, state.prayerRequests);
    }

    // Update trails if changed
    if ((state.workerPaths != previous?.workerPaths ||
            state.showTrails != previous?.showTrails) &&
        state.showTrails) {
      _trailLayer.updateTrails(state.workerPaths);
    }

    // Update breaches
    if (state.breachedWorkerIds != previous?.breachedWorkerIds) {
      _breachLayer.updateBreaches(state.breachedWorkerIds, state.liveLocations);
    }

    // Handle camera changes
    _handleCameraChanges(state, previous);

    // Auto-fit if data just loaded for the first time
    if (state.mapMode == MapMode.overview &&
        previous != null &&
        previous.isLoading &&
        !state.isLoading &&
        (state.territories.isNotEmpty ||
            state.donations.isNotEmpty ||
            state.prayerRequests.isNotEmpty)) {
      final bounds = BoundsCalculator.calculateOverviewBounds(state);
      _cameraController.fitToBounds(bounds, priority: CameraPriority.autoFit);
    }

    _previousState = state;
  }

  void _handleCameraChanges(
    CommandCenterState state,
    CommandCenterState? previous,
  ) {
    // Follow mode
    if (state.followTarget != previous?.followTarget) {
      if (state.followTarget != null &&
          state.liveLocations.containsKey(state.followTarget)) {
        final position = state.liveLocations[state.followTarget]!;
        _cameraController.follow(position.latitude, position.longitude);
      } else {
        _cameraController.stopFollow();
      }
    }

    // Territory selection
    if (state.selectedTerritoryId != previous?.selectedTerritoryId &&
        state.selectedTerritoryId != null) {
      final territory = state.territories.firstWhere(
        (t) => t.id == state.selectedTerritoryId,
        orElse: () => state.territories.first,
      );
      final bounds = BoundsCalculator.fromTerritories([territory]);
      _cameraController.fitToBounds(bounds);
    }

    // Auto-fit on mode change
    if (state.mapMode != previous?.mapMode) {
      switch (state.mapMode) {
        case MapMode.overview:
          final bounds = BoundsCalculator.calculateOverviewBounds(state);
          _cameraController.fitToBounds(
            bounds,
            priority: CameraPriority.autoFit,
          );
          break;
        case MapMode.workers:
          if (state.liveLocations.isNotEmpty) {
            final bounds = BoundsCalculator.fromPositions(
              state.liveLocations.values,
            );
            _cameraController.fitToBounds(
              bounds,
              priority: CameraPriority.autoFit,
            );
          }
          break;
        case MapMode.territories:
          if (state.territories.isNotEmpty) {
            final bounds = BoundsCalculator.fromTerritories(state.territories);
            _cameraController.fitToBounds(
              bounds,
              priority: CameraPriority.autoFit,
            );
          }
          break;
      }
    }
  }

  void dispose() {
    _stateSubscription?.cancel();
    _territoryLayer.dispose();
    _workerLayer.dispose();
    _activityLayer.dispose();
    _trailLayer.dispose();
    _breachLayer.dispose();
  }
}
