import 'dart:async';
import '../../../../../data/models/prayer_request_model.dart';
import '../../../../../data/models/donation_model.dart';
import '../../../../../services/websocket_service.dart';
import '../command_center_bloc.dart';
import '../command_center_event.dart';

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
    DateTime parseOccurredAt(dynamic payloadTimestamp, DateTime fallback) {
      if (payloadTimestamp is String) {
        return DateTime.tryParse(payloadTimestamp)?.toUtc() ?? fallback.toUtc();
      }
      return fallback.toUtc();
    }

    // Listen for worker location updates
    _subscriptions.add(
      _ws.messagesOfType(WsMessageType.locationUpdate).listen((message) {
        final raw = message.data;
        final payload = (raw['data'] is Map) ? (raw['data'] as Map) : raw;

        final userId = (payload['userId'] ?? payload['user_id'])?.toString();
        if (userId == null || userId.isEmpty) return;

        final latRaw = payload['latitude'];
        final lngRaw = payload['longitude'];
        if (latRaw is! num || lngRaw is! num) return;
        final accuracyRaw = payload['accuracy'];
        final speedRaw = payload['speed'] ?? payload['speed_mps'];
        final occurredAt = parseOccurredAt(
          payload['timestamp'],
          message.timestamp,
        );

        bloc.add(
          UpdateLiveLocationEvent(
            workerId: userId,
            latitude: latRaw.toDouble(),
            longitude: lngRaw.toDouble(),
            occurredAt: occurredAt,
            accuracy: accuracyRaw is num ? accuracyRaw.toDouble() : null,
            speedMps: speedRaw is num ? speedRaw.toDouble() : null,
          ),
        );
      }),
    );

    _subscriptions.add(
      _ws.messagesOfType(WsMessageType.workerLocationBroadcast).listen((
        message,
      ) {
        final raw = message.data;
        final payload = (raw['data'] is Map) ? (raw['data'] as Map) : raw;

        final userId = (payload['userId'] ?? payload['user_id'])?.toString();
        if (userId == null || userId.isEmpty) return;

        final latRaw = payload['latitude'];
        final lngRaw = payload['longitude'];
        if (latRaw is! num || lngRaw is! num) return;
        final accuracyRaw = payload['accuracy'];
        final speedRaw = payload['speed'] ?? payload['speed_mps'];
        final occurredAt = parseOccurredAt(
          payload['timestamp'],
          message.timestamp,
        );

        bloc.add(
          UpdateLiveLocationEvent(
            workerId: userId,
            latitude: latRaw.toDouble(),
            longitude: lngRaw.toDouble(),
            occurredAt: occurredAt,
            accuracy: accuracyRaw is num ? accuracyRaw.toDouble() : null,
            speedMps: speedRaw is num ? speedRaw.toDouble() : null,
          ),
        );
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
