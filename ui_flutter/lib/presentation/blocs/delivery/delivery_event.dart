part of 'delivery_bloc.dart';

abstract class DeliveryEvent extends Equatable {
  const DeliveryEvent();

  @override
  List<Object?> get props => [];
}

class DeliveryLoadList extends DeliveryEvent {
  final int limit;
  final int offset;
  final String? status;
  final bool assignedToMe;

  const DeliveryLoadList({
    this.limit = 20,
    this.offset = 0,
    this.status,
    this.assignedToMe = true,
  });

  @override
  List<Object?> get props => [limit, offset, status, assignedToMe];
}

class DeliveryLoadDetail extends DeliveryEvent {
  final String id;

  const DeliveryLoadDetail({required this.id});

  @override
  List<Object?> get props => [id];
}

class DeliveryCreate extends DeliveryEvent {
  final CreateDeliveryRequest request;

  const DeliveryCreate({required this.request});

  @override
  List<Object?> get props => [request];
}

class DeliveryUpdateStatus extends DeliveryEvent {
  final String deliveryId;
  final UpdateDeliveryStatusRequest request;

  const DeliveryUpdateStatus({
    required this.deliveryId,
    required this.request,
  });

  @override
  List<Object?> get props => [deliveryId, request];
}

class DeliveryLoadRoutes extends DeliveryEvent {
  final String? status;

  const DeliveryLoadRoutes({this.status});

  @override
  List<Object?> get props => [status];
}

class DeliveryStartRoute extends DeliveryEvent {
  final String routeId;

  const DeliveryStartRoute({required this.routeId});

  @override
  List<Object?> get props => [routeId];
}

class DeliveryCompleteDelivery extends DeliveryEvent {
  final String deliveryId;
  final String? signatureUrl;
  final String? photoUrl;
  final String? notes;

  const DeliveryCompleteDelivery({
    required this.deliveryId,
    this.signatureUrl,
    this.photoUrl,
    this.notes,
  });

  @override
  List<Object?> get props => [deliveryId, signatureUrl, photoUrl, notes];
}

class DeliveryFailDelivery extends DeliveryEvent {
  final String deliveryId;
  final String reason;
  final String? photoUrl;

  const DeliveryFailDelivery({
    required this.deliveryId,
    required this.reason,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [deliveryId, reason, photoUrl];
}

class DeliveryRefresh extends DeliveryEvent {
  const DeliveryRefresh();
}
