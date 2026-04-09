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
      urgency: json['urgency'] as String,
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
