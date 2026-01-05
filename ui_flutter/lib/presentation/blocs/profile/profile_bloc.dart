import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/location_model.dart';
import '../../../data/repositories/location_repository.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final LocationRepository _locationRepository;

  ProfileBloc({LocationRepository? locationRepository})
      : _locationRepository = locationRepository ?? LocationRepository(),
        super(ProfileInitial()) {
    on<ProfileLoadStats>(_onLoadStats);
    on<ProfileRefresh>(_onRefresh);
  }

  Future<void> _onLoadStats(ProfileLoadStats event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());

    final result = await _locationRepository.getLocationStats();

    result.when(
      success: (stats) {
        emit(ProfileLoaded(
          totalHours: stats.formattedTotalDuration,
          totalDistance: stats.formattedTotalDistance,
          totalSessions: stats.totalSessions,
          locationStats: stats,
        ));
      },
      failure: (message, statusCode) {
        // On failure, emit empty stats rather than error to show placeholders
        emit(const ProfileLoaded(
          totalHours: '0h',
          totalDistance: '0 km',
          totalSessions: 0,
        ));
      },
    );
  }

  Future<void> _onRefresh(ProfileRefresh event, Emitter<ProfileState> emit) async {
    add(const ProfileLoadStats());
  }
}
