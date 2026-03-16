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

  RealtimeBridge({required this.bloc}) {
    _initialize();
  }

  void _initialize() {
    final ws = WebSocketService();

    // Listen for worker location updates
    _subscriptions.add(
      ws.messagesOfType(WsMessageType.locationUpdate).listen((message) {
        final update = message.data;
        bloc.add(
          UpdateLiveLocationEvent(
            workerId: update['userId'] as String,
            latitude: update['latitude'] as double,
            longitude: update['longitude'] as double,
          ),
        );

        // Update worker path if tracking
        if (update['userId'] == bloc.state.followTarget) {
          final currentPath = bloc.state.workerPaths[update['userId']] ?? [];
          bloc.add(
            UpdateWorkerPathEvent(
              workerId: update['userId'] as String,
              path: [
                ...currentPath,
                Position(
                  latitude: update['latitude'] as double,
                  longitude: update['longitude'] as double,
                ),
              ],
            ),
          );
        }
      }),
    );

    // Listen for new donations (using team activity stream)
    _subscriptions.add(
      ws.teamActivityStream.listen((message) {
        final data = message.data;
        if (data['type'] == 'donation') {
          final donation = DonationModel.fromJson(data);
          bloc.add(AddDonationEvent(donation: donation));
        }
      }),
    );

    // Listen for new prayer requests (using team activity stream)
    _subscriptions.add(
      ws.teamActivityStream.listen((message) {
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
