import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  ApiClient? _apiClient;
  bool _isInitialized = false;
  String? _currentTeamId;

  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardLoadStats>(_onLoadStats);
    on<DashboardRefresh>(_onRefresh);
    on<DashboardLoadActivity>(_onLoadActivity);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _isInitialized = true;
  }

  ApiClient get _api => _apiClient!;

  Future<void> _onLoadStats(
    DashboardLoadStats event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    _currentTeamId = event.teamId;

    try {
      await _initialize();

      // Fetch multiple data sources in parallel
      final results = await Future.wait([
        _fetchTeamMembers(event.teamId),
        _fetchActiveWorkers(event.teamId),
        _fetchTeamAssignments(event.teamId),
        _fetchDeliveries(event.teamId),
        _fetchDonations(event.teamId),
        _fetchBookSales(event.teamId),
        _fetchPrayerRequests(event.teamId),
      ]);

      final members = results[0];
      final activeWorkers = results[1];
      final assignments = results[2];
      final deliveries = results[3];
      final donations = results[4];
      final bookSales = results[5];
      final prayers = results[6];

      // Calculate completion percentage based on deliveries vs total housing units
      // This is more accurate than using completeness_percentage from API which may not update with deliveries
      int totalHousingUnits = 0;
      int totalDeliveriesInTerritories = 0;

      // Build a map of territory_id to delivery count
      final deliveryCountByTerritory = <String, int>{};
      for (var delivery in deliveries) {
        final territoryId = delivery['territory_id']?.toString();
        if (territoryId != null && territoryId.isNotEmpty) {
          deliveryCountByTerritory[territoryId] =
              (deliveryCountByTerritory[territoryId] ?? 0) + 1;
        }
      }

      // Sum up housing units and delivery counts for all assigned territories
      for (var assignment in assignments) {
        // Safely convert housing_units to int (might be num from JSON)
        final housingUnitsValue = assignment['housing_units'];
        final housingUnits = housingUnitsValue is int
            ? housingUnitsValue
            : (housingUnitsValue as num?)?.toInt() ?? 0;
        final territoryId = assignment['territory_id']?.toString();
        totalHousingUnits += housingUnits;
        if (territoryId != null) {
          totalDeliveriesInTerritories +=
              deliveryCountByTerritory[territoryId] ?? 0;
        }
      }

      // Calculate completion as percentage of housing units covered by deliveries
      final avgCompletion = totalHousingUnits > 0
          ? (totalDeliveriesInTerritories / totalHousingUnits * 100).clamp(
              0.0,
              100.0,
            )
          : 0.0;

      // Build activities from deliveries and donations (these are the actual "visits")
      final activities = _buildActivitiesFromDeliveriesAndDonations(
        deliveries,
        donations,
        bookSales,
      );

      // Build worker performance from deliveries and assignments
      final workerPerformance = _buildWorkerPerformance(
        deliveries,
        donations,
        bookSales,
        prayers,
        members,
        activeWorkers,
        assignments,
      );

      final totalBookSalesAmount = bookSales.fold<double>(0.0, (sum, sale) {
        final amount =
            (sale['total_amount'] as num? ?? sale['amount'] as num? ?? 0)
                .toDouble();
        return sum + amount;
      });

      final stats = TeamDashboardStats(
        totalMembers: members.length,
        activeWorkers: activeWorkers.length,
        totalTerritories: assignments.length,
        completionPercentage: avgCompletion,
        visitsToday: _countVisitsToday(deliveries, donations, bookSales),
        visitsThisWeek: _countVisitsThisWeek(deliveries, donations, bookSales),
        totalDeliveries: deliveries.length,
        totalDonations: donations.length,
        totalBookSales: bookSales.length,
        totalBookSalesAmount: totalBookSalesAmount,
      );

      // Build territory stats from assignments with delivery counts
      final territoryStats = _buildTerritoryStats(
        assignments,
        members,
        deliveries,
        donations,
        bookSales,
      );

      emit(
        DashboardLoaded(
          stats: stats,
          recentActivity: activities,
          workerPerformance: workerPerformance,
          territoryStats: territoryStats,
        ),
      );
    } catch (e) {
      emit(DashboardError(message: e.toString()));
    }
  }

  Future<List<dynamic>> _fetchTeamMembers(String teamId) async {
    try {
      final response = await _api.get('${ApiConstants.teams}/$teamId/workers');
      if (response.statusCode == 200) {
        return response.data is List
            ? response.data
            : (response.data['workers'] ?? response.data['members'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _fetchActiveWorkers(String teamId) async {
    try {
      final response = await _api.get(
        ApiConstants.workersActive,
        queryParameters: {'team_id': teamId},
      );
      if (response.statusCode == 200) {
        return response.data is List
            ? response.data
            : (response.data['workers'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _fetchTeamAssignments(String teamId) async {
    try {
      final response = await _api.get(
        ApiConstants.assignments,
        queryParameters: {'team_id': teamId},
      );
      if (response.statusCode == 200) {
        return response.data is List
            ? response.data
            : (response.data['assignments'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _fetchDeliveries(String teamId) async {
    try {
      final response = await _api.get('/api/teams/$teamId/deliveries');
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : (response.data['deliveries'] ?? []);
        // Handle nested structure: { "delivery": {...}, "items": [...] }
        return data.map((json) {
          if (json is Map && json.containsKey('delivery')) {
            return json['delivery'] as Map<String, dynamic>;
          }
          return json;
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _fetchDonations(String teamId) async {
    try {
      final response = await _api.get('/api/donations/team/$teamId');
      if (response.statusCode == 200) {
        return response.data is List
            ? response.data
            : (response.data['donations'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _fetchBookSales(String teamId) async {
    try {
      final response = await _api.get('${ApiConstants.bookSalesTeam}/$teamId');
      if (response.statusCode == 200) {
        return response.data is List
            ? response.data
            : (response.data['book_sales'] ??
                  response.data['results'] ??
                  response.data['data'] ??
                  []);
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _fetchPrayerRequests(String teamId) async {
    try {
      final response = await _api.get('/api/prayer-requests/team/$teamId');
      if (response.statusCode == 200) {
        return response.data is List
            ? response.data
            : (response.data['prayer_requests'] ??
                  response.data['items'] ??
                  []);
      }
    } catch (_) {}
    return [];
  }

  List<TeamActivity> _buildActivitiesFromDeliveriesAndDonations(
    List<dynamic> deliveries,
    List<dynamic> donations,
    List<dynamic> bookSales,
  ) {
    final activities = <TeamActivity>[];

    // Add delivery activities
    for (var delivery in deliveries) {
      activities.add(
        TeamActivity(
          id: delivery['id']?.toString() ?? '',
          type: 'delivery',
          workerId: delivery['worker_id']?.toString() ?? '',
          workerName: delivery['worker_name']?.toString() ?? 'Worker',
          description:
              'Delivered to ${delivery['recipient_name'] ?? 'recipient'}',
          territoryName: delivery['address']?.toString(),
          address: delivery['address']?.toString(),
          timestamp: delivery['created_at'] != null
              ? DateTime.tryParse(delivery['created_at'].toString()) ??
                    DateTime.now()
              : DateTime.now(),
          metadata: {'status': delivery['status'], 'type': 'delivery'},
        ),
      );
    }

    // Add book sale activities
    for (var sale in bookSales) {
      final amount = (sale['total_amount'] ?? sale['amount'] ?? 0).toDouble();
      final quantity = (sale['quantity'] as num? ?? 1).toInt();
      final bookTitle =
          sale['book_title']?.toString().trim().isNotEmpty == true
          ? sale['book_title'].toString()
          : 'Book Sale';

      activities.add(
        TeamActivity(
          id: sale['id']?.toString() ?? '',
          type: 'book_sale',
          workerId: sale['worker_id']?.toString() ?? '',
          workerName: sale['worker_name']?.toString() ?? 'Worker',
          description: 'Sold $quantity x $bookTitle (\$${amount.toStringAsFixed(2)})',
          territoryName:
              sale['buyer_address']?.toString() ?? sale['location']?.toString(),
          address:
              sale['buyer_address']?.toString() ?? sale['location']?.toString(),
          timestamp: sale['sold_at'] != null
              ? DateTime.tryParse(sale['sold_at'].toString()) ?? DateTime.now()
              : (sale['created_at'] != null
                    ? DateTime.tryParse(sale['created_at'].toString()) ??
                          DateTime.now()
                    : DateTime.now()),
          metadata: {
            'type': 'book_sale',
            'book_title': bookTitle,
            'quantity': quantity,
            'amount': amount,
            'buyer_name': sale['buyer_name'],
          },
        ),
      );
    }

    // Add donation activities
    for (var donation in donations) {
      activities.add(
        TeamActivity(
          id: donation['id']?.toString() ?? '',
          type: 'donation',
          workerId:
              donation['worker_id']?.toString() ??
              donation['collected_by_id']?.toString() ??
              '',
          workerName:
              donation['worker_name']?.toString() ??
              donation['collected_by_name']?.toString() ??
              'Worker',
          description: 'Collected donation: \$${donation['amount'] ?? 0}',
          territoryName: donation['location']?.toString(),
          address: donation['location']?.toString(),
          timestamp: donation['created_at'] != null
              ? DateTime.tryParse(donation['created_at'].toString()) ??
                    DateTime.now()
              : DateTime.now(),
          metadata: {'amount': donation['amount'], 'type': 'donation'},
        ),
      );
    }

    // Sort by timestamp descending
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(20).toList();
  }

  int _countVisitsToday(
    List<dynamic> deliveries,
    List<dynamic> donations,
    List<dynamic> bookSales,
  ) {
    final today = DateTime.now();
    int count = 0;

    for (var delivery in deliveries) {
      final createdAt = delivery['created_at'] != null
          ? DateTime.tryParse(delivery['created_at'].toString())
          : null;
      if (createdAt != null &&
          createdAt.year == today.year &&
          createdAt.month == today.month &&
          createdAt.day == today.day) {
        count++;
      }
    }

    for (var donation in donations) {
      final createdAt = donation['created_at'] != null
          ? DateTime.tryParse(donation['created_at'].toString())
          : null;
      if (createdAt != null &&
          createdAt.year == today.year &&
          createdAt.month == today.month &&
          createdAt.day == today.day) {
        count++;
      }
    }

    for (var sale in bookSales) {
      final soldAt = sale['sold_at'] ?? sale['created_at'];
      final createdAt = soldAt != null
          ? DateTime.tryParse(soldAt.toString())
          : null;
      if (createdAt != null &&
          createdAt.year == today.year &&
          createdAt.month == today.month &&
          createdAt.day == today.day) {
        count++;
      }
    }

    return count;
  }

  int _countVisitsThisWeek(
    List<dynamic> deliveries,
    List<dynamic> donations,
    List<dynamic> bookSales,
  ) {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    int count = 0;

    for (var delivery in deliveries) {
      final createdAt = delivery['created_at'] != null
          ? DateTime.tryParse(delivery['created_at'].toString())
          : null;
      if (createdAt != null && createdAt.isAfter(weekStart)) {
        count++;
      }
    }

    for (var donation in donations) {
      final createdAt = donation['created_at'] != null
          ? DateTime.tryParse(donation['created_at'].toString())
          : null;
      if (createdAt != null && createdAt.isAfter(weekStart)) {
        count++;
      }
    }

    for (var sale in bookSales) {
      final soldAt = sale['sold_at'] ?? sale['created_at'];
      final createdAt = soldAt != null
          ? DateTime.tryParse(soldAt.toString())
          : null;
      if (createdAt != null && createdAt.isAfter(weekStart)) {
        count++;
      }
    }

    return count;
  }

  List<WorkerPerformance> _buildWorkerPerformance(
    List<dynamic> deliveries,
    List<dynamic> donations,
    List<dynamic> bookSales,
    List<dynamic> prayers,
    List<dynamic> members,
    List<dynamic> activeWorkers,
    List<dynamic> assignments,
  ) {
    final performanceList = <WorkerPerformance>[];
    final activeWorkerIds = <String>{};

    // Count active workers
    for (var worker in activeWorkers) {
      final id = worker['id']?.toString() ?? worker['user_id']?.toString();
      if (id != null) activeWorkerIds.add(id);
    }

    // Count donations per worker
    final workerDonationsCount = <String, int>{};
    final workerDonationsTotal = <String, double>{};
    for (var donation in donations) {
      final workerId =
          donation['worker_id']?.toString() ??
          donation['collected_by_id']?.toString();
      if (workerId != null) {
        workerDonationsCount[workerId] =
            (workerDonationsCount[workerId] ?? 0) + 1;
        final amount = (donation['amount'] ?? 0).toDouble();
        workerDonationsTotal[workerId] =
            (workerDonationsTotal[workerId] ?? 0) + amount;
      }
    }

    // Count book sales per worker
    final workerBookSalesCount = <String, int>{};
    final workerBookSalesTotal = <String, double>{};
    for (var sale in bookSales) {
      final workerId = sale['worker_id']?.toString();
      if (workerId != null && workerId.isNotEmpty) {
        workerBookSalesCount[workerId] = (workerBookSalesCount[workerId] ?? 0) + 1;
        final amount =
            (sale['total_amount'] as num? ?? sale['amount'] as num? ?? 0)
                .toDouble();
        workerBookSalesTotal[workerId] =
            (workerBookSalesTotal[workerId] ?? 0) + amount;
      }
    }

    // Count prayers per worker
    final workerPrayersCount = <String, int>{};
    for (var prayer in prayers) {
      final workerId = prayer['worker_id']?.toString();
      if (workerId != null) {
        workerPrayersCount[workerId] = (workerPrayersCount[workerId] ?? 0) + 1;
      }
    }

    // Group assignments by worker and calculate weighted coverage
    final workerAssignments = <String, List<Map<String, dynamic>>>{};
    for (var assignment in assignments) {
      final workerId =
          assignment['assigned_worker_id']?.toString() ??
          assignment['worker_id']?.toString();
      if (workerId != null) {
        workerAssignments.putIfAbsent(workerId, () => []).add(assignment);
      }
    }

    // Build performance list from members
    for (var member in members) {
      final id =
          member['id']?.toString() ?? member['user_id']?.toString() ?? '';
      final firstName = member['first_name']?.toString() ?? '';
      final lastName = member['last_name']?.toString() ?? '';
      final fullName =
          member['display_name']?.toString() ??
          member['name']?.toString() ??
          member['full_name']?.toString() ??
          '$firstName $lastName'.trim();

      final assignmentsForMember = workerAssignments[id] ?? [];
      final territoryCoverage = _calculateWeightedCoverage(
        assignmentsForMember,
      );

      performanceList.add(
        WorkerPerformance(
          id: id,
          name: fullName.isNotEmpty ? fullName : 'Unknown Worker',
          avatarUrl:
              member['avatar_url']?.toString() ??
              member['avatarUrl']?.toString(),
          donationsCount: workerDonationsCount[id] ?? 0,
          donationsTotal: workerDonationsTotal[id] ?? 0.0,
          bookSalesCount: workerBookSalesCount[id] ?? 0,
          bookSalesTotal: workerBookSalesTotal[id] ?? 0.0,
          prayersCount: workerPrayersCount[id] ?? 0,
          territoriesAssigned: assignmentsForMember.length,
          territoryCoverage: territoryCoverage,
          isActive: activeWorkerIds.contains(id),
        ),
      );
    }

    // Sort by donations total descending
    performanceList.sort(
      (a, b) => b.totalGiving.compareTo(a.totalGiving),
    );
    return performanceList;
  }

  double _calculateWeightedCoverage(List<Map<String, dynamic>> assignments) {
    double totalHousingUnits = 0;
    double weightedSum = 0;

    for (var assignment in assignments) {
      final housingUnits = (assignment['housing_units'] ?? 0).toDouble();
      final completeness = (assignment['completeness_percentage'] ?? 0)
          .toDouble();

      totalHousingUnits += housingUnits;
      weightedSum += housingUnits * completeness;
    }

    return totalHousingUnits > 0 ? weightedSum / totalHousingUnits : 0;
  }

  List<TerritoryStats> _buildTerritoryStats(
    List<dynamic> assignments,
    List<dynamic> members,
    List<dynamic> deliveries,
    List<dynamic> donations,
    List<dynamic> bookSales,
  ) {
    final territoryStats = <TerritoryStats>[];

    // Create a lookup map for member names
    final memberNames = <String, String>{};
    for (var member in members) {
      final id = member['id']?.toString() ?? member['user_id']?.toString();
      if (id != null) {
        final firstName = member['first_name']?.toString() ?? '';
        final lastName = member['last_name']?.toString() ?? '';
        final fullName =
            member['display_name']?.toString() ??
            member['name']?.toString() ??
            member['full_name']?.toString() ??
            '$firstName $lastName'.trim();
        memberNames[id] = fullName.isNotEmpty ? fullName : 'Unknown';
      }
    }

    // Count deliveries per territory using territory_id from deliveries
    final deliveriesPerTerritory = <String, int>{};
    final totalVisitsPerTerritory = <String, int>{};

    for (var delivery in deliveries) {
      // Use territory_id directly from delivery if available
      final territoryId = delivery['territory_id']?.toString();
      if (territoryId != null && territoryId.isNotEmpty) {
        deliveriesPerTerritory[territoryId] =
            (deliveriesPerTerritory[territoryId] ?? 0) + 1;
        totalVisitsPerTerritory[territoryId] =
            (totalVisitsPerTerritory[territoryId] ?? 0) + 1;
      }
    }

    for (var donation in donations) {
      final territoryId = donation['territory_id']?.toString();
      if (territoryId != null && territoryId.isNotEmpty) {
        totalVisitsPerTerritory[territoryId] =
            (totalVisitsPerTerritory[territoryId] ?? 0) + 1;
      }
    }

    for (var sale in bookSales) {
      final territoryId = sale['territory_id']?.toString();
      if (territoryId != null && territoryId.isNotEmpty) {
        totalVisitsPerTerritory[territoryId] =
            (totalVisitsPerTerritory[territoryId] ?? 0) + 1;
      }
    }

    for (var assignment in assignments) {
      final assignmentId = assignment['id']?.toString() ?? '';
      // Use territory_id for matching with deliveries
      final territoryId =
          assignment['territory_id']?.toString() ?? assignmentId;
      // Use assigned_worker_id (not worker_id) - this is the correct field name from API
      final workerId =
          assignment['assigned_worker_id']?.toString() ??
          assignment['worker_id']?.toString();
      final workerName = assignment['worker_name']?.toString();

      // Get assignee name from member lookup or assignment data
      String? assigneeName;
      if (workerId != null) {
        assigneeName = memberNames[workerId] ?? workerName;
      } else if (workerName != null && workerName.isNotEmpty) {
        assigneeName = workerName;
      }

      // Use delivery count as visited count (households covered) - match by territory_id
      final visitedFromDeliveries = totalVisitsPerTerritory[territoryId] ?? 0;
      final housingUnits = assignment['housing_units'] ?? 0;

      // Calculate completion rate based on deliveries
      double completionRate;
      if (housingUnits > 0) {
        completionRate = (visitedFromDeliveries / housingUnits * 100)
            .clamp(0.0, 100.0)
            .toDouble();
      } else {
        // If no housing units defined, use delivery count as indicator
        completionRate = visitedFromDeliveries > 0 ? 50.0 : 0.0;
      }

      territoryStats.add(
        TerritoryStats(
          id: assignmentId,
          name:
              assignment['entity_name']?.toString() ??
              assignment['territory_name']?.toString() ??
              'Unknown Territory',
          assigneeName: assigneeName,
          assigneeId: workerId,
          housingUnits: housingUnits > 0 ? housingUnits : visitedFromDeliveries,
          visitedCount: visitedFromDeliveries,
          completionRate: completionRate,
          status: assignment['status']?.toString(),
        ),
      );
    }

    // Sort by completion rate ascending (least complete first)
    territoryStats.sort((a, b) => a.completionRate.compareTo(b.completionRate));

    return territoryStats;
  }

  Future<void> _onRefresh(
    DashboardRefresh event,
    Emitter<DashboardState> emit,
  ) async {
    if (_currentTeamId != null) {
      add(DashboardLoadStats(teamId: _currentTeamId!));
    }
  }

  Future<void> _onLoadActivity(
    DashboardLoadActivity event,
    Emitter<DashboardState> emit,
  ) async {
    // This can be used to load more activity with pagination
    // For now, activity is loaded with stats
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      try {
        await _initialize();
        final deliveries = await _fetchDeliveries(event.teamId);
        final donations = await _fetchDonations(event.teamId);
        final bookSales = await _fetchBookSales(event.teamId);
        final activities = _buildActivitiesFromDeliveriesAndDonations(
          deliveries,
          donations,
          bookSales,
        );
        emit(
          DashboardLoaded(
            stats: currentState.stats,
            recentActivity: activities,
            workerPerformance: currentState.workerPerformance,
            territoryStats: currentState.territoryStats,
          ),
        );
      } catch (e) {
        // Keep current state on error
      }
    }
  }
}
