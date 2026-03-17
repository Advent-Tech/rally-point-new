import 'package:equatable/equatable.dart';
import 'command_center_state.dart';
import '../../../../data/models/donation_model.dart';
import '../../../../data/models/prayer_request_model.dart';

abstract class CommandCenterEvent extends Equatable {
  const CommandCenterEvent();

  @override
  List<Object?> get props => [];
}

class InitializeEvent extends CommandCenterEvent {
  final MapMode initialMode;

  const InitializeEvent({required this.initialMode});

  @override
  List<Object> get props => [initialMode];
}

class ChangeMapModeEvent extends CommandCenterEvent {
  final MapMode mode;

  const ChangeMapModeEvent({required this.mode});

  @override
  List<Object> get props => [mode];
}

class RefreshDataEvent extends CommandCenterEvent {}

class UpdateLiveLocationEvent extends CommandCenterEvent {
  final String workerId;
  final double latitude;
  final double longitude;

  const UpdateLiveLocationEvent({
    required this.workerId,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object> get props => [workerId, latitude, longitude];
}

class AddDonationEvent extends CommandCenterEvent {
  final DonationModel donation;

  const AddDonationEvent({required this.donation});

  @override
  List<Object> get props => [donation];
}

class AddPrayerRequestEvent extends CommandCenterEvent {
  final PrayerRequestModel prayerRequest;

  const AddPrayerRequestEvent({required this.prayerRequest});

  @override
  List<Object> get props => [prayerRequest];
}

class SelectTerritoryEvent extends CommandCenterEvent {
  final String? territoryId;

  const SelectTerritoryEvent({this.territoryId});

  @override
  List<Object?> get props => [territoryId];
}

class FollowWorkerEvent extends CommandCenterEvent {
  final String? workerId;

  const FollowWorkerEvent({this.workerId});

  @override
  List<Object?> get props => [workerId];
}

class ToggleLayerEvent extends CommandCenterEvent {
  final String layer;

  const ToggleLayerEvent({required this.layer});

  @override
  List<Object> get props => [layer];
}

class UpdateWorkerPathEvent extends CommandCenterEvent {
  final String workerId;
  final List<Position> path;

  const UpdateWorkerPathEvent({required this.workerId, required this.path});

  @override
  List<Object> get props => [workerId, path];
}

class ShowMapPopupEvent extends CommandCenterEvent {
  final MapPopup popup;

  const ShowMapPopupEvent({required this.popup});

  @override
  List<Object> get props => [popup];
}

class HideMapPopupEvent extends CommandCenterEvent {}

class ToggleMapPopupExpandedEvent extends CommandCenterEvent {}
