// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryModel _$DeliveryModelFromJson(Map<String, dynamic> json) =>
    DeliveryModel(
      id: json['id'] as String,
      recipientName: json['recipient_name'] as String? ?? '',
      recipientPhone: json['recipient_phone'] as String?,
      recipientEmail: json['recipient_email'] as String?,
      address: json['address'] as String? ?? '',
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'pending',
      priority: json['priority'] as String? ?? 'medium',
      notes: json['notes'] as String?,
      deliveryType: json['delivery_type'] as String? ?? 'door_to_door',
      workerId: json['worker_id'] as String?,
      workerName: json['worker_name'] as String?,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      scheduledDate: json['scheduled_date'] == null
          ? null
          : DateTime.parse(json['scheduled_date'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      territoryId: json['territory_id'] as String?,
      territoryName: json['territory_name'] as String?,
      householdId: json['household_id'] as String?,
      donationAmount: (json['donation_amount'] as num?)?.toDouble(),
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String?,
      stripePaymentId: json['stripe_payment_id'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      isOffline: json['is_offline'] as bool? ?? false,
      syncedAt: json['synced_at'] == null
          ? null
          : DateTime.parse(json['synced_at'] as String),
      offlineId: json['offline_id'] as String?,
    );

Map<String, dynamic> _$DeliveryModelToJson(DeliveryModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'recipient_name': instance.recipientName,
      'recipient_phone': instance.recipientPhone,
      'recipient_email': instance.recipientEmail,
      'address': instance.address,
      'city': instance.city,
      'state': instance.state,
      'zip_code': instance.zipCode,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'status': instance.status,
      'priority': instance.priority,
      'notes': instance.notes,
      'delivery_type': instance.deliveryType,
      'worker_id': instance.workerId,
      'worker_name': instance.workerName,
      'completed_at': instance.completedAt?.toIso8601String(),
      'scheduled_date': instance.scheduledDate?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'territory_id': instance.territoryId,
      'territory_name': instance.territoryName,
      'household_id': instance.householdId,
      'donation_amount': instance.donationAmount,
      'payment_method': instance.paymentMethod,
      'payment_status': instance.paymentStatus,
      'stripe_payment_id': instance.stripePaymentId,
      'receipt_number': instance.receiptNumber,
      'receipt_url': instance.receiptUrl,
      'is_offline': instance.isOffline,
      'synced_at': instance.syncedAt?.toIso8601String(),
      'offline_id': instance.offlineId,
    };

DeliveryRoute _$DeliveryRouteFromJson(Map<String, dynamic> json) =>
    DeliveryRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      driverId: json['driver_id'] as String?,
      driverName: json['driver_name'] as String?,
      status: json['status'] as String,
      deliveryCount: (json['delivery_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble(),
      estimatedDurationMinutes:
          (json['estimated_duration_minutes'] as num?)?.toInt(),
      startTime: json['start_time'] == null
          ? null
          : DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] == null
          ? null
          : DateTime.parse(json['end_time'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$DeliveryRouteToJson(DeliveryRoute instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'driver_id': instance.driverId,
      'driver_name': instance.driverName,
      'status': instance.status,
      'delivery_count': instance.deliveryCount,
      'completed_count': instance.completedCount,
      'total_distance_km': instance.totalDistanceKm,
      'estimated_duration_minutes': instance.estimatedDurationMinutes,
      'start_time': instance.startTime?.toIso8601String(),
      'end_time': instance.endTime?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
    };

DeliveryItem _$DeliveryItemFromJson(Map<String, dynamic> json) => DeliveryItem(
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$DeliveryItemToJson(DeliveryItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'quantity': instance.quantity,
      'description': instance.description,
    };

CreateDeliveryRequest _$CreateDeliveryRequestFromJson(
        Map<String, dynamic> json) =>
    CreateDeliveryRequest(
      teamId: json['team_id'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => DeliveryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recipientName: json['recipient_name'] as String,
      recipientPhone: json['recipient_phone'] as String?,
      recipientEmail: json['recipient_email'] as String?,
      address: json['address'] as String,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      priority: json['priority'] as String?,
      notes: json['notes'] as String?,
      deliveryType: json['delivery_type'] as String? ?? 'door_to_door',
      territoryId: json['territory_id'] as String?,
      territoryName: json['territory_name'] as String?,
      householdId: json['household_id'] as String?,
      donationAmount: (json['donation_amount'] as num?)?.toDouble(),
      paymentMethod: json['payment_method'] as String?,
      offlineId: json['offline_id'] as String?,
    );

Map<String, dynamic> _$CreateDeliveryRequestToJson(
        CreateDeliveryRequest instance) =>
    <String, dynamic>{
      'team_id': instance.teamId,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'recipient_name': instance.recipientName,
      'recipient_phone': instance.recipientPhone,
      'recipient_email': instance.recipientEmail,
      'address': instance.address,
      'city': instance.city,
      'state': instance.state,
      'zip_code': instance.zipCode,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'priority': instance.priority,
      'notes': instance.notes,
      'delivery_type': instance.deliveryType,
      'territory_id': instance.territoryId,
      'territory_name': instance.territoryName,
      'household_id': instance.householdId,
      'donation_amount': instance.donationAmount,
      'payment_method': instance.paymentMethod,
      'offline_id': instance.offlineId,
    };

UpdateDeliveryStatusRequest _$UpdateDeliveryStatusRequestFromJson(
        Map<String, dynamic> json) =>
    UpdateDeliveryStatusRequest(
      status: json['status'] as String,
      failureReason: json['failure_reason'] as String?,
      signatureUrl: json['signature_url'] as String?,
      photoUrl: json['photo_url'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$UpdateDeliveryStatusRequestToJson(
        UpdateDeliveryStatusRequest instance) =>
    <String, dynamic>{
      'status': instance.status,
      'failure_reason': instance.failureReason,
      'signature_url': instance.signatureUrl,
      'photo_url': instance.photoUrl,
      'notes': instance.notes,
    };
