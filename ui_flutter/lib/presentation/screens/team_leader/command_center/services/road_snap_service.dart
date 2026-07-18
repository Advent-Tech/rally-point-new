import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../../../core/constants/map_constants.dart';
import '../command_center_state.dart' as cc;

/// Snaps raw GPS positions to road geometry via Mapbox APIs.
/// - `snapPath`: batch snaps a full trail via Map Matching API
/// - `snapPoint`: snaps a single point to nearest road via Directions API
class RoadSnapService {
  final Dio _dio;

  // Per-worker snap cache to avoid redundant API calls
  final Map<String, _SnapCache> _cache = {};

  RoadSnapService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.mapbox.com',
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  /// Snaps a single GPS point to the nearest road using Mapbox Directions API.
  /// Returns the snapped position, or null if snapping fails.
  /// [context] is a list of recent positions (last 3-5) for better snap direction.
  Future<cc.Position?> snapPoint(
    cc.Position raw, {
    List<cc.Position>? context,
  }) async {
    final cacheKey = '${raw.latitude.toStringAsFixed(5)},${raw.longitude.toStringAsFixed(5)}';

    // Check cache: skip if same position within 5m
    final cached = _cache[cacheKey];
    if (cached != null) {
      final age = DateTime.now().difference(cached.timestamp);
      if (age < const Duration(seconds: 10)) {
        return cached.position;
      }
    }

    try {
      // Build coordinate string: if we have context, use first→last for bearing
      final coords = context != null && context.length >= 2
          ? '${context.first.longitude},${context.first.latitude};${raw.longitude},${raw.latitude}'
          : '${raw.longitude},${raw.latitude}';

      final queryParams = <String, dynamic>{
        'geometries': 'geojson',
        'overview': 'full',
        'steps': false,
        'access_token': MapConstants.mapboxAccessToken,
      };

      // Add radius: 50m tolerance for road snapping
      if (context != null && context.length >= 2) {
        queryParams['radiuses'] = '50;50';
      } else {
        queryParams['radiuses'] = '50';
      }

      final response = await _dio.get(
        '/directions/v5/mapbox/driving/$coords',
        queryParameters: queryParams,
      );

      if (response.statusCode != 200 || response.data is! Map) return null;

      final data = response.data as Map;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map;
      final geometry = route['geometry'] as Map?;
      if (geometry == null) return null;

      final coordinates = geometry['coordinates'] as List?;
      if (coordinates == null || coordinates.isEmpty) return null;

      // Find the closest point on the route to our raw position
      cc.Position? bestSnap;
      double bestDist = double.infinity;

      for (final c in coordinates) {
        if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
          final point = cc.Position(
            latitude: (c[1] as num).toDouble(),
            longitude: (c[0] as num).toDouble(),
          );
          final dist = _haversineMeters(
            raw.latitude,
            raw.longitude,
            point.latitude,
            point.longitude,
          );
          if (dist < bestDist) {
            bestDist = dist;
            bestSnap = point;
          }
        }
      }

      // Only snap if within 80m of a road (avoid snapping to far roads)
      if (bestSnap != null && bestDist <= 80) {
        _cache[cacheKey] = _SnapCache(position: bestSnap, timestamp: DateTime.now());
        return bestSnap;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<cc.Position>?> snapPath(List<cc.Position> rawPath) async {
    if (rawPath.length < 3) return null;

    try {
      final sampled = _sampleForMatching(rawPath, maxPoints: 80);
      if (sampled.length < 3) return null;

      final coordString = sampled
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');

      final response = await _dio.get(
        '/matching/v5/mapbox/driving/$coordString',
        queryParameters: <String, dynamic>{
          'geometries': 'geojson',
          'overview': 'full',
          'steps': false,
          'radiuses': List.filled(sampled.length, 30).join(';'),
          'tidy': true,
          'access_token': MapConstants.mapboxAccessToken,
        },
      );

      if (response.statusCode != 200 || response.data is! Map) return null;
      final data = response.data as Map;
      final matchings = data['matchings'];
      if (matchings is! List || matchings.isEmpty) return null;

      final first = matchings.first;
      if (first is! Map) return null;
      final geometry = first['geometry'];
      if (geometry is! Map) return null;
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) return null;

      final snapped = <cc.Position>[];
      for (final c in coordinates) {
        if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
          snapped.add(
            cc.Position(
              latitude: (c[1] as num).toDouble(),
              longitude: (c[0] as num).toDouble(),
            ),
          );
        }
      }

      if (snapped.length < 2) return null;
      return snapped;
    } catch (_) {
      return null;
    }
  }

  List<cc.Position> _sampleForMatching(
    List<cc.Position> path, {
    required int maxPoints,
  }) {
    if (path.length <= maxPoints) return path;
    final stride = path.length / maxPoints;
    final sampled = <cc.Position>[];
    double i = 0;
    while (i < path.length) {
      sampled.add(path[i.floor()]);
      i += stride;
    }
    if (sampled.last != path.last) {
      sampled.add(path.last);
    }
    return sampled;
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  void dispose() {
    _cache.clear();
  }
}

class _SnapCache {
  final cc.Position position;
  final DateTime timestamp;

  const _SnapCache({required this.position, required this.timestamp});
}

