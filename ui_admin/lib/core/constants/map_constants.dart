/// Mapbox configuration constants
class MapConstants {
  MapConstants._();

  /// Mapbox access token
  static const String mapboxAccessToken =
      'pk.eyJ1IjoiYWJoaXNoZWticmljaGhhbGl5YSIsImEiOiJjbWpucGt6ZGMwZmpxM2NzZHVzOWMwZ2RsIn0.uvQnSW5RBEroADuX27ZshQ';

  /// Mapbox style URLs
  static const String mapboxStyleStreets = 'mapbox/streets-v12';
  static const String mapboxStyleOutdoors = 'mapbox/outdoors-v12';
  static const String mapboxStyleLight = 'mapbox/light-v11';
  static const String mapboxStyleDark = 'mapbox/dark-v11';
  static const String mapboxStyleSatellite = 'mapbox/satellite-v9';
  static const String mapboxStyleSatelliteStreets = 'mapbox/satellite-streets-v12';

  /// Tile size for flutter_map (256 = standard, 512 = retina @2x)
  static const int tileSize = 256;

  /// Get tile URL for flutter_map
  /// Using Mapbox for map tiles
  static String getTileUrl({String style = mapboxStyleStreets}) {
    return 'https://api.mapbox.com/styles/v1/$style/tiles/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';
  }

  /// Get Mapbox tile URL for dark mode
  static String getDarkTileUrl() {
    return getTileUrl(style: mapboxStyleDark);
  }

  /// Get Mapbox tile URL for light mode
  static String getLightTileUrl() {
    return getTileUrl(style: mapboxStyleLight);
  }

  /// Get Mapbox tile URL based on theme brightness
  static String getThemedTileUrl(bool isDark) {
    return isDark ? getDarkTileUrl() : getTileUrl(style: mapboxStyleStreets);
  }

  /// Default map center (US)
  static const double defaultLatitude = 39.8283;
  static const double defaultLongitude = -98.5795;
  static const double defaultZoom = 4.0;

  /// Zoom levels
  static const double minZoom = 2.0;
  static const double maxZoom = 18.0;

  /// Attribution (required by Mapbox ToS)
  static const String mapboxAttribution =
      '© Mapbox © OpenStreetMap';

  /// Get Mapbox geocoding URL for a search query
  static String getGeocodingUrl(String query) {
    final encoded = Uri.encodeComponent(query);
    return 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json'
        '?access_token=$mapboxAccessToken&limit=5';
  }
}
