/// Registry for tracking Mapbox annotation IDs by domain entities
class AnnotationRegistry<T> {
  final Map<String, T> _entities = {};
  final Map<String, List<String>> _annotationIds = {};
  final Map<String, dynamic> _annotationObjects = {};

  /// Register an entity with its annotation IDs and objects
  void register(
    String domainId,
    T entity,
    List<String> annotationIds,
    List<dynamic> annotations,
  ) {
    _entities[domainId] = entity;
    _annotationIds[domainId] = annotationIds;
    _annotationObjects[domainId] = annotations;
  }

  /// Get annotation objects for a domain entity
  List<dynamic> getAnnotations(String domainId) {
    return _annotationObjects[domainId] as List<dynamic>? ?? [];
  }

  /// Get annotation IDs for a domain entity
  List<String> getAnnotationIds(String domainId) {
    return _annotationIds[domainId] ?? [];
  }

  // Calculate diff between current and new state
  Map<String, dynamic> diff(Set<String> newIds, Map<String, T> newEntities) {
    final currentIds = _entities.keys.toSet();

    final List<String> added = newIds
        .difference(currentIds)
        .where((id) => newEntities.containsKey(id))
        .toList();

    final List<String> updated = newIds
        .intersection(currentIds)
        .where(
          (id) =>
              newEntities.containsKey(id) && _entities[id] != newEntities[id],
        )
        .toList();

    final Map<String, List<dynamic>> removed = currentIds
        .difference(newIds)
        .fold<Map<String, List<dynamic>>>({}, (acc, id) {
          acc[id] = _annotationObjects[id] as List<dynamic>? ?? [];
          return acc;
        });

    // Clean up removed entries
    for (final id in removed.keys) {
      _entities.remove(id);
      _annotationIds.remove(id);
      _annotationObjects.remove(id);
    }

    return {'added': added, 'updated': updated, 'removed': removed};
  }

  /// Clear all registrations
  void clear() {
    _entities.clear();
    _annotationIds.clear();
    _annotationObjects.clear();
  }
}
