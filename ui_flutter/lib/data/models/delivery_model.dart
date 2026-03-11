import 'package:json_annotation/json_annotation.dart';

part 'delivery_model.g.dart';

@JsonSerializable()
class DeliveryModel {
  final String id;
  @JsonKey(name: 'recipient_name', defaultValue: '')
  final String recipientName;
  @JsonKey(name: 'recipient_phone')
  final String? recipientPhone;
  @JsonKey(name: 'recipient_email')
  final String? recipientEmail;
  @JsonKey(defaultValue: '')
  final String address;
  final String? city;
  final String? state;
  @JsonKey(name: 'zip_code')
  final String? zipCode;
  final double? latitude;
  final double? longitude;
  @JsonKey(defaultValue: 'pending')
  final String status; // pending, completed, failed, cancelled
  @JsonKey(defaultValue: 'medium')
  final String priority;
  final String? notes;
  @JsonKey(name: 'delivery_type', defaultValue: 'door_to_door')
  final String deliveryType; // door_to_door, person_to_person, donation
  @JsonKey(name: 'worker_id')
  final String? workerId;
  @JsonKey(name: 'worker_name')
  final String? workerName;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'scheduled_date')
  final DateTime? scheduledDate;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  // Territory context
  @JsonKey(name: 'territory_id')
  final String? territoryId;
  @JsonKey(name: 'territory_name')
  final String? territoryName;
  @JsonKey(name: 'household_id')
  final String? householdId;

  // Donation fields
  @JsonKey(name: 'donation_amount')
  final double? donationAmount;
  @JsonKey(name: 'payment_method')
  final String? paymentMethod; // cash, card, online
  @JsonKey(name: 'payment_status')
  final String? paymentStatus; // pending, completed, failed
  @JsonKey(name: 'stripe_payment_id')
  final String? stripePaymentId;
  @JsonKey(name: 'receipt_number')
  final String? receiptNumber;
  @JsonKey(name: 'receipt_url')
  final String? receiptUrl;

  // Offline sync
  @JsonKey(name: 'is_offline')
  final bool isOffline;
  @JsonKey(name: 'synced_at')
  final DateTime? syncedAt;
  @JsonKey(name: 'offline_id')
  final String? offlineId;

  const DeliveryModel({
    required this.id,
    required this.recipientName,
    this.recipientPhone,
    this.recipientEmail,
    required this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
    required this.status,
    this.priority = 'medium',
    this.notes,
    this.deliveryType = 'door_to_door',
    this.workerId,
    this.workerName,
    this.completedAt,
    this.scheduledDate,
    this.createdAt,
    this.updatedAt,
    this.territoryId,
    this.territoryName,
    this.householdId,
    this.donationAmount,
    this.paymentMethod,
    this.paymentStatus,
    this.stripePaymentId,
    this.receiptNumber,
    this.receiptUrl,
    this.isOffline = false,
    this.syncedAt,
    this.offlineId,
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> json) => _$DeliveryModelFromJson(json);
  Map<String, dynamic> toJson() => _$DeliveryModelToJson(this);

  // Status helpers
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';

  // Legacy status helpers for backwards compatibility
  bool get isAssigned => isPending; // Simplified - assigned = pending
  bool get isInTransit => false; // Removed
  bool get isDelivered => isCompleted; // Renamed

  // Type helpers
  bool get isDoorToDoor => deliveryType == 'door_to_door';
  bool get isPersonToPerson => deliveryType == 'person_to_person';
  bool get isDonation => deliveryType == 'donation';

  bool get isHighPriority => priority == 'high' || priority == 'urgent';

  String get fullAddress {
    final parts = <String>[address];
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    if (zipCode != null) parts.add(zipCode!);
    return parts.join(', ');
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get deliveryTypeDisplay {
    switch (deliveryType) {
      case 'door_to_door':
        return 'Door to Door';
      case 'person_to_person':
        return 'Person to Person';
      case 'donation':
        return 'Donation';
      default:
        return deliveryType;
    }
  }

  DeliveryModel copyWith({
    String? id,
    String? recipientName,
    String? recipientPhone,
    String? recipientEmail,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    double? latitude,
    double? longitude,
    String? status,
    String? priority,
    String? notes,
    String? deliveryType,
    String? workerId,
    String? workerName,
    DateTime? completedAt,
    DateTime? scheduledDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? territoryId,
    String? territoryName,
    String? householdId,
    double? donationAmount,
    String? paymentMethod,
    String? paymentStatus,
    String? stripePaymentId,
    String? receiptNumber,
    String? receiptUrl,
    bool? isOffline,
    DateTime? syncedAt,
    String? offlineId,
  }) {
    return DeliveryModel(
      id: id ?? this.id,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      deliveryType: deliveryType ?? this.deliveryType,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      completedAt: completedAt ?? this.completedAt,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      territoryId: territoryId ?? this.territoryId,
      territoryName: territoryName ?? this.territoryName,
      householdId: householdId ?? this.householdId,
      donationAmount: donationAmount ?? this.donationAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      stripePaymentId: stripePaymentId ?? this.stripePaymentId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      isOffline: isOffline ?? this.isOffline,
      syncedAt: syncedAt ?? this.syncedAt,
      offlineId: offlineId ?? this.offlineId,
    );
  }
}

@JsonSerializable()
class DeliveryRoute {
  final String id;
  final String name;
  final String? description;
  @JsonKey(name: 'driver_id')
  final String? driverId;
  @JsonKey(name: 'driver_name')
  final String? driverName;
  final String status;
  @JsonKey(name: 'delivery_count')
  final int deliveryCount;
  @JsonKey(name: 'completed_count')
  final int completedCount;
  @JsonKey(name: 'total_distance_km')
  final double? totalDistanceKm;
  @JsonKey(name: 'estimated_duration_minutes')
  final int? estimatedDurationMinutes;
  @JsonKey(name: 'start_time')
  final DateTime? startTime;
  @JsonKey(name: 'end_time')
  final DateTime? endTime;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const DeliveryRoute({
    required this.id,
    required this.name,
    this.description,
    this.driverId,
    this.driverName,
    required this.status,
    this.deliveryCount = 0,
    this.completedCount = 0,
    this.totalDistanceKm,
    this.estimatedDurationMinutes,
    this.startTime,
    this.endTime,
    this.createdAt,
  });

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) => _$DeliveryRouteFromJson(json);
  Map<String, dynamic> toJson() => _$DeliveryRouteToJson(this);

  double get completionPercentage {
    if (deliveryCount == 0) return 0;
    return (completedCount / deliveryCount) * 100;
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
}

@JsonSerializable()
class DeliveryItem {
  final String name;
  final int quantity;
  final String? description;

  const DeliveryItem({
    required this.name,
    this.quantity = 1,
    this.description,
  });

  factory DeliveryItem.fromJson(Map<String, dynamic> json) => _$DeliveryItemFromJson(json);
  Map<String, dynamic> toJson() => _$DeliveryItemToJson(this);
}

@JsonSerializable(explicitToJson: true)
class CreateDeliveryRequest {
  @JsonKey(name: 'team_id')
  final String teamId;
  final List<DeliveryItem> items; // Required for door_to_door and person_to_person
  @JsonKey(name: 'recipient_name')
  final String recipientName;
  @JsonKey(name: 'recipient_phone')
  final String? recipientPhone;
  @JsonKey(name: 'recipient_email')
  final String? recipientEmail;
  final String address;
  final String? city;
  final String? state;
  @JsonKey(name: 'zip_code')
  final String? zipCode;
  final double? latitude;
  final double? longitude;
  final String? priority;
  final String? notes;
  @JsonKey(name: 'delivery_type')
  final String deliveryType; // door_to_door, person_to_person, donation
  @JsonKey(name: 'territory_id')
  final String? territoryId;
  @JsonKey(name: 'territory_name')
  final String? territoryName;
  @JsonKey(name: 'household_id')
  final String? householdId;

  // Donation fields
  @JsonKey(name: 'donation_amount')
  final double? donationAmount;
  @JsonKey(name: 'payment_method')
  final String? paymentMethod; // cash, card, online

  // Offline sync
  @JsonKey(name: 'offline_id')
  final String? offlineId;

  const CreateDeliveryRequest({
    required this.teamId,
    this.items = const [],
    required this.recipientName,
    this.recipientPhone,
    this.recipientEmail,
    required this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
    this.priority,
    this.notes,
    this.deliveryType = 'door_to_door',
    this.territoryId,
    this.territoryName,
    this.householdId,
    this.donationAmount,
    this.paymentMethod,
    this.offlineId,
  });

  factory CreateDeliveryRequest.fromJson(Map<String, dynamic> json) => _$CreateDeliveryRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateDeliveryRequestToJson(this);

  // Helper to check if this is a donation request
  bool get isDonation => deliveryType == 'donation';
}

@JsonSerializable()
class UpdateDeliveryStatusRequest {
  final String status;
  @JsonKey(name: 'failure_reason')
  final String? failureReason;
  @JsonKey(name: 'signature_url')
  final String? signatureUrl;
  @JsonKey(name: 'photo_url')
  final String? photoUrl;
  final String? notes;

  const UpdateDeliveryStatusRequest({
    required this.status,
    this.failureReason,
    this.signatureUrl,
    this.photoUrl,
    this.notes,
  });

  factory UpdateDeliveryStatusRequest.fromJson(Map<String, dynamic> json) => _$UpdateDeliveryStatusRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateDeliveryStatusRequestToJson(this);
}
