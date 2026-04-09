import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Service for generating digital donation receipts
class ReceiptService {
  static ReceiptService? _instance;

  ReceiptService._();

  static ReceiptService getInstance() {
    _instance ??= ReceiptService._();
    return _instance!;
  }

  /// Generate a receipt image for a donation
  Future<ReceiptResult> generateReceipt({
    required String receiptNumber,
    required String donorName,
    required double amountInCents,
    required String paymentMethod,
    required DateTime date,
    String? organizationName,
    String? organizationAddress,
    String? workerName,
    String? notes,
  }) async {
    try {
      final formatter = NumberFormat.currency(symbol: '\$');
      final dateFormatter = DateFormat('MMMM d, yyyy h:mm a');
      final amount = amountInCents / 100;

      // Create receipt content
      final receipt = ReceiptData(
        receiptNumber: receiptNumber,
        donorName: donorName,
        amount: formatter.format(amount),
        paymentMethod: _formatPaymentMethod(paymentMethod),
        date: dateFormatter.format(date),
        organizationName: organizationName ?? 'Rally Point Ministry',
        organizationAddress: organizationAddress,
        workerName: workerName,
        notes: notes,
      );

      // Generate receipt as text (can be enhanced to generate PDF/image)
      final receiptText = _generateReceiptText(receipt);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/receipts/receipt_$receiptNumber.txt';

      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(receiptText);

      return ReceiptResult.success(
        receiptNumber: receiptNumber,
        filePath: filePath,
        receiptText: receiptText,
      );
    } catch (e) {
      return ReceiptResult.failure('Failed to generate receipt: $e');
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Credit/Debit Card';
      case 'online':
        return 'Online Payment';
      default:
        return method;
    }
  }

  String _generateReceiptText(ReceiptData data) {
    final buffer = StringBuffer();

    buffer.writeln('=' * 50);
    buffer.writeln();
    buffer.writeln('        DONATION RECEIPT');
    buffer.writeln();
    buffer.writeln('=' * 50);
    buffer.writeln();
    buffer.writeln(data.organizationName);
    if (data.organizationAddress != null) {
      buffer.writeln(data.organizationAddress);
    }
    buffer.writeln();
    buffer.writeln('-' * 50);
    buffer.writeln();
    buffer.writeln('Receipt #: ${data.receiptNumber}');
    buffer.writeln('Date: ${data.date}');
    buffer.writeln();
    buffer.writeln('-' * 50);
    buffer.writeln();
    buffer.writeln('Donor: ${data.donorName}');
    buffer.writeln();
    buffer.writeln('Amount: ${data.amount}');
    buffer.writeln('Payment Method: ${data.paymentMethod}');
    buffer.writeln();
    if (data.workerName != null) {
      buffer.writeln('Received by: ${data.workerName}');
      buffer.writeln();
    }
    if (data.notes != null && data.notes!.isNotEmpty) {
      buffer.writeln('Notes: ${data.notes}');
      buffer.writeln();
    }
    buffer.writeln('-' * 50);
    buffer.writeln();
    buffer.writeln('Thank you for your generous donation!');
    buffer.writeln();
    buffer.writeln('This receipt serves as confirmation of your');
    buffer.writeln('contribution. Please retain for your records.');
    buffer.writeln();
    buffer.writeln('=' * 50);

    return buffer.toString();
  }

  /// Generate a shareable receipt message
  String generateShareableReceipt({
    required String receiptNumber,
    required String donorName,
    required double amountInCents,
    required String paymentMethod,
    required DateTime date,
    String? organizationName,
  }) {
    final formatter = NumberFormat.currency(symbol: '\$');
    final dateFormatter = DateFormat('MMM d, yyyy');
    final amount = amountInCents / 100;

    return '''
Donation Receipt

Receipt #: $receiptNumber
Date: ${dateFormatter.format(date)}
Donor: $donorName
Amount: ${formatter.format(amount)}
Payment: ${_formatPaymentMethod(paymentMethod)}

Thank you for your donation to ${organizationName ?? 'Rally Point Ministry'}!
''';
  }
}

/// Data class for receipt information
class ReceiptData {
  final String receiptNumber;
  final String donorName;
  final String amount;
  final String paymentMethod;
  final String date;
  final String organizationName;
  final String? organizationAddress;
  final String? workerName;
  final String? notes;

  ReceiptData({
    required this.receiptNumber,
    required this.donorName,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    required this.organizationName,
    this.organizationAddress,
    this.workerName,
    this.notes,
  });
}

/// Result of receipt generation
class ReceiptResult {
  final bool isSuccess;
  final String? receiptNumber;
  final String? filePath;
  final String? receiptText;
  final String? errorMessage;

  ReceiptResult._({
    required this.isSuccess,
    this.receiptNumber,
    this.filePath,
    this.receiptText,
    this.errorMessage,
  });

  factory ReceiptResult.success({
    required String receiptNumber,
    required String filePath,
    required String receiptText,
  }) {
    return ReceiptResult._(
      isSuccess: true,
      receiptNumber: receiptNumber,
      filePath: filePath,
      receiptText: receiptText,
    );
  }

  factory ReceiptResult.failure(String message) {
    return ReceiptResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// Generate a unique receipt number
String generateReceiptNumber() {
  final now = DateTime.now();
  final timestamp = now.millisecondsSinceEpoch.toString().substring(5);
  final random = DateTime.now().microsecond.toString().padLeft(6, '0').substring(0, 4);
  return 'RCP-$timestamp-$random';
}
