import 'package:json_annotation/json_annotation.dart';

part 'prayer_request_model.g.dart';

@JsonSerializable()
class PrayerRequestModel {
  final String id;
  @JsonKey(name: 'worker_id')
  final String workerId;
  @JsonKey(name: 'team_id')
  final String? teamId;
  @JsonKey(name: 'territory_id')
  final String? territoryId;

  // Requester info
  @JsonKey(name: 'requester_name')
  final String requesterName;
  @JsonKey(name: 'requester_phone')
  final String? requesterPhone;
  @JsonKey(name: 'requester_email')
  final String? requesterEmail;
  @JsonKey(name: 'requester_address')
  final String? requesterAddress;

  // Location
  final double? latitude;
  final double? longitude;

  // Prayer details
  @JsonKey(name: 'prayer_subject')
  final String prayerSubject;
  @JsonKey(name: 'prayer_details')
  final String prayerDetails;
  @JsonKey(name: 'prayer_category')
  final String prayerCategory;

  // Request type
  @JsonKey(name: 'request_type')
  final String requestType;

  // For home visits
  @JsonKey(name: 'preacher_id')
  final String? preacherId;
  @JsonKey(name: 'preferred_visit_date')
  final String? preferredVisitDate;
  @JsonKey(name: 'preferred_visit_time')
  final String? preferredVisitTime;

  // Status
  final String status;
  final String urgency;

  // Completion
  @JsonKey(name: 'scheduled_at')
  final DateTime? scheduledAt;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'completed_by')
  final String? completedBy;
  @JsonKey(name: 'completion_notes')
  final String? completionNotes;

  // Metadata
  final String? notes;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  // Joined data
  @JsonKey(name: 'worker_name')
  final String? workerName;
  @JsonKey(name: 'preacher_name')
  final String? preacherName;

  PrayerRequestModel({
    required this.id,
    required this.workerId,
    this.teamId,
    this.territoryId,
    required this.requesterName,
    this.requesterPhone,
    this.requesterEmail,
    this.requesterAddress,
    this.latitude,
    this.longitude,
    required this.prayerSubject,
    required this.prayerDetails,
    required this.prayerCategory,
    required this.requestType,
    this.preacherId,
    this.preferredVisitDate,
    this.preferredVisitTime,
    required this.status,
    required this.urgency,
    this.scheduledAt,
    this.completedAt,
    this.completedBy,
    this.completionNotes,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.workerName,
    this.preacherName,
  });

  factory PrayerRequestModel.fromJson(Map<String, dynamic> json) =>
      _$PrayerRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$PrayerRequestModelToJson(this);
}

@JsonSerializable()
class PrayerRequestStats {
  @JsonKey(name: 'total_requests')
  final int totalRequests;
  @JsonKey(name: 'pending_requests')
  final int pendingRequests;
  @JsonKey(name: 'completed_requests')
  final int completedRequests;
  @JsonKey(name: 'home_visit_requests')
  final int homeVisitRequests;
  @JsonKey(name: 'by_category')
  final Map<String, int>? byCategory;
  @JsonKey(name: 'by_urgency')
  final Map<String, int>? byUrgency;

  PrayerRequestStats({
    required this.totalRequests,
    required this.pendingRequests,
    required this.completedRequests,
    required this.homeVisitRequests,
    this.byCategory,
    this.byUrgency,
  });

  factory PrayerRequestStats.fromJson(Map<String, dynamic> json) =>
      _$PrayerRequestStatsFromJson(json);

  Map<String, dynamic> toJson() => _$PrayerRequestStatsToJson(this);
}
