import 'dart:async';
import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
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
  final mapbox.MapboxMap mapController;
  final CommandCenterBloc bloc;

  late TerritoryLayer _territoryLayer;
  late WorkerLayer _workerLayer;
  late ActivityLayer _activityLayer;
  late TrailLayer _trailLayer;
  late BreachLayer _breachLayer;
  late CommandCenterCameraController _cameraController;

  StreamSubscription? _stateSubscription;
  CommandCenterState? _previousState;

  Future<void> _stateQueue = Future.value();

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
    _stateSubscription = bloc.stream.listen(_enqueueStateChange);

    // Apply current state immediately in case the bloc emitted updates
    // before the subscription was attached (during async layer init).
    _enqueueStateChange(bloc.state);
  }

  void _enqueueStateChange(CommandCenterState state) {
    _stateQueue = _stateQueue.then((_) => _handleStateChange(state));
  }

  Future<void> handleMapTap(dynamic context) async {
    final mapbox.Point? tapPoint = switch (context) {
      mapbox.Point p => p,
      _ => () {
        try {
          final dynamic maybePoint = (context as dynamic).point;
          return maybePoint is mapbox.Point ? maybePoint : null;
        } catch (_) {
          return null;
        }
      }(),
    };

    if (tapPoint == null) return;

    final double geoThreshold = await _getAdaptiveGeoThreshold();
    final _Pixel? tapPixel = await _pixelForPoint(tapPoint);

    // 0. Check if tap is near any activity marker (donations/prayers)
    final activityTargets = _activityLayer.getTapTargets();
    ActivityTapTarget? closestActivity;
    var closestActivityDist = double.infinity;
    var closestActivityPxDist = double.infinity;
    for (final t in activityTargets) {
      if (tapPixel != null) {
        final px = await _pixelForLatLng(t.latitude, t.longitude);
        if (px != null) {
          final d = _pixelDistance(tapPixel, px);
          if (d < closestActivityPxDist) {
            closestActivityPxDist = d;
            closestActivity = t;
          }
          continue;
        }
      }

      final d = _calculateDistance(
        tapPoint.coordinates.lat.toDouble(),
        tapPoint.coordinates.lng.toDouble(),
        t.latitude,
        t.longitude,
      );
      if (d < closestActivityDist) {
        closestActivityDist = d;
        closestActivity = t;
      }
    }
    final bool activityHit = tapPixel != null
        ? closestActivity != null && closestActivityPxDist < 32.0
        : closestActivity != null &&
              closestActivityDist < (geoThreshold * geoThreshold);
    if (activityHit) {
      final kind = switch (closestActivity.kind) {
        ActivityTapKind.donation => MapPopupKind.activityDonation,
        ActivityTapKind.bookSale => MapPopupKind.activityBookSale,
        ActivityTapKind.prayer => MapPopupKind.activityPrayer,
      };
      bloc.add(
        ShowMapPopupEvent(
          popup: MapPopup(
            kind: kind,
            id: closestActivity.id,
            latitude: closestActivity.latitude,
            longitude: closestActivity.longitude,
          ),
        ),
      );
      return;
    }

    final territories = bloc.state.territories;
    if (territories.isEmpty) {
      bloc.add(HideMapPopupEvent());
      return;
    }

    // 1. Check if tap is near any territory marker/centroid
    for (final territory in territories) {
      final annotations = _territoryLayer.getRegisteredAnnotations(
        territory.id,
      );
      for (final annotation in annotations) {
        if (annotation is mapbox.CircleAnnotation) {
          final double markerLat = annotation.geometry.coordinates.lat
              .toDouble();
          final double markerLng = annotation.geometry.coordinates.lng
              .toDouble();

          bool hit = false;
          if (tapPixel != null) {
            final px = await _pixelForLatLng(markerLat, markerLng);
            if (px != null) {
              hit = _pixelDistance(tapPixel, px) < 32.0;
            }
          }

          if (!hit) {
            final distance = _calculateDistance(
              tapPoint.coordinates.lat.toDouble(),
              tapPoint.coordinates.lng.toDouble(),
              markerLat,
              markerLng,
            );
            hit = distance < (geoThreshold * geoThreshold);
          }

          if (hit) {
            bloc.add(
              ShowMapPopupEvent(
                popup: MapPopup(
                  kind: MapPopupKind.territory,
                  id: territory.id,
                  latitude: markerLat,
                  longitude: markerLng,
                ),
              ),
            );
            return;
          }
        }
      }
    }

    bloc.add(HideMapPopupEvent());

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

  Future<_Pixel?> _pixelForPoint(mapbox.Point p) async {
    try {
      final dynamic dyn = mapController;
      final dynamic px = await dyn.pixelForCoordinate(p);
      final dx = (px as dynamic).x as num?;
      final dy = (px as dynamic).y as num?;
      if (dx == null || dy == null) return null;
      return _Pixel(dx.toDouble(), dy.toDouble());
    } catch (_) {
      return null;
    }
  }

  Future<_Pixel?> _pixelForLatLng(double lat, double lng) async {
    return _pixelForPoint(mapbox.Point(coordinates: mapbox.Position(lng, lat)));
  }

  double _pixelDistance(_Pixel a, _Pixel b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  Future<double> _getAdaptiveGeoThreshold() async {
    try {
      final zoom = await mapController.getCameraState().then((s) => s.zoom);
      final z = zoom.toDouble();
      const base = 0.005;
      final scaled = base * pow(2.0, (10.0 - z));
      if (scaled < base) return base;
      if (scaled > 0.25) return 0.25;
      return scaled;
    } catch (_) {
      return 0.005;
    }
  }

  Future<void> _handleStateChange(CommandCenterState state) async {
    final previous = _previousState;

    // Clear layers when toggled off
    if (previous != null) {
      if (previous.showTerritories && !state.showTerritories) {
        await _territoryLayer.clear();
      }
      if (previous.showWorkers && !state.showWorkers) {
        await _workerLayer.clear();
      }
      if (previous.showActivities && !state.showActivities) {
        await _activityLayer.clear();
      }
      if (previous.showTrails && !state.showTrails) {
        await _trailLayer.clear();
      }
    }

    // Update territories if changed
    if ((state.territories != previous?.territories ||
            state.selectedTerritoryId != previous?.selectedTerritoryId ||
            (previous?.showTerritories == false && state.showTerritories)) &&
        state.showTerritories) {
      await _territoryLayer.updateTerritories(
        state.territories,
        selectedId: state.selectedTerritoryId,
      );
    }

    // Update workers if changed or visibility toggled
    if ((state.liveLocations != previous?.liveLocations ||
            state.showWorkers != previous?.showWorkers) &&
        state.showWorkers) {
      await _workerLayer.updateWorkers(state.workers, state.liveLocations);
    }

    // Update activities if changed
    if ((state.donations != previous?.donations ||
            state.prayerRequests != previous?.prayerRequests ||
            state.showActivities != previous?.showActivities) &&
        state.showActivities) {
      await _activityLayer.updateActivities(
        state.donations,
        state.prayerRequests,
      );
    }

    if (previous != null && previous.showActivities && !state.showActivities) {
      await _activityLayer.clear();
    }

    // Update trails if changed
    if ((state.workerPaths != previous?.workerPaths ||
            state.showTrails != previous?.showTrails) &&
        state.showTrails) {
      await _trailLayer.updateTrails(state.workerPaths);
    }

    // Update breaches
    if (state.breachedWorkerIds != previous?.breachedWorkerIds) {
      await _breachLayer.updateBreaches(
        state.breachedWorkerIds,
        state.liveLocations,
      );
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
    final followId = state.followTarget;
    if (followId != null) {
      final pos = state.liveLocations[followId];
      final prevPos = previous?.liveLocations[followId];

      // Start follow when target changes and we have any location (GPS live or last-known entry)
      if (followId != previous?.followTarget) {
        if (pos != null) {
          _cameraController.follow(
            pos.latitude,
            pos.longitude,
            workerId: followId,
          );
        }
      } else {
        // While following, keep camera updated when position changes (e.g. websocket updates)
        if (pos != null && pos != prevPos) {
          _cameraController.updateFollowPosition(pos.latitude, pos.longitude);
        }
      }
    } else {
      if (previous?.followTarget != null) {
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

class _Pixel {
  final double x;
  final double y;

  const _Pixel(this.x, this.y);
}
