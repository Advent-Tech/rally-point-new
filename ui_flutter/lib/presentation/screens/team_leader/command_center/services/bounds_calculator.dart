import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../../data/models/territory_model.dart';
import '../command_center_state.dart' as cc_state;

class BoundsCalculator {
  /// Calculate bounds from a list of territories
  static CoordinateBounds fromTerritories(List<GeoTerritory> territories) {
    if (territories.isEmpty) {
      // Default US bounds
      return CoordinateBounds(
        southwest: Point(coordinates: Position(-125.0, 24.0)),
        northeast: Point(coordinates: Position(-66.0, 49.0)),
        infiniteBounds: false,
      );
    }

    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;

    for (final territory in territories) {
      final geometry = territory.geometry;
      if (geometry == null) continue;

      if (geometry['type'] == 'Polygon') {
        final coordinates = (geometry['coordinates'] as List?)?.first as List?;

        if (coordinates != null) {
          for (final coord in coordinates) {
            final coordList = coord as List?;
            final lng = (coordList?[0] as num?)?.toDouble();
            final lat = (coordList?[1] as num?)?.toDouble();

            if (lng != null && lat != null) {
              minLat = lat < minLat ? lat : minLat;
              maxLat = lat > maxLat ? lat : maxLat;
              minLng = lng < minLng ? lng : minLng;
              maxLng = lng > maxLng ? lng : maxLng;
            }
          }
        }
      } else if (geometry['type'] == 'MultiPolygon') {
        final polygons = geometry['coordinates'] as List?;

        if (polygons != null) {
          for (final polygon in polygons) {
            final coordinates = (polygon as List?)?.first as List?;

            if (coordinates != null) {
              for (final coord in coordinates) {
                final coordList = coord as List?;
                final lng = (coordList?[0] as num?)?.toDouble();
                final lat = (coordList?[1] as num?)?.toDouble();

                if (lng != null && lat != null) {
                  minLat = lat < minLat ? lat : minLat;
                  maxLat = lat > maxLat ? lat : maxLat;
                  minLng = lng < minLng ? lng : minLng;
                  maxLng = lng > maxLng ? lng : maxLng;
                }
              }
            }
          }
        }
      }
    }

    // Add padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    return CoordinateBounds(
      southwest: Point(
        coordinates: Position(minLng - lngPadding, minLat - latPadding),
      ),
      northeast: Point(
        coordinates: Position(maxLng + lngPadding, maxLat + latPadding),
      ),
      infiniteBounds: false,
    );
  }

  /// Calculate unified bounds for territories and activities
  static CoordinateBounds calculateOverviewBounds(
    cc_state.CommandCenterState state,
  ) {
    List<double> latitudes = [];
    List<double> longitudes = [];

    // Helper to add valid coordinates only
    void addCoord(double? lat, double? lng) {
      if (lat == null || lng == null) return;
      // Filter out invalid/zero coordinates that skew bounds
      if (lat == 0 && lng == 0) return;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;

      latitudes.add(lat);
      longitudes.add(lng);
    }

    // Extract from territories
    for (final territory in state.territories) {
      final geometry = territory.geometry;
      if (geometry == null) continue;

      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'];

      if (coordinates is List) {
        if (type == 'Polygon') {
          for (final ring in coordinates) {
            if (ring is List) {
              for (final coord in ring) {
                final c = coord as List;
                addCoord((c[1] as num).toDouble(), (c[0] as num).toDouble());
              }
            }
          }
        } else if (type == 'MultiPolygon') {
          for (final polygon in coordinates) {
            if (polygon is List) {
              for (final ring in polygon) {
                if (ring is List) {
                  for (final coord in ring) {
                    final c = coord as List;
                    addCoord(
                      (c[1] as num).toDouble(),
                      (c[0] as num).toDouble(),
                    );
                  }
                }
              }
            }
          }
        }
      }
    }

    // Extract from donations
    for (final donation in state.donations) {
      addCoord(donation.latitude, donation.longitude);
    }

    // Extract from prayer requests
    for (final prayer in state.prayerRequests) {
      addCoord(prayer.latitude, prayer.longitude);
    }

    if (latitudes.isEmpty || longitudes.isEmpty) {
      // Default US bounds if no data
      return CoordinateBounds(
        southwest: Point(coordinates: Position(-125.0, 24.0)),
        northeast: Point(coordinates: Position(-66.0, 49.0)),
        infiniteBounds: false,
      );
    }

    // HANDLE GLOBAL SPREAD (e.g. US vs India)
    // Identify the best cluster to focus on if data is spread globally.
    double minLat, maxLat, minLng, maxLng;

    final rawMinLng = longitudes.reduce((a, b) => a < b ? a : b);
    final rawMaxLng = longitudes.reduce((a, b) => a > b ? a : b);
    final lngSpread = (rawMaxLng - rawMinLng).abs();

    if (lngSpread > 120) {
      // Data is likely across hemispheres (e.g., US ~ -100, India ~ +80)
      // Count points in Western vs Eastern hemispheres
      final westernLats = <double>[];
      final westernLngs = <double>[];
      final easternLats = <double>[];
      final easternLngs = <double>[];

      for (int i = 0; i < longitudes.length; i++) {
        if (longitudes[i] < 0) {
          westernLats.add(latitudes[i]);
          westernLngs.add(longitudes[i]);
        } else {
          easternLats.add(latitudes[i]);
          easternLngs.add(longitudes[i]);
        }
      }

      List<double> focusLats;
      List<double> focusLngs;

      if (westernLats.length >= easternLats.length) {
        focusLats = westernLats;
        focusLngs = westernLngs;
      } else {
        focusLats = easternLats;
        focusLngs = easternLngs;
      }

      minLat = focusLats.reduce((a, b) => a < b ? a : b);
      maxLat = focusLats.reduce((a, b) => a > b ? a : b);
      minLng = focusLngs.reduce((a, b) => a < b ? a : b);
      maxLng = focusLngs.reduce((a, b) => a > b ? a : b);
    } else {
      // Data is relatively local
      minLat = latitudes.reduce((a, b) => a < b ? a : b);
      maxLat = latitudes.reduce((a, b) => a > b ? a : b);
      minLng = longitudes.reduce((a, b) => a < b ? a : b);
      maxLng = longitudes.reduce((a, b) => a > b ? a : b);
    }

    // Ensure a minimum spread so it doesn't zoom into a single point (infinite zoom)
    const minSpread = 0.02; // Roughly 2km
    if (maxLat - minLat < minSpread) {
      final center = (maxLat + minLat) / 2;
      minLat = center - (minSpread / 2);
      maxLat = center + (minSpread / 2);
    }
    if (maxLng - minLng < minSpread) {
      final center = (maxLng + minLng) / 2;
      minLng = center - (minSpread / 2);
      maxLng = center + (minSpread / 2);
    }

    // Dynamic padding: use less padding if spread is larger to avoid massive empty space
    final paddingFactor = (maxLng - minLng) > 5 ? 0.05 : 0.15;
    final latPadding = (maxLat - minLat).abs() * paddingFactor;
    final lngPadding = (maxLng - minLng).abs() * paddingFactor;

    return CoordinateBounds(
      southwest: Point(
        coordinates: Position(minLng - lngPadding, minLat - latPadding),
      ),
      northeast: Point(
        coordinates: Position(maxLng + lngPadding, maxLat + latPadding),
      ),
      infiniteBounds: false,
    );
  }
}
