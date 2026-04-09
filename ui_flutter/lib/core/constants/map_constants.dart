import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Map mode enum for command center tabs
enum MapMode { overview, workers, territories }

/// Lightweight model for a selectable map style.
class MapStyle {
  final String label;
  final String uri;
  final IconData icon;

  const MapStyle(this.label, this.uri, this.icon);
}

/// Mapbox configuration constants for native SDK
class MapConstants {
  MapConstants._();

  /// Mapbox public access token (for runtime usage)
  static const String mapboxAccessToken =
      'pk.eyJ1IjoiYWJoaXNoZWticmljaGhhbGl5YSIsImEiOiJjbWpucGt6ZGMwZmpxM2NzZHVzOWMwZ2RsIn0.uvQnSW5RBEroADuX27ZshQ';

  /// Mapbox style URIs for native SDK
  static const String mapboxStyleStreets = 'mapbox://styles/mapbox/streets-v12';
  static const String mapboxStyleOutdoors =
      'mapbox://styles/mapbox/outdoors-v12';
  static const String mapboxStyleLight = 'mapbox://styles/mapbox/light-v11';
  static const String mapboxStyleDark = 'mapbox://styles/mapbox/dark-v11';
  static const String mapboxStyleSatellite =
      'mapbox://styles/mapbox/satellite-v9';
  static const String mapboxStyleSatelliteStreets =
      'mapbox://styles/mapbox/satellite-streets-v12';
  static const String mapboxStyleNavigationDay =
      'mapbox://styles/mapbox/navigation-day-v1';
  static const String mapboxStyleNavigationNight =
      'mapbox://styles/mapbox/navigation-night-v1';

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

  /// Available map styles for the style toggle
  static const List<MapStyle> mapStyles = [
    MapStyle('Streets', mapboxStyleStreets, Icons.map),
    MapStyle('Satellite', mapboxStyleSatelliteStreets, Icons.satellite_alt),
    MapStyle('Outdoors', mapboxStyleOutdoors, Icons.terrain),
  ];

  /// Attribution (required by Mapbox ToS - handled automatically by SDK)
  static const String mapboxAttribution = '© Mapbox © OpenStreetMap';
}

/// A floating pill widget that lets the user switch between map styles.
class MapStyleToggle extends StatefulWidget {
  final MapboxMap mapboxMap;

  const MapStyleToggle({super.key, required this.mapboxMap});

  @override
  State<MapStyleToggle> createState() => _MapStyleToggleState();
}

class _MapStyleToggleState extends State<MapStyleToggle> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(MapConstants.mapStyles.length, (i) {
          final style = MapConstants.mapStyles[i];
          final isSelected = i == _selectedIndex;
          return GestureDetector(
            onTap: () {
              if (i == _selectedIndex) return;
              setState(() => _selectedIndex = i);
              widget.mapboxMap.loadStyleURI(style.uri);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                style.icon,
                size: 20,
                color: isSelected ? Colors.blue : Colors.grey.shade600,
              ),
            ),
          );
        }),
      ),
    );
  }
}
