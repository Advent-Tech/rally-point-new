import 'package:json_annotation/json_annotation.dart';

part 'prayer_request_model.g.dart';

// Prayer request types
class PrayerRequestType {
  static const String churchPrayer = 'church_prayer';
  static const String homeVisit = 'home_visit';

  static const List<String> all = [churchPrayer, homeVisit];

  static String getDisplayName(String type) {
    switch (type) {
      case churchPrayer:
        return 'Church Prayer';
      case homeVisit:
        return 'Home Visit';
      default:
        return type;
    }
  }
}

// Prayer request statuses
class PrayerRequestStatus {
  static const String pending = 'pending';
  static const String scheduled = 'scheduled';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const List<String> all = [pending, scheduled, inProgress, completed, cancelled];

  static String getDisplayName(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case scheduled:
        return 'Scheduled';
      case inProgress:
        return 'In Progress';
      case completed:
        return 'Completed';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}

// Prayer categories
class PrayerCategory {
  static const String general = 'general';
  static const String healing = 'healing';
  static const String family = 'family';
  static const String financial = 'financial';
  static const String spiritual = 'spiritual';
  static const String thanksgiving = 'thanksgiving';
  static const String other = 'other';

  static const List<String> all = [
    general, healing, family, financial, spiritual, thanksgiving, other
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case general:
        return 'General';
      case healing:
        return 'Healing';
      case family:
        return 'Family';
      case financial:
        return 'Financial';
      case spiritual:
        return 'Spiritual';
      case thanksgiving:
        return 'Thanksgiving';
      case other:
        return 'Other';
      default:
        return category;
    }
  }
}

// Urgency levels
class PrayerUrgency {
  static const String low = 'low';
  static const String normal = 'normal';
  static const String high = 'high';
  static const String urgent = 'urgent';

  static const List<String> all = [low, normal, high, urgent];

