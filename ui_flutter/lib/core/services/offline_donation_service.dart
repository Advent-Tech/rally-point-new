import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../storage/local_storage.dart';
import '../network/api_client.dart';
import '../constants/api_constants.dart';
import '../../data/models/delivery_model.dart';

/// Service to handle offline donations with automatic sync
class OfflineDonationService {
  static OfflineDonationService? _instance;
  static const String _offlineDonationsKey = 'offline_donations_queue';

  LocalStorage? _localStorage;
  ApiClient? _apiClient;
  bool _isInitialized = false;
  bool _isSyncing = false;

  OfflineDonationService._();

  static Future<OfflineDonationService> getInstance() async {
    if (_instance == null) {
      _instance = OfflineDonationService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _localStorage = await LocalStorage.getInstance();
    _apiClient = await ApiClient.getInstance();
    _isInitialized = true;

    // Listen for connectivity changes and sync when online
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncPendingDonations();
      }
    });
  }

  /// Save a donation for offline sync
  Future<String> saveOfflineDonation(OfflineDonation donation) async {
    final offlineId = const Uuid().v4();
    final donationWithId = donation.copyWith(offlineId: offlineId);

    final pending = await getPendingDonations();
    pending.add(donationWithId);

    await _savePendingDonations(pending);

    debugPrint('Saved offline donation: $offlineId');
    return offlineId;
  }

  /// Get all pending offline donations
  Future<List<OfflineDonation>> getPendingDonations() async {
    if (_localStorage == null) return [];

    final jsonStr = _localStorage!.getString(_offlineDonationsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonStr);
      return jsonList.map((j) => OfflineDonation.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error parsing offline donations: $e');
      return [];
    }
  }

  Future<void> _savePendingDonations(List<OfflineDonation> donations) async {
    if (_localStorage == null) return;

    final jsonStr = json.encode(donations.map((d) => d.toJson()).toList());
    await _localStorage!.setString(_offlineDonationsKey, jsonStr);
  }

  /// Remove a synced donation from the queue
  Future<void> _removeDonation(String offlineId) async {
    final pending = await getPendingDonations();
    pending.removeWhere((d) => d.offlineId == offlineId);
    await _savePendingDonations(pending);
  }

  /// Mark a donation as failed with error message
  Future<void> _markDonationFailed(String offlineId, String error) async {
    final pending = await getPendingDonations();
    final index = pending.indexWhere((d) => d.offlineId == offlineId);
    if (index >= 0) {
      pending[index] = pending[index].copyWith(
        syncError: error,
        syncAttempts: pending[index].syncAttempts + 1,
      );
      await _savePendingDonations(pending);
    }
  }

  /// Sync all pending donations
  Future<SyncResult> syncPendingDonations() async {
    if (_isSyncing) {
      return SyncResult(synced: 0, failed: 0, message: 'Sync already in progress');
    }

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return SyncResult(synced: 0, failed: 0, message: 'No internet connection');
    }

    _isSyncing = true;
    int synced = 0;
    int failed = 0;

    try {
      final pending = await getPendingDonations();
      if (pending.isEmpty) {
        return SyncResult(synced: 0, failed: 0, message: 'No pending donations');
      }

      debugPrint('Syncing ${pending.length} offline donations...');

      for (final donation in pending) {
        // Skip donations that have failed too many times
        if (donation.syncAttempts >= 3) {
          debugPrint('Skipping donation ${donation.offlineId} - too many failures');
          continue;
        }

        try {
          final request = CreateDeliveryRequest(
            teamId: donation.teamId,
            recipientName: donation.donorName,
            recipientPhone: donation.donorPhone,
            address: donation.address,
            latitude: donation.latitude,
            longitude: donation.longitude,
            deliveryType: 'donation',
            priority: 'medium',
            notes: donation.notes,
            territoryId: donation.territoryId,
            donationAmount: donation.amountInCents,
            paymentMethod: donation.paymentMethod,
            offlineId: donation.offlineId,
          );

          final response = await _apiClient!.post(
            ApiConstants.deliveriesCreate,
            data: request.toJson(),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            await _removeDonation(donation.offlineId!);
            synced++;
            debugPrint('Synced donation: ${donation.offlineId}');
          } else {
            await _markDonationFailed(donation.offlineId!, 'Server error: ${response.statusCode}');
            failed++;
          }
        } catch (e) {
          await _markDonationFailed(donation.offlineId!, e.toString());
          failed++;
          debugPrint('Failed to sync donation ${donation.offlineId}: $e');
        }
      }

      return SyncResult(
        synced: synced,
        failed: failed,
        message: 'Synced $synced, failed $failed',
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Get count of pending donations
  Future<int> getPendingCount() async {
    final pending = await getPendingDonations();
    return pending.length;
  }

  /// Clear all pending donations (use with caution)
  Future<void> clearPendingDonations() async {
    await _savePendingDonations([]);
  }
}

/// Represents an offline donation pending sync
class OfflineDonation {
  final String? offlineId;
  final String teamId;
  final String donorName;
  final String? donorPhone;
  final String address;
  final double? latitude;
  final double? longitude;
  final double amountInCents;
  final String paymentMethod; // 'cash' only for offline
  final String? notes;
  final String? territoryId;
  final DateTime createdAt;
  final int syncAttempts;
  final String? syncError;

  OfflineDonation({
    this.offlineId,
    required this.teamId,
    required this.donorName,
    this.donorPhone,
    required this.address,
    this.latitude,
    this.longitude,
    required this.amountInCents,
    this.paymentMethod = 'cash',
    this.notes,
    this.territoryId,
    DateTime? createdAt,
    this.syncAttempts = 0,
    this.syncError,
  }) : createdAt = createdAt ?? DateTime.now();

  OfflineDonation copyWith({
    String? offlineId,
    String? teamId,
    String? donorName,
    String? donorPhone,
    String? address,
    double? latitude,
    double? longitude,
    double? amountInCents,
    String? paymentMethod,
    String? notes,
    String? territoryId,
    DateTime? createdAt,
    int? syncAttempts,
    String? syncError,
  }) {
    return OfflineDonation(
      offlineId: offlineId ?? this.offlineId,
      teamId: teamId ?? this.teamId,
      donorName: donorName ?? this.donorName,
      donorPhone: donorPhone ?? this.donorPhone,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      amountInCents: amountInCents ?? this.amountInCents,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      territoryId: territoryId ?? this.territoryId,
      createdAt: createdAt ?? this.createdAt,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      syncError: syncError ?? this.syncError,
    );
  }

  Map<String, dynamic> toJson() => {
    'offline_id': offlineId,
    'team_id': teamId,
    'donor_name': donorName,
    'donor_phone': donorPhone,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'amount_in_cents': amountInCents,
    'payment_method': paymentMethod,
    'notes': notes,
    'territory_id': territoryId,
    'created_at': createdAt.toIso8601String(),
    'sync_attempts': syncAttempts,
    'sync_error': syncError,
  };

  factory OfflineDonation.fromJson(Map<String, dynamic> json) {
    return OfflineDonation(
      offlineId: json['offline_id'],
      teamId: json['team_id'],
      donorName: json['donor_name'],
      donorPhone: json['donor_phone'],
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      amountInCents: (json['amount_in_cents'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? 'cash',
      notes: json['notes'],
      territoryId: json['territory_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      syncAttempts: json['sync_attempts'] ?? 0,
      syncError: json['sync_error'],
    );
  }
}

/// Result of a sync operation
class SyncResult {
  final int synced;
  final int failed;
  final String message;

  SyncResult({
    required this.synced,
    required this.failed,
    required this.message,
  });

  bool get hasErrors => failed > 0;
  bool get isSuccess => synced > 0 && failed == 0;
}
