import '../../../../../data/models/territory_model.dart';
import '../command_center_state.dart';

class GeofenceChecker {
  /// Check if a position is inside any territory using point-in-polygon
  static bool isInsideTerritory(
    Position position,
    List<GeoTerritory> territories,
  ) {
    for (final territory in territories) {
      if (_isPointInPolygon(position, territory)) {
        return true;
      }
    }
    return false;
  }

  /// Check which workers are outside their assigned territories
  static Set<String> checkBreaches(
    Map<String, Position> workerLocations,
    Map<String, List<String>> workerTerritoryAssignments,
    List<GeoTerritory> territories,
  ) {
    final breachedWorkers = <String>{};

    for (final entry in workerLocations.entries) {
      final workerId = entry.key;
      final position = entry.value;

      // Get assigned territories for this worker
      final assignedTerritoryIds = workerTerritoryAssignments[workerId] ?? [];
      final assignedTerritories = territories
          .where((t) => assignedTerritoryIds.contains(t.id))
          .toList();

      // If worker has assigned territories but is not in any of them
      if (assignedTerritories.isNotEmpty &&
          !isInsideTerritory(position, assignedTerritories)) {
        breachedWorkers.add(workerId);
      }
    }

    return breachedWorkers;
  }

  /// Point-in-polygon algorithm using ray casting
  static bool _isPointInPolygon(Position point, GeoTerritory territory) {
    final geometry = territory.geometry;
    if (geometry == null) return false;

    if (geometry['type'] == 'Polygon') {
      final coordinates = (geometry['coordinates'] as List?)?.first as List?;
      if (coordinates != null) {
        return _checkPolygon(point, coordinates);
      }
    } else if (geometry['type'] == 'MultiPolygon') {
      final polygons = geometry['coordinates'] as List?;
      if (polygons != null) {
        for (final polygon in polygons) {
          final coordinates = (polygon as List?)?.first as List?;
          if (coordinates != null && _checkPolygon(point, coordinates)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  static bool _checkPolygon(Position point, List coordinates) {
    bool inside = false;

    int j = coordinates.length - 1;
    for (int i = 0; i < coordinates.length; j = i++) {
      final xi = (coordinates[i]?[0] as num?)?.toDouble();
      final yi = (coordinates[i]?[1] as num?)?.toDouble();
      final xj = (coordinates[j]?[0] as num?)?.toDouble();
      final yj = (coordinates[j]?[1] as num?)?.toDouble();

      if (xi != null && yi != null && xj != null && yj != null) {
        final intersect =
            ((yi > point.latitude) != (yj > point.latitude)) &&
            (point.longitude <
                (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);

        if (intersect) {
          inside = !inside;
        }
      }
    }

    return inside;
  }
}
