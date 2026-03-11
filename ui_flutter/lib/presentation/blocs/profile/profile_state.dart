part of 'profile_bloc.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final String totalHours;
  final String totalDistance;
  final int totalSessions;
  final int totalVisits;
  final int totalDeliveries;
  final LocationStats? locationStats;

  const ProfileLoaded({
    required this.totalHours,
    required this.totalDistance,
    this.totalSessions = 0,
    this.totalVisits = 0,
    this.totalDeliveries = 0,
    this.locationStats,
  });

  @override
  List<Object?> get props => [totalHours, totalDistance, totalSessions, totalVisits, totalDeliveries, locationStats];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError({required this.message});

  @override
  List<Object?> get props => [message];
}
