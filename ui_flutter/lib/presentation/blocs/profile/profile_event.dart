part of 'profile_bloc.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileLoadStats extends ProfileEvent {
  const ProfileLoadStats();
}

class ProfileRefresh extends ProfileEvent {
  const ProfileRefresh();
}