  static String getDisplayName(String urgency) {
    switch (urgency) {
      case low:
        return 'Low';
      case normal:
        return 'Normal';
      case high:
        return 'High';
      case urgent:
        return 'Urgent';
      default:
        return urgency;
    }
  }
}

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

  const PrayerRequestModel({
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
    this.urgency = 'normal',
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

  // Helper getters
  bool get isPending => status == PrayerRequestStatus.pending;
  bool get isScheduled => status == PrayerRequestStatus.scheduled;
  bool get isInProgress => status == PrayerRequestStatus.inProgress;
  bool get isCompleted => status == PrayerRequestStatus.completed;
  bool get isCancelled => status == PrayerRequestStatus.cancelled;

  bool get isChurchPrayer => requestType == PrayerRequestType.churchPrayer;
  bool get isHomeVisit => requestType == PrayerRequestType.homeVisit;

  bool get hasLocation => latitude != null && longitude != null;

  String get requestTypeDisplay => PrayerRequestType.getDisplayName(requestType);
  String get statusDisplay => PrayerRequestStatus.getDisplayName(status);
  String get categoryDisplay => PrayerCategory.getDisplayName(prayerCategory);
  String get urgencyDisplay => PrayerUrgency.getDisplayName(urgency);
}

@JsonSerializable()
class CreatePrayerRequestRequest {
  @JsonKey(name: 'requester_name')
  final String requesterName;
  @JsonKey(name: 'requester_phone')
  final String? requesterPhone;
  @JsonKey(name: 'requester_email')
  final String? requesterEmail;
  @JsonKey(name: 'requester_address')
  final String? requesterAddress;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'prayer_subject')
  final String prayerSubject;
  @JsonKey(name: 'prayer_details')
  final String prayerDetails;
  @JsonKey(name: 'prayer_category')
  final String? prayerCategory;
  @JsonKey(name: 'request_type')
  final String requestType;
  @JsonKey(name: 'preferred_visit_date')
  final String? preferredVisitDate;
  @JsonKey(name: 'preferred_visit_time')
  final String? preferredVisitTime;
  final String? urgency;
  @JsonKey(name: 'territory_id')
  final String? territoryId;
  final String? notes;

  const CreatePrayerRequestRequest({
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

  factory CreatePrayerRequestRequest.fromJson(Map<String, dynamic> json) =>
      _$CreatePrayerRequestRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreatePrayerRequestRequestToJson(this);
}

@JsonSerializable()
class UpdatePrayerRequestRequest {
  @JsonKey(name: 'requester_name')
  final String? requesterName;
  @JsonKey(name: 'requester_phone')
  final String? requesterPhone;
  @JsonKey(name: 'requester_email')
  final String? requesterEmail;
  @JsonKey(name: 'requester_address')
  final String? requesterAddress;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'prayer_subject')
  final String? prayerSubject;
  @JsonKey(name: 'prayer_details')
  final String? prayerDetails;
  @JsonKey(name: 'prayer_category')
  final String? prayerCategory;
  @JsonKey(name: 'request_type')
  final String? requestType;
  @JsonKey(name: 'preferred_visit_date')
  final String? preferredVisitDate;
  @JsonKey(name: 'preferred_visit_time')
  final String? preferredVisitTime;
  final String? urgency;
  final String? notes;

  const UpdatePrayerRequestRequest({
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

  factory UpdatePrayerRequestRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdatePrayerRequestRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdatePrayerRequestRequestToJson(this);
}

@JsonSerializable()
class UpdatePrayerStatusRequest {
  final String status;
  @JsonKey(name: 'completion_notes')
  final String? completionNotes;

  const UpdatePrayerStatusRequest({
    required this.status,
    this.completionNotes,
  });

  factory UpdatePrayerStatusRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdatePrayerStatusRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdatePrayerStatusRequestToJson(this);
}

@JsonSerializable()
class AssignPreacherRequest {
  @JsonKey(name: 'preacher_id')
  final String preacherId;
  @JsonKey(name: 'scheduled_at')
  final String? scheduledAt;
  final String? notes;

  const AssignPreacherRequest({
    required this.preacherId,
    this.scheduledAt,
    this.notes,
  });

  factory AssignPreacherRequest.fromJson(Map<String, dynamic> json) =>
      _$AssignPreacherRequestFromJson(json);
  Map<String, dynamic> toJson() => _$AssignPreacherRequestToJson(this);
}

@JsonSerializable()
class PrayerRequestMapMarker {
  final String id;
  final double latitude;
  final double longitude;
  @JsonKey(name: 'requester_name')
  final String requesterName;
  @JsonKey(name: 'prayer_subject')
  final String prayerSubject;
  @JsonKey(name: 'prayer_category')
  final String prayerCategory;
  @JsonKey(name: 'request_type')
  final String requestType;
  final String status;
  final String urgency;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const PrayerRequestMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.requesterName,
    required this.prayerSubject,
    required this.prayerCategory,
    required this.requestType,
    required this.status,
    required this.urgency,
    this.createdAt,
  });

  factory PrayerRequestMapMarker.fromJson(Map<String, dynamic> json) =>
      _$PrayerRequestMapMarkerFromJson(json);
  Map<String, dynamic> toJson() => _$PrayerRequestMapMarkerToJson(this);

  String get requestTypeDisplay => PrayerRequestType.getDisplayName(requestType);
  String get statusDisplay => PrayerRequestStatus.getDisplayName(status);
  String get categoryDisplay => PrayerCategory.getDisplayName(prayerCategory);
  String get urgencyDisplay => PrayerUrgency.getDisplayName(urgency);
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

  const PrayerRequestStats({
    this.totalRequests = 0,
    this.pendingRequests = 0,
    this.completedRequests = 0,
    this.homeVisitRequests = 0,
    this.byCategory,
    this.byUrgency,
  });

  factory PrayerRequestStats.fromJson(Map<String, dynamic> json) =>
      _$PrayerRequestStatsFromJson(json);
  Map<String, dynamic> toJson() => _$PrayerRequestStatsToJson(this);
}

@JsonSerializable()
class PrayerRequestListResponse {
  @JsonKey(name: 'prayer_requests')
  final List<PrayerRequestModel> prayerRequests;
  final int total;
  final int page;
  @JsonKey(name: 'page_size')
  final int pageSize;
  @JsonKey(name: 'total_pages')
  final int totalPages;

  const PrayerRequestListResponse({
    required this.prayerRequests,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PrayerRequestListResponse.fromJson(Map<String, dynamic> json) =>
      _$PrayerRequestListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PrayerRequestListResponseToJson(this);
}
