import 'package:dio/dio.dart';

import '../../../../../core/constants/map_constants.dart';
import '../command_center_state.dart' as cc;

/// Snaps raw GPS trails to road geometry via Mapbox Map Matching API.
/// Falls back to original points when matching is unavailable.
class RoadSnapService {
  final Dio _dio;

  RoadSnapService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.mapbox.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

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
}

