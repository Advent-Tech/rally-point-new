part of 'prayer_request_bloc.dart';

abstract class PrayerRequestEvent extends Equatable {
  const PrayerRequestEvent();

  @override
  List<Object?> get props => [];
}

class PrayerRequestLoadMy extends PrayerRequestEvent {
  final int page;
  final int pageSize;

  const PrayerRequestLoadMy({this.page = 1, this.pageSize = 20});

  @override
  List<Object?> get props => [page, pageSize];
}

class PrayerRequestLoadList extends PrayerRequestEvent {
  final String? teamId;
  final String? territoryId;
  final String? status;
  final String? requestType;
  final String? category;
  final String? urgency;
  final int page;
  final int pageSize;

  const PrayerRequestLoadList({
    this.teamId,
    this.territoryId,
    this.status,
    this.requestType,
    this.category,
    this.urgency,
    this.page = 1,
    this.pageSize = 20,
  });

  @override
  List<Object?> get props => [teamId, territoryId, status, requestType, category, urgency, page, pageSize];
}

class PrayerRequestLoadMapMarkers extends PrayerRequestEvent {
  final String? teamId;
  final String? territoryId;
  final String? status;
  final String? requestType;

  const PrayerRequestLoadMapMarkers({
    this.teamId,
    this.territoryId,
    this.status,
    this.requestType,
  });

  @override
  List<Object?> get props => [teamId, territoryId, status, requestType];
}

class PrayerRequestLoadStats extends PrayerRequestEvent {
  final String? teamId;
  final String? territoryId;

  const PrayerRequestLoadStats({this.teamId, this.territoryId});

  @override
  List<Object?> get props => [teamId, territoryId];
}

class PrayerRequestLoadDetails extends PrayerRequestEvent {
  final String id;

  const PrayerRequestLoadDetails({required this.id});

  @override
  List<Object?> get props => [id];
}

class PrayerRequestCreate extends PrayerRequestEvent {
  final String requesterName;
  final String? requesterPhone;
  final String? requesterEmail;
  final String? requesterAddress;
  final double? latitude;
  final double? longitude;
  final String prayerSubject;
  final String prayerDetails;
  final String? prayerCategory;
  final String requestType;
  final String? preferredVisitDate;
  final String? preferredVisitTime;
  final String? urgency;
  final String? territoryId;
  final String? notes;

  const PrayerRequestCreate({
    required this.requesterName,
    this.requesterPhone,
    this.requesterEmail,
    this.requesterAddress,
    this.latitude,
    this.longitude,
    required this.prayerSubject,
    required this.prayerDetails,
    this.prayerCategory,
    required this.requestType,
    this.preferredVisitDate,
    this.preferredVisitTime,
    this.urgency,
    this.territoryId,
    this.notes,
  });

  @override
  List<Object?> get props => [
    requesterName, requesterPhone, requesterEmail, requesterAddress,
    latitude, longitude, prayerSubject, prayerDetails, prayerCategory,
    requestType, preferredVisitDate, preferredVisitTime, urgency,
    territoryId, notes
  ];
}

class PrayerRequestUpdate extends PrayerRequestEvent {
  final String id;
  final String? requesterName;
  final String? requesterPhone;
  final String? requesterEmail;
  final String? requesterAddress;
  final double? latitude;
  final double? longitude;
  final String? prayerSubject;
  final String? prayerDetails;
  final String? prayerCategory;
  final String? requestType;
  final String? preferredVisitDate;
  final String? preferredVisitTime;
  final String? urgency;
  final String? notes;

  const PrayerRequestUpdate({
    required this.id,
    this.requesterName,
    this.requesterPhone,
    this.requesterEmail,
    this.requesterAddress,
    this.latitude,
    this.longitude,
    this.prayerSubject,
    this.prayerDetails,
    this.prayerCategory,
    this.requestType,
    this.preferredVisitDate,
    this.preferredVisitTime,
    this.urgency,
    this.notes,
  });

  @override
  List<Object?> get props => [
    id, requesterName, requesterPhone, requesterEmail, requesterAddress,
    latitude, longitude, prayerSubject, prayerDetails, prayerCategory,
    requestType, preferredVisitDate, preferredVisitTime, urgency, notes
  ];
}

class PrayerRequestDelete extends PrayerRequestEvent {
  final String id;

  const PrayerRequestDelete({required this.id});

  @override
  List<Object?> get props => [id];
}

class PrayerRequestUpdateStatus extends PrayerRequestEvent {
  final String id;
  final String status;
  final String? completionNotes;

  const PrayerRequestUpdateStatus({
    required this.id,
    required this.status,
    this.completionNotes,
  });

  @override
  List<Object?> get props => [id, status, completionNotes];
}

class PrayerRequestAssignPreacher extends PrayerRequestEvent {
  final String id;
  final String preacherId;
  final String? scheduledAt;
  final String? notes;

  const PrayerRequestAssignPreacher({
    required this.id,
    required this.preacherId,
    this.scheduledAt,
    this.notes,
  });

  @override
  List<Object?> get props => [id, preacherId, scheduledAt, notes];
}

class PrayerRequestComplete extends PrayerRequestEvent {
  final String id;
  final String? notes;

  const PrayerRequestComplete({
    required this.id,
    this.notes,
  });

  @override
  List<Object?> get props => [id, notes];
}

class PrayerRequestRefresh extends PrayerRequestEvent {
  final bool isLeader;
  final String? teamId;

  const PrayerRequestRefresh({this.isLeader = false, this.teamId});

  @override
  List<Object?> get props => [isLeader, teamId];
}
