/// Mapbox configuration constants for native SDK
class MapConstants {
  MapConstants._();

  /// Mapbox public access token (for runtime usage)
  static const String mapboxAccessToken =
      'pk.eyJ1IjoiYWJoaXNoZWticmljaGhhbGl5YSIsImEiOiJjbWpucGt6ZGMwZmpxM2NzZHVzOWMwZ2RsIn0.uvQnSW5RBEroADuX27ZshQ';

  /// Mapbox style URIs for native SDK
  static const String mapboxStyleStreets = 'mapbox://styles/mapbox/streets-v12';
  static const String mapboxStyleOutdoors = 'mapbox://styles/mapbox/outdoors-v12';
  static const String mapboxStyleLight = 'mapbox://styles/mapbox/light-v11';
  static const String mapboxStyleDark = 'mapbox://styles/mapbox/dark-v11';
  static const String mapboxStyleSatellite = 'mapbox://styles/mapbox/satellite-v9';
  static const String mapboxStyleSatelliteStreets = 'mapbox://styles/mapbox/satellite-streets-v12';
  static const String mapboxStyleNavigationDay = 'mapbox://styles/mapbox/navigation-day-v1';
  static const String mapboxStyleNavigationNight = 'mapbox://styles/mapbox/navigation-night-v1';

  /// Get style URI based on theme
  static String getThemedStyleUri(bool isDark) {
    return isDark ? mapboxStyleDark : mapboxStyleStreets;
  }

  /// Default map center (US)
  static const double defaultLatitude = 39.8283;
  static const double defaultLongitude = -98.5795;
  static const double defaultZoom = 4.0;

  /// Zoom levels
  static const double minZoom = 2.0;
  static const double maxZoom = 18.0;
  static const double streetLevelZoom = 16.0;
  static const double neighborhoodZoom = 14.0;
  static const double cityZoom = 12.0;
  static const double regionZoom = 8.0;

  /// Attribution (required by Mapbox ToS - handled automatically by SDK)
  static const String mapboxAttribution =
      '© Mapbox © OpenStreetMap';
}
