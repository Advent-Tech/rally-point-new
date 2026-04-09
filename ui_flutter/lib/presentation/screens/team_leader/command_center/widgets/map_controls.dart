import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

class MapControls extends StatelessWidget {
  final mapbox.MapboxMap? mapController;

  const MapControls({super.key, this.mapController});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zoom in
        _buildControlButton(
          icon: Icons.add,
          onPressed: () async {
            if (mapController == null) return;
            final camera = await mapController!.getCameraState();
            final zoom = camera.zoom;
            await mapController!.setCamera(
              mapbox.CameraOptions(zoom: zoom + 1),
            );
          },
        ),
        const SizedBox(height: 8),

        // Zoom out
        _buildControlButton(
          icon: Icons.remove,
          onPressed: () async {
            if (mapController == null) return;
            final camera = await mapController!.getCameraState();
            final zoom = camera.zoom;
            await mapController!.setCamera(
              mapbox.CameraOptions(zoom: zoom - 1),
            );
          },
        ),
        const SizedBox(height: 8),

        // Map styles
        _buildControlButton(
          icon: Icons.layers,
          onPressed: () => _showStylePicker(context),
        ),
      ],
    );
  }

  void _showStylePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Standard'),
                onTap: () {
                  mapController?.loadStyleURI(mapbox.MapboxStyles.STANDARD);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.satellite_alt),
                title: const Text('Satellite'),
                onTap: () {
                  mapController?.loadStyleURI(
                    mapbox.MapboxStyles.SATELLITE_STREETS,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Light'),
                onTap: () {
                  mapController?.loadStyleURI(mapbox.MapboxStyles.LIGHT);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final Color bg = Colors.white.withValues(alpha: 0.96);
    const Color iconColor = Color(0xFF1F2937);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}
