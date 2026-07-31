import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../command_center_bloc.dart';
import '../command_center_event.dart';
import '../command_center_state.dart' as cc;
import '../../../../../data/models/donation_model.dart';
import '../../../../../data/models/prayer_request_model.dart';
import '../../../../../data/models/team_model.dart';
import '../../../../../data/models/territory_model.dart';

class MapPopupOverlay extends StatefulWidget {
  final mapbox.MapboxMap? mapController;

  const MapPopupOverlay({super.key, required this.mapController});

  @override
  State<MapPopupOverlay> createState() => _MapPopupOverlayState();
}

class _MapPopupOverlayState extends State<MapPopupOverlay> {
  Offset? _anchor;

  Future<void> _recomputeAnchor(cc.MapPopup popup) async {
    if (popup.latitude == null || popup.longitude == null) return;
    final controller = widget.mapController;
    if (controller == null) return;

    try {
      final point = mapbox.Point(
        coordinates: mapbox.Position(popup.longitude!, popup.latitude!),
      );
      final dynamic dyn = controller;
      final dynamic pixel = await dyn.pixelForCoordinate(point);
      if (!mounted) return;
      final dx = (pixel as dynamic).x as num?;
      final dy = (pixel as dynamic).y as num?;
      if (dx == null || dy == null) return;
      setState(() => _anchor = Offset(dx.toDouble(), dy.toDouble()));
    } catch (_) {
      // Fallback: fixed-position card
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: BlocBuilder<CommandCenterBloc, cc.CommandCenterState>(
        buildWhen: (p, n) =>
            p.activePopup != n.activePopup || p.mapMode != n.mapMode,
        builder: (context, state) {
          final popup = state.activePopup;
          if (popup == null) return const SizedBox.shrink();

          final bool forceCenter = state.mapMode == cc.MapMode.territories;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _recomputeAnchor(popup);
          });

          final card = _PopupCard(popup: popup);

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => context.read<CommandCenterBloc>().add(
                    HideMapPopupEvent(),
                  ),
                ),
              ),
              if (forceCenter)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: card,
                  ),
                )
              else if (_anchor != null)
                Positioned(
                  left: (_anchor!.dx - 170).clamp(12.0, 100000.0),
                  top: (_anchor!.dy - 160).clamp(
                    MediaQuery.of(context).padding.top + 138.0,
                    100000.0,
                  ),
                  child: card,
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: card,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PopupCard extends StatelessWidget {
  final cc.MapPopup popup;

  const _PopupCard({required this.popup});

  DonationModel? _findDonation(cc.CommandCenterState s) {
    for (final d in s.donations) {
      if (d.id == popup.id) return d;
    }
    return null;
  }

  PrayerRequestModel? _findPrayer(cc.CommandCenterState s) {
    for (final p in s.prayerRequests) {
      if (p.id == popup.id) return p;
    }
    return null;
  }

  GeoTerritory? _findTerritory(cc.CommandCenterState s) {
    for (final t in s.territories) {
      if (t.id == popup.id) return t;
    }
    return null;
  }

  TeamMember? _findWorker(cc.CommandCenterState s) {
    for (final w in s.workers) {
      if (w.id == popup.id) return w;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CommandCenterBloc>().state;

    Widget body;
    switch (popup.kind) {
      case cc.MapPopupKind.activityDonation:
      case cc.MapPopupKind.activityBookSale:
        final d = _findDonation(state);
        body = d == null
            ? const Text('Details unavailable')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${d.displayName} • ${d.formattedAmount}'),
                  const SizedBox(height: 4),
                  Text(
                    popup.kind == cc.MapPopupKind.activityBookSale
                        ? 'Status: ${d.statusDisplay} • Book Sale'
                        : 'Status: ${d.statusDisplay}',
                  ),
                  if (popup.expanded) ...[
                    const SizedBox(height: 8),
                    Text('Light Squad: ${d.workerName}'),
                    if (d.donationType.isNotEmpty)
                      Text('Type: ${d.donationType}'),
                  ],
                ],
              );
        break;
      case cc.MapPopupKind.activityPrayer:
        final p = _findPrayer(state);
        body = p == null
            ? const Text('Details unavailable')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.prayerSubject),
                  const SizedBox(height: 4),
                  Text('${p.requesterName} • ${p.statusDisplay}'),
                  if (popup.expanded) ...[
                    const SizedBox(height: 8),
                    Text('Category: ${p.categoryDisplay}'),
                    Text('Urgency: ${p.urgencyDisplay}'),
                    const SizedBox(height: 6),
                    Text(p.prayerDetails),
                  ],
                ],
              );
        break;
      case cc.MapPopupKind.territory:
        final t = _findTerritory(state);
        body = t == null
            ? const Text('Details unavailable')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.entityName),
                  const SizedBox(height: 4),
                  if (t.displayLocation.isNotEmpty) Text(t.displayLocation),
                ],
              );
        break;
      case cc.MapPopupKind.worker:
        final w = _findWorker(state);
        final workerPos = state.liveLocations[popup.id];
        final hasAnyLocation =
            workerPos != null &&
            _isValidLocation(workerPos.latitude, workerPos.longitude);
        final isGpsLive = state.gpsLiveWorkerIds.contains(popup.id);
        final isApiOnline = w?.isOnline == true;
        final updatedAt = state.liveLocationUpdatedAt[popup.id];
        final accuracy = state.liveLocationAccuracy[popup.id];
        final speedMps = state.liveLocationSpeedMps[popup.id];
        final speedKmh = speedMps == null ? null : speedMps * 3.6;
        final isFollowing = state.followTarget == popup.id;
        body = w == null
            ? const Text('Details unavailable')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(w.displayName ?? 'Team Member'),
                  const SizedBox(height: 4),
                  Text(
                    isGpsLive
                        ? 'GPS Live'
                        : (hasAnyLocation
                              ? 'Last known (entry)'
                              : (isApiOnline
                                    ? 'Online (no valid location yet)'
                                    : 'Offline')),
                  ),
                  if (!hasAnyLocation) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Follow is unavailable until valid GPS coordinates arrive.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (updatedAt != null) ...[
                    const SizedBox(height: 6),
                    Text('Updated ${_formatFreshness(updatedAt)}'),
                  ],
                  if (accuracy != null || speedKmh != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (accuracy != null)
                          'Accuracy ±${accuracy.toStringAsFixed(0)}m',
                        if (speedKmh != null)
                          'Speed ${speedKmh.toStringAsFixed(1)} km/h',
                      ].join('  •  '),
                    ),
                  ],
                  if (isFollowing) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Following now',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              );
        break;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(switch (popup.kind) {
                      cc.MapPopupKind.activityDonation => 'Donation',
                      cc.MapPopupKind.activityBookSale => 'Book Sale',
                      cc.MapPopupKind.activityPrayer => 'Prayer Request',
                      cc.MapPopupKind.territory => 'Territory',
                      cc.MapPopupKind.worker => 'Light Squad',
                    }, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    onPressed: () => context.read<CommandCenterBloc>().add(
                      HideMapPopupEvent(),
                    ),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              body,
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: switch (popup.kind) {
                  cc.MapPopupKind.territory => FilledButton(
                    onPressed: () {
                      context.read<CommandCenterBloc>().add(
                        SelectTerritoryEvent(territoryId: popup.id),
                      );
                      context.read<CommandCenterBloc>().add(
                        HideMapPopupEvent(),
                      );
                    },
                    child: const Text('View'),
                  ),
                  cc.MapPopupKind.worker => FilledButton(
                    onPressed: (() {
                          final pos = state.liveLocations[popup.id];
                          return pos != null &&
                              _isValidLocation(pos.latitude, pos.longitude);
                        })()
                        ? () {
                            context.read<CommandCenterBloc>().add(
                              FollowWorkerEvent(
                                workerId: state.followTarget == popup.id
                                    ? null
                                    : popup.id,
                              ),
                            );
                            context.read<CommandCenterBloc>().add(
                              HideMapPopupEvent(),
                            );
                          }
                        : null,
                    child: Text(state.followTarget == popup.id ? 'Stop' : 'Follow'),
                  ),
                  _ => TextButton(
                    onPressed: () {
                      context.read<CommandCenterBloc>().add(
                        ToggleMapPopupExpandedEvent(),
                      );
                    },
                    child: Text(popup.expanded ? 'Collapse' : 'View'),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFreshness(DateTime updatedAt) {
    final age = DateTime.now().toUtc().difference(updatedAt.toUtc());
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    return '${age.inHours}h ago';
  }

  bool _isValidLocation(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }
}
