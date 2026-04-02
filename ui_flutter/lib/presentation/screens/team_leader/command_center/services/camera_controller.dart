import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

enum CameraPriority {
  idle, // Default, user can control
  autoFit, // Auto-fit to bounds
  selection, // Territory/worker selected
  follow, // Following a worker
  userGesture, // User is actively interacting
}

class CommandCenterCameraController {
  final MapboxMap mapController;

  CameraPriority _currentPriority = CameraPriority.idle;
  Timer? _followTimer;
  double? _followLatitude;
  double? _followLongitude;

  CommandCenterCameraController({required this.mapController});

  /// Move camera to a specific location with priority check
  Future<void> easeTo({
    required double latitude,
    required double longitude,
    double? zoom,
    CameraPriority priority = CameraPriority.selection,
  }) async {
    if (!_canOverridePriority(priority)) return;

    _currentPriority = priority;

    await mapController.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: zoom ?? await mapController.getCameraState().then((s) => s.zoom),
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  /// Fit camera to bounds with priority check
  Future<void> fitToBounds(
    CoordinateBounds bounds, {
    CameraPriority priority = CameraPriority.autoFit,
    EdgeInsets padding = const EdgeInsets.all(50),
  }) async {
    if (!_canOverridePriority(priority)) return;

    _currentPriority = priority;

    final camera = await mapController.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(
        top: padding.top,
        left: padding.left,
        bottom: padding.bottom,
        right: padding.right,
      ),
      null, // bearing
      null, // pitch
      null, // maxZoom
      null, // screenRotation
    );

    await mapController.easeTo(camera, MapAnimationOptions(duration: 800));
  }

  /// Start following a worker
  void follow(double latitude, double longitude, {String? workerId}) {
    _currentPriority = CameraPriority.follow;
    _followLatitude = latitude;
    _followLongitude = longitude;

    // Cancel existing follow timer
    _followTimer?.cancel();

    // Initial camera move
    easeTo(
      latitude: latitude,
      longitude: longitude,
      zoom: 16.0,
      priority: CameraPriority.follow,
    );

    // Set up periodic updates
    _followTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_followLatitude == null || _followLongitude == null) return;
      easeTo(
        latitude: _followLatitude!,
        longitude: _followLongitude!,
        priority: CameraPriority.follow,
      );
    });
  }

  void updateFollowPosition(double latitude, double longitude) {
    _followLatitude = latitude;
    _followLongitude = longitude;
    if (_currentPriority == CameraPriority.follow) {
      easeTo(
        latitude: latitude,
        longitude: longitude,
        priority: CameraPriority.follow,
      );
    }
  }

  /// Stop following
  void stopFollow() {
    _followTimer?.cancel();
    _followTimer = null;
    _followLatitude = null;
    _followLongitude = null;
    _currentPriority = CameraPriority.idle;
  }

  /// Check if a new priority can override current
  bool _canOverridePriority(CameraPriority newPriority) {
    // User gesture always wins
    if (newPriority == CameraPriority.userGesture) return true;

    // While following, allow follow updates (same priority) and user gesture.
    if (_currentPriority == CameraPriority.follow) {
      return newPriority == CameraPriority.follow ||
          newPriority == CameraPriority.userGesture;
    }

    // If user is interacting, still allow explicit follow from UI action.
    if (_currentPriority == CameraPriority.userGesture) {
      return newPriority == CameraPriority.follow;
    }

    // Otherwise, higher priority wins
    return newPriority.index >= _currentPriority.index;
  }

  /// Handle user interaction
  void onUserInteraction() {
    if (_currentPriority == CameraPriority.follow) {
      stopFollow();
    }
    _currentPriority = CameraPriority.userGesture;

    // Reset to idle after interaction
    Timer(const Duration(seconds: 3), () {
      if (_currentPriority == CameraPriority.userGesture) {
        _currentPriority = CameraPriority.idle;
      }
    });
  }

  void dispose() {
    _followTimer?.cancel();
  }
}
