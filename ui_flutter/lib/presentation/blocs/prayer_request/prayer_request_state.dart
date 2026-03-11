part of 'prayer_request_bloc.dart';

abstract class PrayerRequestState extends Equatable {
  const PrayerRequestState();

  @override
  List<Object?> get props => [];
}

class PrayerRequestInitial extends PrayerRequestState {}

class PrayerRequestLoading extends PrayerRequestState {}

class PrayerRequestLoaded extends PrayerRequestState {
  final List<PrayerRequestModel> prayerRequests;
  final List<PrayerRequestMapMarker> mapMarkers;
  final PrayerRequestStats? stats;
  final PrayerRequestModel? currentPrayerRequest;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PrayerRequestLoaded({
    this.prayerRequests = const [],
    this.mapMarkers = const [],
    this.stats,
    this.currentPrayerRequest,
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.totalPages = 0,
  });

  PrayerRequestLoaded copyWith({
    List<PrayerRequestModel>? prayerRequests,
    List<PrayerRequestMapMarker>? mapMarkers,
    PrayerRequestStats? stats,
    PrayerRequestModel? currentPrayerRequest,
    int? total,
    int? page,
    int? pageSize,
    int? totalPages,
  }) {
    return PrayerRequestLoaded(
      prayerRequests: prayerRequests ?? this.prayerRequests,
      mapMarkers: mapMarkers ?? this.mapMarkers,
      stats: stats ?? this.stats,
      currentPrayerRequest: currentPrayerRequest ?? this.currentPrayerRequest,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  @override
  List<Object?> get props => [
    prayerRequests, mapMarkers, stats, currentPrayerRequest,
    total, page, pageSize, totalPages
  ];
}

class PrayerRequestSubmitting extends PrayerRequestState {}

class PrayerRequestSubmitSuccess extends PrayerRequestState {
  final PrayerRequestModel prayerRequest;

  const PrayerRequestSubmitSuccess({required this.prayerRequest});

  @override
  List<Object?> get props => [prayerRequest];
}

class PrayerRequestActionSuccess extends PrayerRequestState {
  final String message;

  const PrayerRequestActionSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class PrayerRequestError extends PrayerRequestState {
  final String message;

  const PrayerRequestError({required this.message});

  @override
  List<Object?> get props => [message];
}
