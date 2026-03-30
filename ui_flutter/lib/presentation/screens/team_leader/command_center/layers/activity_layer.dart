import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:math';
import '../../../../../data/models/donation_model.dart';
import '../../../../../data/models/prayer_request_model.dart';
import '../services/annotation_registry.dart';

class ActivityLayer {
  final MapboxMap mapController;
  final _donationRegistry = AnnotationRegistry<DonationModel>();
  final _prayerRegistry = AnnotationRegistry<PrayerRequestModel>();

  CircleAnnotationManager? _circleManager;

  ActivityLayer({required this.mapController});

  List<ActivityTapTarget> getTapTargets() {
    final targets = <ActivityTapTarget>[];

    for (final id in _donationRegistry.domainIds) {
      final donation = _donationRegistry.getEntity(id);
      final annotations = _donationRegistry.getAnnotations(id);
      for (final a in annotations) {
        if (a is CircleAnnotation) {
          targets.add(
            ActivityTapTarget(
              kind: donation?.donationType == 'book_sale'
                  ? ActivityTapKind.bookSale
                  : ActivityTapKind.donation,
              id: id,
              latitude: a.geometry.coordinates.lat.toDouble(),
              longitude: a.geometry.coordinates.lng.toDouble(),
            ),
          );
        }
      }
    }

    for (final id in _prayerRegistry.domainIds) {
      final annotations = _prayerRegistry.getAnnotations(id);
      for (final a in annotations) {
        if (a is CircleAnnotation) {
          targets.add(
            ActivityTapTarget(
              kind: ActivityTapKind.prayer,
              id: id,
              latitude: a.geometry.coordinates.lat.toDouble(),
              longitude: a.geometry.coordinates.lng.toDouble(),
            ),
          );
        }
      }
    }

    return targets;
  }

  Future<void> initialize() async {
    try {
      _circleManager = await mapController.annotations
          .createCircleAnnotationManager();
    } catch (e) {
      debugPrint('Error initializing activity layer: $e');
    }
  }

