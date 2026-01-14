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
      workerName: json['worker_name'] as String?,
      teamId: json['team_id'] as String,
      teamName: json['team_name'] as String?,
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
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      status: json['status'] as String? ?? 'received',
      notes: json['notes'] as String?,
      depositedAt: json['deposited_at'] == null
          ? null
          : DateTime.parse(json['deposited_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$DonationModelToJson(DonationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'session_id': instance.sessionId,
      'worker_id': instance.workerId,
      'worker_name': instance.workerName,
      'team_id': instance.teamId,
      'team_name': instance.teamName,
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
      'status': instance.status,
      'notes': instance.notes,
      'deposited_at': instance.depositedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
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

ReceiptModel _$ReceiptModelFromJson(Map<String, dynamic> json) => ReceiptModel(
  id: json['id'] as String,
  receiptNumber: json['receipt_number'] as String,
  workerId: json['worker_id'] as String,
  workerName: json['worker_name'] as String?,
  teamId: json['team_id'] as String,
  recipientName: json['recipient_name'] as String,
  receiptType: json['receipt_type'] as String,
  totalAmount: (json['total_amount'] as num).toDouble(),
  currency: json['currency'] as String? ?? 'BDT',
  paymentMethod: json['payment_method'] as String,
  status: json['status'] as String? ?? 'completed',
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ReceiptModelToJson(ReceiptModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'receipt_number': instance.receiptNumber,
      'worker_id': instance.workerId,
      'worker_name': instance.workerName,
      'team_id': instance.teamId,
      'recipient_name': instance.recipientName,
      'receipt_type': instance.receiptType,
      'total_amount': instance.totalAmount,
      'currency': instance.currency,
      'payment_method': instance.paymentMethod,
      'status': instance.status,
      'created_at': instance.createdAt?.toIso8601String(),
    };

ReceiptStats _$ReceiptStatsFromJson(Map<String, dynamic> json) => ReceiptStats(
  totalReceipts: (json['total_receipts'] as num?)?.toInt() ?? 0,
  totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
  bookSalesCount: (json['book_sales_count'] as num?)?.toInt() ?? 0,
  bookSalesAmount: (json['book_sales_amount'] as num?)?.toDouble() ?? 0,
  literatureCount: (json['literature_count'] as num?)?.toInt() ?? 0,
  literatureAmount: (json['literature_amount'] as num?)?.toDouble() ?? 0,
  donationCount: (json['donation_count'] as num?)?.toInt() ?? 0,
  donationAmount: (json['donation_amount'] as num?)?.toDouble() ?? 0,
  averageReceiptValue: (json['average_receipt_value'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$ReceiptStatsToJson(ReceiptStats instance) =>
    <String, dynamic>{
      'total_receipts': instance.totalReceipts,
      'total_amount': instance.totalAmount,
      'book_sales_count': instance.bookSalesCount,
      'book_sales_amount': instance.bookSalesAmount,
      'literature_count': instance.literatureCount,
      'literature_amount': instance.literatureAmount,
      'donation_count': instance.donationCount,
      'donation_amount': instance.donationAmount,
      'average_receipt_value': instance.averageReceiptValue,
    };
