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
  final String workerName;
  @JsonKey(name: 'team_id')
  final String teamId;
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
  @JsonKey(name: 'receipt_number')
  final String receiptNumber;
  @JsonKey(name: 'is_anonymous')
  final bool isAnonymous;
  final String? notes;
  final String status;
  @JsonKey(name: 'collected_at')
  final DateTime? collectedAt;
  @JsonKey(name: 'deposited_at')
  final DateTime? depositedAt;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const DonationModel({
    required this.id,
    this.sessionId,
    required this.workerId,
    required this.workerName,
    required this.teamId,
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
    required this.receiptNumber,
    this.isAnonymous = false,
    this.notes,
    required this.status,
    this.collectedAt,
    this.depositedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DonationModel.fromJson(Map<String, dynamic> json) => _$DonationModelFromJson(json);
  Map<String, dynamic> toJson() => _$DonationModelToJson(this);

  bool get isReceived => status == 'received';
  bool get isDeposited => status == 'deposited';
  bool get isCancelled => status == 'cancelled';

  bool get isOneTime => donationType == 'one_time';
  bool get isRecurring => donationType == 'recurring';
  bool get isPledge => donationType == 'pledge';

  String get donationTypeDisplay {
    switch (donationType) {
      case 'one_time':
        return 'One Time';
      case 'recurring':
        return 'Recurring';
      case 'pledge':
        return 'Pledge';
      default:
        return donationType;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'received':
        return 'Received';
      case 'deposited':
        return 'Deposited';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get formattedAmount => '$currency ${amount.toStringAsFixed(2)}';

  String get displayName => isAnonymous ? 'Anonymous' : donorName;
}

@JsonSerializable()
class CreateDonationRequest {
  @JsonKey(name: 'session_id')
  final String? sessionId;
  @JsonKey(name: 'team_id')
  final String teamId;
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
  final String? currency;
  @JsonKey(name: 'donation_type')
  final String donationType;
  final String? purpose;
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
  @JsonKey(name: 'payment_ref')
  final String? paymentRef;
  @JsonKey(name: 'is_anonymous')
  final bool isAnonymous;
  final String? notes;

  const CreateDonationRequest({
    this.sessionId,
    required this.teamId,
    required this.donorName,
    this.donorPhone,
    this.donorEmail,
    this.donorAddress,
    this.latitude,
    this.longitude,
    required this.amount,
    this.currency,
    required this.donationType,
    this.purpose,
    required this.paymentMethod,
    this.paymentRef,
    this.isAnonymous = false,
    this.notes,
  });

  factory CreateDonationRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateDonationRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateDonationRequestToJson(this);
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
