// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prayer_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrayerRequestModel _$PrayerRequestModelFromJson(Map<String, dynamic> json) =>
    PrayerRequestModel(
      id: json['id'] as String,
      workerId: json['worker_id'] as String,
      teamId: json['team_id'] as String?,
      territoryId: json['territory_id'] as String?,
      requesterName: json['requester_name'] as String,
      requesterPhone: json['requester_phone'] as String?,
      requesterEmail: json['requester_email'] as String?,
      requesterAddress: json['requester_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      prayerSubject: json['prayer_subject'] as String,
      prayerDetails: json['prayer_details'] as String,
      prayerCategory: json['prayer_category'] as String,
      requestType: json['request_type'] as String,
      preacherId: json['preacher_id'] as String?,
      preferredVisitDate: json['preferred_visit_date'] as String?,
      preferredVisitTime: json['preferred_visit_time'] as String?,
      status: json['status'] as String,
      urgency: json['urgency'] as String? ?? 'normal',
      scheduledAt: json['scheduled_at'] == null
          ? null
          : DateTime.parse(json['scheduled_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      completedBy: json['completed_by'] as String?,
      completionNotes: json['completion_notes'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      workerName: json['worker_name'] as String?,
      preacherName: json['preacher_name'] as String?,
    );

Map<String, dynamic> _$PrayerRequestModelToJson(PrayerRequestModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'worker_id': instance.workerId,
      'team_id': instance.teamId,
      'territory_id': instance.territoryId,
      'requester_name': instance.requesterName,
      'requester_phone': instance.requesterPhone,
      'requester_email': instance.requesterEmail,
      'requester_address': instance.requesterAddress,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'prayer_subject': instance.prayerSubject,
      'prayer_details': instance.prayerDetails,
      'prayer_category': instance.prayerCategory,
      'request_type': instance.requestType,
      'preacher_id': instance.preacherId,
      'preferred_visit_date': instance.preferredVisitDate,
      'preferred_visit_time': instance.preferredVisitTime,
      'status': instance.status,
      'urgency': instance.urgency,
      'scheduled_at': instance.scheduledAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'completed_by': instance.completedBy,
      'completion_notes': instance.completionNotes,
      'notes': instance.notes,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'worker_name': instance.workerName,
      'preacher_name': instance.preacherName,
    };

CreatePrayerRequestRequest _$CreatePrayerRequestRequestFromJson(
        Map<String, dynamic> json) =>
    CreatePrayerRequestRequest(
      requesterName: json['requester_name'] as String,
      requesterPhone: json['requester_phone'] as String?,
      requesterEmail: json['requester_email'] as String?,
      requesterAddress: json['requester_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      prayerSubject: json['prayer_subject'] as String,
      prayerDetails: json['prayer_details'] as String,
      prayerCategory: json['prayer_category'] as String?,
      requestType: json['request_type'] as String,
      preferredVisitDate: json['preferred_visit_date'] as String?,
      preferredVisitTime: json['preferred_visit_time'] as String?,
      urgency: json['urgency'] as String?,
      territoryId: json['territory_id'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$CreatePrayerRequestRequestToJson(
        CreatePrayerRequestRequest instance) =>
    <String, dynamic>{
      'requester_name': instance.requesterName,
      'requester_phone': instance.requesterPhone,
      'requester_email': instance.requesterEmail,
      'requester_address': instance.requesterAddress,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'prayer_subject': instance.prayerSubject,
      'prayer_details': instance.prayerDetails,
      'prayer_category': instance.prayerCategory,
      'request_type': instance.requestType,
      'preferred_visit_date': instance.preferredVisitDate,
      'preferred_visit_time': instance.preferredVisitTime,
      'urgency': instance.urgency,
      'territory_id': instance.territoryId,
      'notes': instance.notes,
    };

UpdatePrayerRequestRequest _$UpdatePrayerRequestRequestFromJson(
        Map<String, dynamic> json) =>
    UpdatePrayerRequestRequest(
      requesterName: json['requester_name'] as String?,
      requesterPhone: json['requester_phone'] as String?,
      requesterEmail: json['requester_email'] as String?,
      requesterAddress: json['requester_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      prayerSubject: json['prayer_subject'] as String?,
      prayerDetails: json['prayer_details'] as String?,
      prayerCategory: json['prayer_category'] as String?,
      requestType: json['request_type'] as String?,
      preferredVisitDate: json['preferred_visit_date'] as String?,
      preferredVisitTime: json['preferred_visit_time'] as String?,
      urgency: json['urgency'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$UpdatePrayerRequestRequestToJson(
        UpdatePrayerRequestRequest instance) =>
    <String, dynamic>{
      'requester_name': instance.requesterName,
      'requester_phone': instance.requesterPhone,
      'requester_email': instance.requesterEmail,
      'requester_address': instance.requesterAddress,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'prayer_subject': instance.prayerSubject,
      'prayer_details': instance.prayerDetails,
      'prayer_category': instance.prayerCategory,
      'request_type': instance.requestType,
      'preferred_visit_date': instance.preferredVisitDate,
      'preferred_visit_time': instance.preferredVisitTime,
      'urgency': instance.urgency,
      'notes': instance.notes,
    };

UpdatePrayerStatusRequest _$UpdatePrayerStatusRequestFromJson(
        Map<String, dynamic> json) =>
    UpdatePrayerStatusRequest(
      status: json['status'] as String,
      completionNotes: json['completion_notes'] as String?,
    );

Map<String, dynamic> _$UpdatePrayerStatusRequestToJson(
        UpdatePrayerStatusRequest instance) =>
    <String, dynamic>{
      'status': instance.status,
      'completion_notes': instance.completionNotes,
    };

AssignPreacherRequest _$AssignPreacherRequestFromJson(
        Map<String, dynamic> json) =>
    AssignPreacherRequest(
      preacherId: json['preacher_id'] as String,
      scheduledAt: json['scheduled_at'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$AssignPreacherRequestToJson(
        AssignPreacherRequest instance) =>
    <String, dynamic>{
      'preacher_id': instance.preacherId,
      'scheduled_at': instance.scheduledAt,
      'notes': instance.notes,
    };

PrayerRequestMapMarker _$PrayerRequestMapMarkerFromJson(
        Map<String, dynamic> json) =>
    PrayerRequestMapMarker(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      requesterName: json['requester_name'] as String,
      prayerSubject: json['prayer_subject'] as String,
      prayerCategory: json['prayer_category'] as String,
      requestType: json['request_type'] as String,
      status: json['status'] as String,
      urgency: json['urgency'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PrayerRequestMapMarkerToJson(
        PrayerRequestMapMarker instance) =>
    <String, dynamic>{
      'id': instance.id,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'requester_name': instance.requesterName,
      'prayer_subject': instance.prayerSubject,
      'prayer_category': instance.prayerCategory,
      'request_type': instance.requestType,
      'status': instance.status,
      'urgency': instance.urgency,
      'created_at': instance.createdAt?.toIso8601String(),
    };

PrayerRequestStats _$PrayerRequestStatsFromJson(Map<String, dynamic> json) =>
    PrayerRequestStats(
      totalRequests: (json['total_requests'] as num?)?.toInt() ?? 0,
      pendingRequests: (json['pending_requests'] as num?)?.toInt() ?? 0,
      completedRequests: (json['completed_requests'] as num?)?.toInt() ?? 0,
      homeVisitRequests: (json['home_visit_requests'] as num?)?.toInt() ?? 0,
      byCategory: (json['by_category'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ),
      byUrgency: (json['by_urgency'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ),
    );

Map<String, dynamic> _$PrayerRequestStatsToJson(PrayerRequestStats instance) =>
    <String, dynamic>{
      'total_requests': instance.totalRequests,
      'pending_requests': instance.pendingRequests,
      'completed_requests': instance.completedRequests,
      'home_visit_requests': instance.homeVisitRequests,
      'by_category': instance.byCategory,
      'by_urgency': instance.byUrgency,
    };

PrayerRequestListResponse _$PrayerRequestListResponseFromJson(
        Map<String, dynamic> json) =>
    PrayerRequestListResponse(
      prayerRequests: (json['prayer_requests'] as List<dynamic>)
          .map((e) => PrayerRequestModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      totalPages: (json['total_pages'] as num).toInt(),
    );

Map<String, dynamic> _$PrayerRequestListResponseToJson(
        PrayerRequestListResponse instance) =>
    <String, dynamic>{
      'prayer_requests': instance.prayerRequests,
      'total': instance.total,
      'page': instance.page,
      'page_size': instance.pageSize,
      'total_pages': instance.totalPages,
    };
