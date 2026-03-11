part of 'delivery_bloc.dart';

abstract class DeliveryState extends Equatable {
  const DeliveryState();

  @override
  List<Object?> get props => [];
}

class DeliveryInitial extends DeliveryState {}

class DeliveryLoading extends DeliveryState {}

class DeliverySubmitting extends DeliveryState {}

class DeliveryUpdating extends DeliveryState {}

class DeliveryListLoaded extends DeliveryState {
  final List<DeliveryModel> deliveries;
  final int pendingCount;
  final int completedCount;
  final int failedCount;
  final bool hasMore;
  final bool isOffline;

  const DeliveryListLoaded({
    required this.deliveries,
    this.pendingCount = 0,
    this.completedCount = 0,
    this.failedCount = 0,
    this.hasMore = false,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [
    deliveries, pendingCount, completedCount, failedCount, hasMore, isOffline
  ];
}

class DeliveryDetailLoaded extends DeliveryState {
  final DeliveryModel delivery;

  const DeliveryDetailLoaded({required this.delivery});

  @override
  List<Object?> get props => [delivery];
}

class DeliveryCreateSuccess extends DeliveryState {
  final DeliveryModel delivery;

  const DeliveryCreateSuccess({required this.delivery});

  @override
  List<Object?> get props => [delivery];
}

class DeliveryUpdateSuccess extends DeliveryState {
  final DeliveryModel delivery;

  const DeliveryUpdateSuccess({required this.delivery});

  @override
  List<Object?> get props => [delivery];
}

class DeliveryRoutesLoaded extends DeliveryState {
  final List<DeliveryRoute> routes;

  const DeliveryRoutesLoaded({required this.routes});

  @override
  List<Object?> get props => [routes];
}

class DeliveryRouteStarted extends DeliveryState {
  final String routeId;

  const DeliveryRouteStarted({required this.routeId});

  @override
  List<Object?> get props => [routeId];
}

class DeliveryCompleteSuccess extends DeliveryState {
  final DeliveryModel delivery;

  const DeliveryCompleteSuccess({required this.delivery});

  @override
  List<Object?> get props => [delivery];
}

class DeliveryFailureRecorded extends DeliveryState {
  final DeliveryModel delivery;

  const DeliveryFailureRecorded({required this.delivery});

  @override
  List<Object?> get props => [delivery];
}

class DeliveryError extends DeliveryState {
  final String message;

  const DeliveryError({required this.message});

  @override
  List<Object?> get props => [message];
}
