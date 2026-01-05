// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReceiptModel _$ReceiptModelFromJson(Map<String, dynamic> json) => ReceiptModel(
      id: json['id'] as String,
      deliveryId: json['delivery_id'] as String?,
      sessionId: json['session_id'] as String?,
      workerId: json['worker_id'] as String,
      workerName: json['worker_name'] as String,
      teamId: json['team_id'] as String,
      recipientName: json['recipient_name'] as String,
      recipientPhone: json['recipient_phone'] as String?,
      recipientEmail: json['recipient_email'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      receiptType: json['receipt_type'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'BDT',
      paymentMethod: json['payment_method'] as String,
      paymentRef: json['payment_ref'] as String?,
      notes: json['notes'] as String?,
      receiptNumber: json['receipt_number'] as String,
      status: json['status'] as String,
      issuedAt: json['issued_at'] == null
          ? null
          : DateTime.parse(json['issued_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ReceiptModelToJson(ReceiptModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'delivery_id': instance.deliveryId,
      'session_id': instance.sessionId,
      'worker_id': instance.workerId,
      'worker_name': instance.workerName,
      'team_id': instance.teamId,
      'recipient_name': instance.recipientName,
      'recipient_phone': instance.recipientPhone,
      'recipient_email': instance.recipientEmail,
      'address': instance.address,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'receipt_type': instance.receiptType,
      'total_amount': instance.totalAmount,
      'currency': instance.currency,
      'payment_method': instance.paymentMethod,
      'payment_ref': instance.paymentRef,
      'notes': instance.notes,
      'receipt_number': instance.receiptNumber,
      'status': instance.status,
      'issued_at': instance.issuedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

ReceiptItemModel _$ReceiptItemModelFromJson(Map<String, dynamic> json) =>
    ReceiptItemModel(
      id: json['id'] as String,
      receiptId: json['receipt_id'] as String,
      itemType: json['item_type'] as String,
      itemName: json['item_name'] as String,
      itemCode: json['item_code'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      description: json['description'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ReceiptItemModelToJson(ReceiptItemModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'receipt_id': instance.receiptId,
      'item_type': instance.itemType,
      'item_name': instance.itemName,
      'item_code': instance.itemCode,
      'quantity': instance.quantity,
      'unit_price': instance.unitPrice,
      'total_price': instance.totalPrice,
      'description': instance.description,
      'created_at': instance.createdAt?.toIso8601String(),
    };

ReceiptWithItemsModel _$ReceiptWithItemsModelFromJson(
        Map<String, dynamic> json) =>
    ReceiptWithItemsModel(
      receipt: ReceiptModel.fromJson(json['receipt'] as Map<String, dynamic>),
      items: (json['items'] as List<dynamic>)
          .map((e) => ReceiptItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ReceiptWithItemsModelToJson(
        ReceiptWithItemsModel instance) =>
    <String, dynamic>{
      'receipt': instance.receipt,
      'items': instance.items,
    };

CreateReceiptRequest _$CreateReceiptRequestFromJson(
        Map<String, dynamic> json) =>
    CreateReceiptRequest(
      deliveryId: json['delivery_id'] as String?,
      sessionId: json['session_id'] as String?,
      teamId: json['team_id'] as String,
      recipientName: json['recipient_name'] as String,
      recipientPhone: json['recipient_phone'] as String?,
      recipientEmail: json['recipient_email'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      receiptType: json['receipt_type'] as String,
      currency: json['currency'] as String?,
      paymentMethod: json['payment_method'] as String,
      paymentRef: json['payment_ref'] as String?,
      notes: json['notes'] as String?,
      items: (json['items'] as List<dynamic>)
          .map((e) =>
              CreateReceiptItemRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CreateReceiptRequestToJson(
        CreateReceiptRequest instance) =>
    <String, dynamic>{
      'delivery_id': instance.deliveryId,
      'session_id': instance.sessionId,
      'team_id': instance.teamId,
      'recipient_name': instance.recipientName,
      'recipient_phone': instance.recipientPhone,
      'recipient_email': instance.recipientEmail,
      'address': instance.address,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'receipt_type': instance.receiptType,
      'currency': instance.currency,
      'payment_method': instance.paymentMethod,
      'payment_ref': instance.paymentRef,
      'notes': instance.notes,
      'items': instance.items,
    };

CreateReceiptItemRequest _$CreateReceiptItemRequestFromJson(
        Map<String, dynamic> json) =>
    CreateReceiptItemRequest(
      itemType: json['item_type'] as String,
      itemName: json['item_name'] as String,
      itemCode: json['item_code'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$CreateReceiptItemRequestToJson(
        CreateReceiptItemRequest instance) =>
    <String, dynamic>{
      'item_type': instance.itemType,
      'item_name': instance.itemName,
      'item_code': instance.itemCode,
      'quantity': instance.quantity,
      'unit_price': instance.unitPrice,
      'description': instance.description,
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
      averageReceiptValue:
          (json['average_receipt_value'] as num?)?.toDouble() ?? 0,
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
