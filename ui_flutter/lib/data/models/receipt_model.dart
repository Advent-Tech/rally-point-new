import 'package:json_annotation/json_annotation.dart';

part 'receipt_model.g.dart';

@JsonSerializable()
class ReceiptModel {
  final String id;
  @JsonKey(name: 'delivery_id')
  final String? deliveryId;
  @JsonKey(name: 'session_id')
  final String? sessionId;
  @JsonKey(name: 'worker_id')
  final String workerId;
  @JsonKey(name: 'worker_name')
  final String workerName;
  @JsonKey(name: 'team_id')
  final String teamId;
  @JsonKey(name: 'recipient_name')
  final String recipientName;
  @JsonKey(name: 'recipient_phone')
  final String? recipientPhone;
  @JsonKey(name: 'recipient_email')
  final String? recipientEmail;
  final String? address;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'receipt_type')
  final String receiptType;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  final String currency;
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
  @JsonKey(name: 'payment_ref')
  final String? paymentRef;
  final String? notes;
  @JsonKey(name: 'receipt_number')
  final String receiptNumber;
  final String status;
  @JsonKey(name: 'issued_at')
  final DateTime? issuedAt;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const ReceiptModel({
    required this.id,
    this.deliveryId,
    this.sessionId,
    required this.workerId,
    required this.workerName,
    required this.teamId,
    required this.recipientName,
    this.recipientPhone,
    this.recipientEmail,
    this.address,
    this.latitude,
    this.longitude,
    required this.receiptType,
    required this.totalAmount,
    this.currency = 'BDT',
    required this.paymentMethod,
    this.paymentRef,
    this.notes,
    required this.receiptNumber,
    required this.status,
    this.issuedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) => _$ReceiptModelFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptModelToJson(this);

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isRefunded => status == 'refunded';

  bool get isBookSale => receiptType == 'book_sale';
  bool get isLiterature => receiptType == 'literature';
  bool get isDonation => receiptType == 'donation';

  String get receiptTypeDisplay {
    switch (receiptType) {
      case 'book_sale':
        return 'Book Sale';
      case 'literature':
        return 'Literature';
      case 'donation':
        return 'Donation';
      default:
        return receiptType;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  String get formattedAmount => '$currency ${totalAmount.toStringAsFixed(2)}';
}

@JsonSerializable()
class ReceiptItemModel {
  final String id;
  @JsonKey(name: 'receipt_id')
  final String receiptId;
  @JsonKey(name: 'item_type')
  final String itemType;
  @JsonKey(name: 'item_name')
  final String itemName;
  @JsonKey(name: 'item_code')
  final String? itemCode;
  final int quantity;
  @JsonKey(name: 'unit_price')
  final double unitPrice;
  @JsonKey(name: 'total_price')
  final double totalPrice;
  final String? description;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const ReceiptItemModel({
    required this.id,
    required this.receiptId,
    required this.itemType,
    required this.itemName,
    this.itemCode,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.description,
    this.createdAt,
  });

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json) => _$ReceiptItemModelFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptItemModelToJson(this);

  String get itemTypeDisplay {
    switch (itemType) {
      case 'book':
        return 'Book';
      case 'magazine':
        return 'Magazine';
      case 'tract':
        return 'Tract';
      case 'brochure':
        return 'Brochure';
      default:
        return itemType;
    }
  }
}

@JsonSerializable()
class ReceiptWithItemsModel {
  final ReceiptModel receipt;
  final List<ReceiptItemModel> items;

  const ReceiptWithItemsModel({
    required this.receipt,
    required this.items,
  });

  factory ReceiptWithItemsModel.fromJson(Map<String, dynamic> json) =>
      _$ReceiptWithItemsModelFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptWithItemsModelToJson(this);
}

@JsonSerializable()
class CreateReceiptRequest {
  @JsonKey(name: 'delivery_id')
  final String? deliveryId;
  @JsonKey(name: 'session_id')
  final String? sessionId;
  @JsonKey(name: 'team_id')
  final String teamId;
  @JsonKey(name: 'recipient_name')
  final String recipientName;
  @JsonKey(name: 'recipient_phone')
  final String? recipientPhone;
  @JsonKey(name: 'recipient_email')
  final String? recipientEmail;
  final String? address;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'receipt_type')
  final String receiptType;
  final String? currency;
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
  @JsonKey(name: 'payment_ref')
  final String? paymentRef;
  final String? notes;
  final List<CreateReceiptItemRequest> items;

  const CreateReceiptRequest({
    this.deliveryId,
    this.sessionId,
    required this.teamId,
    required this.recipientName,
    this.recipientPhone,
    this.recipientEmail,
    this.address,
    this.latitude,
    this.longitude,
    required this.receiptType,
    this.currency,
    required this.paymentMethod,
    this.paymentRef,
    this.notes,
    required this.items,
  });

  factory CreateReceiptRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateReceiptRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateReceiptRequestToJson(this);
}

@JsonSerializable()
class CreateReceiptItemRequest {
  @JsonKey(name: 'item_type')
  final String itemType;
  @JsonKey(name: 'item_name')
  final String itemName;
  @JsonKey(name: 'item_code')
  final String? itemCode;
  final int quantity;
  @JsonKey(name: 'unit_price')
  final double unitPrice;
  final String? description;

  const CreateReceiptItemRequest({
    required this.itemType,
    required this.itemName,
    this.itemCode,
    required this.quantity,
    required this.unitPrice,
    this.description,
  });

  factory CreateReceiptItemRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateReceiptItemRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateReceiptItemRequestToJson(this);
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