  Future<void> updateActivities(
    List<DonationModel> donations,
    List<PrayerRequestModel> prayers,
  ) async {
    if (_circleManager == null) return;

    // Handle donations
    final donationIds = donations.map((d) => d.id).toSet();
    final Map<String, dynamic> donationDiff = _donationRegistry.diff(
      donationIds,
      donations.asMap().map((_, d) => MapEntry(d.id, d)),
    );

    // Handle prayers
    final prayerIds = prayers.map((p) => p.id).toSet();
    final Map<String, dynamic> prayerDiff = _prayerRegistry.diff(
      prayerIds,
      prayers.asMap().map((_, p) => MapEntry(p.id, p)),
    );

    // Remove old annotations
    final List<dynamic> toRemove = [
      ...((donationDiff['removed'] as Map? ?? {}).values.expand(
        (r) => r as Iterable<dynamic>,
      )),
      ...((prayerDiff['removed'] as Map? ?? {}).values.expand(
        (r) => r as Iterable<dynamic>,
      )),
    ];

    if (toRemove.isNotEmpty) {
      for (final annotation in toRemove) {
        if (annotation is CircleAnnotation) {
          await _circleManager?.delete(annotation);
        }
      }
    }

    // Add new annotations
    final circlesToAdd = <CircleAnnotationOptions>[];
    final donationsToRegister = <MapEntry<DonationModel, int>>[];
    final prayersToRegister = <MapEntry<PrayerRequestModel, int>>[];

    final addedOrUpdatedIds = [
      ...(donationDiff['added'] as List? ?? []),
      ...(donationDiff['updated'] as List? ?? []),
    ].cast<String>();

    // Render normal donations first and book sales after, so book markers stay visible on overlap.
    final orderedDonationIds = [
      ...addedOrUpdatedIds.where((id) {
        final d = donations.where((e) => e.id == id).firstOrNull;
        return d?.donationType != 'book_sale';
      }),
      ...addedOrUpdatedIds.where((id) {
        final d = donations.where((e) => e.id == id).firstOrNull;
        return d?.donationType == 'book_sale';
      }),
    ];

    final occupiedCoordinateCount = <String, int>{};

    // Add donation markers
    for (final id in orderedDonationIds) {
      final donationModel = donations.where((d) => d.id == id).firstOrNull;
      if (donationModel != null &&
          donationModel.latitude != null &&
          donationModel.longitude != null) {
        donationsToRegister.add(MapEntry(donationModel, circlesToAdd.length));
        final isBookSale = donationModel.donationType == 'book_sale';
        final adjusted = _adjustMarkerPosition(
          donationModel.latitude!,
          donationModel.longitude!,
          occupiedCoordinateCount,
        );
        circlesToAdd.add(
          CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                adjusted.$2,
                adjusted.$1,
              ),
            ),
            circleColor: (isBookSale
                    ? const Color(0xFFF59E0B) // amber for book sales
                    : const Color(0xFF10B981))
                .toARGB32(),
            circleRadius: 12.0,
            circleStrokeColor: const Color(0xFFFFFFFF).toARGB32(),
            circleStrokeWidth: 3.0,
          ),
        );
      }
    }

    // Add prayer markers
    for (final id in [
      ...(prayerDiff['added'] as List? ?? []),
      ...(prayerDiff['updated'] as List? ?? []),
    ]) {
      final prayerModel = prayers.where((p) => p.id == id).firstOrNull;
      if (prayerModel != null &&
          prayerModel.latitude != null &&
          prayerModel.longitude != null) {
        prayersToRegister.add(MapEntry(prayerModel, circlesToAdd.length));
        circlesToAdd.add(
          CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                prayerModel.longitude!,
                prayerModel.latitude!,
              ),
            ),
            circleColor: const Color(0xFF6366F1).toARGB32(), // Indigo 500
            circleRadius: 12.0,
            circleStrokeColor: const Color(0xFFFFFFFF).toARGB32(),
            circleStrokeWidth: 3.0,
          ),
        );
      }
    }

    if (circlesToAdd.isNotEmpty) {
      final circles = await _circleManager!.createMulti(circlesToAdd);

      // Register donations
      for (final entry in donationsToRegister) {
        final circle = circles[entry.value];
        if (circle != null) {
          _donationRegistry.register(
            entry.key.id,
            entry.key,
            [circle.id],
            [circle],
          );
        }
      }

      // Register prayers
      for (final entry in prayersToRegister) {
        final circle = circles[entry.value];
        if (circle != null) {
          _prayerRegistry.register(
            entry.key.id,
            entry.key,
            [circle.id],
            [circle],
          );
        }
      }
    }
  }

  Future<void> clear() async {
    if (_circleManager == null) return;
    await _circleManager!.deleteAll();
    _donationRegistry.clear();
    _prayerRegistry.clear();
  }

  void dispose() {
    _circleManager = null;
  }

  /// Slightly offsets overlapping markers so all activities remain visible.
  /// Returns (lat, lng).
  (double, double) _adjustMarkerPosition(
    double latitude,
    double longitude,
    Map<String, int> occupied,
  ) {
    final key =
        '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    final index = occupied[key] ?? 0;
    occupied[key] = index + 1;

    if (index == 0) return (latitude, longitude);

    const step = 0.00045; // ~50m
    final ring = ((index - 1) ~/ 8) + 1;
    final angleDeg = (index - 1) % 8 * 45.0;
    final angle = angleDeg * 3.141592653589793 / 180.0;
    final latOffset = ring * step * sin(angle);
    final lngOffset = ring * step * cos(angle);

    return (latitude + latOffset, longitude + lngOffset);
  }
}

enum ActivityTapKind { donation, bookSale, prayer }

class ActivityTapTarget {
  final ActivityTapKind kind;
  final String id;
  final double latitude;
  final double longitude;

  const ActivityTapTarget({
    required this.kind,
    required this.id,
    required this.latitude,
    required this.longitude,
  });
}
