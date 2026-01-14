import 'package:json_annotation/json_annotation.dart';

part 'donation_model.g.dart';

@JsonSerializable()
class DonationModel {
  final String id;
  @JsonKey(name: 'session_id')
  final String? sessionId;
  @JsonKey(name: 'worker_id')
  final String workerId;
  @JsonKey(name: 'worker_name')
  final String? workerName;
  @JsonKey(name: 'team_id')
  final String teamId;
  @JsonKey(name: 'team_name')
  final String? teamName;
  @JsonKey(name: 'donor_name')
  final String donorName;
  @JsonKey(name: 'donor_phone')
  final String? donorPhone;
  @JsonKey(name: 'donor_email')
  final String? donorEmail;
  @JsonKey(name: 'donor_address')
  final String? donorAddress;
  final double? latitude;
  final double? longitude;
  final double amount;
  final String currency;
  @JsonKey(name: 'donation_type')
  final String donationType;
  final String? purpose;
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
  @JsonKey(name: 'payment_ref')
  final String? paymentRef;
  @JsonKey(name: 'is_anonymous')
  final bool isAnonymous;
  final String status;
  final String? notes;
  @JsonKey(name: 'deposited_at')
  final DateTime? depositedAt;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const DonationModel({
    required this.id,
    this.sessionId,
    required this.workerId,
    this.workerName,
    required this.teamId,
    this.teamName,
    required this.donorName,
    this.donorPhone,
    this.donorEmail,
    this.donorAddress,
    this.latitude,
    this.longitude,
    required this.amount,
    this.currency = 'BDT',
    required this.donationType,
    this.purpose,
    required this.paymentMethod,
    this.paymentRef,
    this.isAnonymous = false,
    this.status = 'received',
    this.notes,
    this.depositedAt,
    this.createdAt,
  });

  factory DonationModel.fromJson(Map<String, dynamic> json) => _$DonationModelFromJson(json);
  Map<String, dynamic> toJson() => _$DonationModelToJson(this);
}

@JsonSerializable()
class DonationStats {
  @JsonKey(name: 'total_donations')
  final int totalDonations;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  @JsonKey(name: 'one_time_donations')
  final int oneTimeDonations;
  @JsonKey(name: 'one_time_amount')
  final double oneTimeAmount;
  @JsonKey(name: 'recurring_donations')
  final int recurringDonations;
  @JsonKey(name: 'recurring_amount')
  final double recurringAmount;
  @JsonKey(name: 'average_donation')
  final double averageDonation;
  @JsonKey(name: 'largest_donation')
  final double largestDonation;
  @JsonKey(name: 'anonymous_donations')
  final int anonymousDonations;
  @JsonKey(name: 'pending_deposit')
  final double pendingDeposit;

  const DonationStats({
    this.totalDonations = 0,
    this.totalAmount = 0,
    this.oneTimeDonations = 0,
    this.oneTimeAmount = 0,
    this.recurringDonations = 0,
    this.recurringAmount = 0,
    this.averageDonation = 0,
    this.largestDonation = 0,
    this.anonymousDonations = 0,
    this.pendingDeposit = 0,
  });

  factory DonationStats.fromJson(Map<String, dynamic> json) => _$DonationStatsFromJson(json);
  Map<String, dynamic> toJson() => _$DonationStatsToJson(this);
}

@JsonSerializable()
class ReceiptModel {
  final String id;
  @JsonKey(name: 'receipt_number')
  final String receiptNumber;
  @JsonKey(name: 'worker_id')
  final String workerId;
  @JsonKey(name: 'worker_name')
  final String? workerName;
  @JsonKey(name: 'team_id')
  final String teamId;
  @JsonKey(name: 'recipient_name')
  final String recipientName;
  @JsonKey(name: 'receipt_type')
  final String receiptType;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  final String currency;
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
  final String status;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const ReceiptModel({
    required this.id,
    required this.receiptNumber,
    required this.workerId,
    this.workerName,
    required this.teamId,
    required this.recipientName,
    required this.receiptType,
    required this.totalAmount,
    this.currency = 'BDT',
    required this.paymentMethod,
    this.status = 'completed',
    this.createdAt,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) => _$ReceiptModelFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptModelToJson(this);
}

@JsonSerializable()
class ReceiptStats {
  @JsonKey(name: 'total_receipts')
  final int totalReceipts;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  @JsonKey(name: 'book_sales_count')
  final int bookSalesCount;
  @JsonKey(name: 'book_sales_amount')
  final double bookSalesAmount;
  @JsonKey(name: 'literature_count')
  final int literatureCount;
  @JsonKey(name: 'literature_amount')
  final double literatureAmount;
  @JsonKey(name: 'donation_count')
  final int donationCount;
  @JsonKey(name: 'donation_amount')
  final double donationAmount;
  @JsonKey(name: 'average_receipt_value')
  final double averageReceiptValue;

  const ReceiptStats({
    this.totalReceipts = 0,
    this.totalAmount = 0,
    this.bookSalesCount = 0,
    this.bookSalesAmount = 0,
    this.literatureCount = 0,
    this.literatureAmount = 0,
    this.donationCount = 0,
    this.donationAmount = 0,
    this.averageReceiptValue = 0,
  });

  factory ReceiptStats.fromJson(Map<String, dynamic> json) => _$ReceiptStatsFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptStatsToJson(this);
}
