// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'donation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DonationModel _$DonationModelFromJson(Map<String, dynamic> json) =>
    DonationModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String?,
      workerId: json['worker_id'] as String,
      workerName: json['worker_name'] as String,
      teamId: json['team_id'] as String,
      donorName: json['donor_name'] as String,
      donorPhone: json['donor_phone'] as String?,
      donorEmail: json['donor_email'] as String?,
      donorAddress: json['donor_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'BDT',
      donationType: json['donation_type'] as String,
      purpose: json['purpose'] as String?,
      paymentMethod: json['payment_method'] as String,
      paymentRef: json['payment_ref'] as String?,
      receiptNumber: json['receipt_number'] as String,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      notes: json['notes'] as String?,
      status: json['status'] as String,
      collectedAt: json['collected_at'] == null
          ? null
          : DateTime.parse(json['collected_at'] as String),
      depositedAt: json['deposited_at'] == null
          ? null
          : DateTime.parse(json['deposited_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$DonationModelToJson(DonationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'session_id': instance.sessionId,
      'worker_id': instance.workerId,
      'worker_name': instance.workerName,
      'team_id': instance.teamId,
      'donor_name': instance.donorName,
      'donor_phone': instance.donorPhone,
      'donor_email': instance.donorEmail,
      'donor_address': instance.donorAddress,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'amount': instance.amount,
      'currency': instance.currency,
      'donation_type': instance.donationType,
      'purpose': instance.purpose,
      'payment_method': instance.paymentMethod,
      'payment_ref': instance.paymentRef,
      'receipt_number': instance.receiptNumber,
      'is_anonymous': instance.isAnonymous,
      'notes': instance.notes,
      'status': instance.status,
      'collected_at': instance.collectedAt?.toIso8601String(),
      'deposited_at': instance.depositedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

CreateDonationRequest _$CreateDonationRequestFromJson(
        Map<String, dynamic> json) =>
    CreateDonationRequest(
      sessionId: json['session_id'] as String?,
      teamId: json['team_id'] as String,
      donorName: json['donor_name'] as String,
      donorPhone: json['donor_phone'] as String?,
      donorEmail: json['donor_email'] as String?,
      donorAddress: json['donor_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String?,
      donationType: json['donation_type'] as String,
      purpose: json['purpose'] as String?,
      paymentMethod: json['payment_method'] as String,
      paymentRef: json['payment_ref'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$CreateDonationRequestToJson(
        CreateDonationRequest instance) =>
    <String, dynamic>{
      'session_id': instance.sessionId,
      'team_id': instance.teamId,
      'donor_name': instance.donorName,
      'donor_phone': instance.donorPhone,
      'donor_email': instance.donorEmail,
      'donor_address': instance.donorAddress,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'amount': instance.amount,
      'currency': instance.currency,
      'donation_type': instance.donationType,
      'purpose': instance.purpose,
      'payment_method': instance.paymentMethod,
      'payment_ref': instance.paymentRef,
      'is_anonymous': instance.isAnonymous,
      'notes': instance.notes,
    };

DonationStats _$DonationStatsFromJson(Map<String, dynamic> json) =>
    DonationStats(
      totalDonations: (json['total_donations'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      oneTimeDonations: (json['one_time_donations'] as num?)?.toInt() ?? 0,
      oneTimeAmount: (json['one_time_amount'] as num?)?.toDouble() ?? 0,
      recurringDonations: (json['recurring_donations'] as num?)?.toInt() ?? 0,
      recurringAmount: (json['recurring_amount'] as num?)?.toDouble() ?? 0,
      averageDonation: (json['average_donation'] as num?)?.toDouble() ?? 0,
      largestDonation: (json['largest_donation'] as num?)?.toDouble() ?? 0,
      anonymousDonations: (json['anonymous_donations'] as num?)?.toInt() ?? 0,
      pendingDeposit: (json['pending_deposit'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$DonationStatsToJson(DonationStats instance) =>
    <String, dynamic>{
      'total_donations': instance.totalDonations,
      'total_amount': instance.totalAmount,
      'one_time_donations': instance.oneTimeDonations,
      'one_time_amount': instance.oneTimeAmount,
      'recurring_donations': instance.recurringDonations,
      'recurring_amount': instance.recurringAmount,
      'average_donation': instance.averageDonation,
      'largest_donation': instance.largestDonation,
      'anonymous_donations': instance.anonymousDonations,
      'pending_deposit': instance.pendingDeposit,
    };
