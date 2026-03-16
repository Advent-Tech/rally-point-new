import 'dart:async';
import '../../../../../data/models/prayer_request_model.dart';
import '../../../../../data/models/donation_model.dart';
import '../../../../../services/websocket_service.dart';
import '../command_center_bloc.dart';
import '../command_center_event.dart';
import '../command_center_state.dart';

/// Bridge between WebSocket service and CommandCenterBloc
class RealtimeBridge {
  final CommandCenterBloc bloc;
  final List<StreamSubscription> _subscriptions = [];
  final WebSocketService _ws;

  RealtimeBridge({required this.bloc, WebSocketService? ws})
    : _ws = ws ?? WebSocketService() {
    _initialize();
  }

  void _initialize() {
    // Listen for worker location updates
    _subscriptions.add(
      _ws.messagesOfType(WsMessageType.locationUpdate).listen((message) {
        final update = message.data;
        final userId = update['userId']?.toString();
        final latRaw = update['latitude'];
        final lngRaw = update['longitude'];
        if (userId == null || userId.isEmpty) return;
        if (latRaw is! num || lngRaw is! num) return;
        bloc.add(
          UpdateLiveLocationEvent(
            workerId: userId,
            latitude: latRaw.toDouble(),
            longitude: lngRaw.toDouble(),
          ),
        );

        // Update worker path if tracking
        if (userId == bloc.state.followTarget) {
          final currentPath = bloc.state.workerPaths[userId] ?? [];
          bloc.add(
            UpdateWorkerPathEvent(
              workerId: userId,
              path: [
                ...currentPath,
                Position(
                  latitude: latRaw.toDouble(),
                  longitude: lngRaw.toDouble(),
                ),
              ],
            ),
          );
        }
      }),
    );

    _subscriptions.add(
      _ws.messagesOfType(WsMessageType.workerLocationBroadcast).listen((
        message,
      ) {
        final update = message.data;
        final userId = update['userId']?.toString();
        final latRaw = update['latitude'];
        final lngRaw = update['longitude'];
        if (userId == null || userId.isEmpty) return;
        if (latRaw is! num || lngRaw is! num) return;
        bloc.add(
          UpdateLiveLocationEvent(
            workerId: userId,
            latitude: latRaw.toDouble(),
            longitude: lngRaw.toDouble(),
          ),
        );

        if (userId == bloc.state.followTarget) {
          final currentPath = bloc.state.workerPaths[userId] ?? [];
          bloc.add(
            UpdateWorkerPathEvent(
              workerId: userId,
              path: [
                ...currentPath,
                Position(
                  latitude: latRaw.toDouble(),
                  longitude: lngRaw.toDouble(),
                ),
              ],
            ),
          );
        }
      }),
    );

    // Listen for new donations (using team activity stream)
    _subscriptions.add(
      _ws.teamActivityStream.listen((message) {
        final data = message.data;
        if (data['type'] == 'donation') {
          final donation = DonationModel.fromJson(data);
          bloc.add(AddDonationEvent(donation: donation));
        }
      }),
    );

    // Listen for new prayer requests (using team activity stream)
    _subscriptions.add(
      _ws.teamActivityStream.listen((message) {
        final data = message.data;
        if (data['type'] == 'prayer_request') {
          final prayer = PrayerRequestModel.fromJson(data);
          bloc.add(AddPrayerRequestEvent(prayerRequest: prayer));
        }
      }),
    );
  }

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
  }
}
