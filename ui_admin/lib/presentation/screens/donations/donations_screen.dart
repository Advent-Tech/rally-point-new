import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/user_model.dart';

class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DonationModel> _donations = [];
  List<ReceiptModel> _receipts = [];
  DonationStats? _donationStats;
  ReceiptStats? _receiptStats;
  List<TeamModel> _teams = [];
  String? _selectedTeamId;
  bool _isLoading = true;

  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTeams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    try {
      final api = await ApiClient.getInstance();
      final response = await api.get(ApiConstants.teams);
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['teams'] ?? [];
        setState(() {
          _teams = (data as List).map((json) => TeamModel.fromJson(json)).toList();
          if (_teams.isNotEmpty) {
            _selectedTeamId = _teams.first.id;
            _loadData();
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    if (_selectedTeamId == null) return;

    setState(() => _isLoading = true);
    try {
      final api = await ApiClient.getInstance();

      // Load donations
      final donationsResponse = await api.get(
        '${ApiConstants.donations}/team/$_selectedTeamId',
      );
      if (donationsResponse.statusCode == 200) {
        final data = donationsResponse.data is List
            ? donationsResponse.data
            : donationsResponse.data['donations'] ?? [];
        _donations = (data as List).map((json) => DonationModel.fromJson(json)).toList();
      }

      // Load donation stats
      final statsResponse = await api.get(
        '${ApiConstants.donationStats}/team/$_selectedTeamId',
      );
      if (statsResponse.statusCode == 200) {
        _donationStats = DonationStats.fromJson(statsResponse.data);
      }

      // Load receipts
      final receiptsResponse = await api.get(
        '${ApiConstants.receipts}/team/$_selectedTeamId',
      );
      if (receiptsResponse.statusCode == 200) {
        final data = receiptsResponse.data is List
            ? receiptsResponse.data
            : receiptsResponse.data['receipts'] ?? [];
        _receipts = (data as List).map((json) => ReceiptModel.fromJson(json)).toList();
      }

      // Load receipt stats
      final receiptStatsResponse = await api.get(
        '${ApiConstants.receiptStats}/team/$_selectedTeamId',
      );
      if (receiptStatsResponse.statusCode == 200) {
        _receiptStats = ReceiptStats.fromJson(receiptStatsResponse.data);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donations & Receipts'),
        actions: [
          if (_teams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButton<String>(
                value: _selectedTeamId,
                underline: const SizedBox(),
                items: _teams
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedTeamId = value);
                  _loadData();
                },
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Donations'),
            Tab(text: 'Receipts'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverview(),
                _buildDonationsList(),
                _buildReceiptsList(),
              ],
            ),
    );
  }

  Widget _buildOverview() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Donation Stats
            Text(
              'Donation Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatCard(
                  title: 'Total Donations',
                  value: _currencyFormat.format(_donationStats?.totalAmount ?? 0),
                  subtitle: '${_donationStats?.totalDonations ?? 0} donations',
                  icon: Icons.volunteer_activism,
                  color: AppColors.success,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Average',
                  value: _currencyFormat.format(_donationStats?.averageDonation ?? 0),
                  subtitle: 'per donation',
                  icon: Icons.analytics,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Pending Deposit',
                  value: _currencyFormat.format(_donationStats?.pendingDeposit ?? 0),
                  subtitle: 'awaiting deposit',
                  icon: Icons.pending_actions,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Receipt Stats
            Text(
              'Receipt Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatCard(
                  title: 'Total Receipts',
                  value: _currencyFormat.format(_receiptStats?.totalAmount ?? 0),
                  subtitle: '${_receiptStats?.totalReceipts ?? 0} receipts',
                  icon: Icons.receipt_long,
                  color: AppColors.info,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Book Sales',
                  value: _currencyFormat.format(_receiptStats?.bookSalesAmount ?? 0),
                  subtitle: '${_receiptStats?.bookSalesCount ?? 0} sales',
                  icon: Icons.menu_book,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Literature',
                  value: _currencyFormat.format(_receiptStats?.literatureAmount ?? 0),
                  subtitle: '${_receiptStats?.literatureCount ?? 0} items',
                  icon: Icons.article,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationsList() {
    if (_donations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volunteer_activism_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No Donations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'No donations recorded for this team yet',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _donations.length,
        itemBuilder: (context, index) {
          final donation = _donations[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(donation.status).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.volunteer_activism,
                  color: _getStatusColor(donation.status),
                ),
              ),
              title: Text(
                donation.isAnonymous ? 'Anonymous Donor' : donation.donorName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${donation.donationType} • ${donation.paymentMethod}'),
                  if (donation.createdAt != null)
                    Text(
                      DateFormat('MMM d, yyyy h:mm a').format(donation.createdAt!),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(donation.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(donation.status).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      donation.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(donation.status),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReceiptsList() {
    if (_receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No Receipts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'No receipts recorded for this team yet',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receipts.length,
        itemBuilder: (context, index) {
          final receipt = _receipts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.info),
              ),
              title: Text(
                receipt.recipientName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${receipt.receiptType} • #${receipt.receiptNumber}'),
                  if (receipt.createdAt != null)
                    Text(
                      DateFormat('MMM d, yyyy h:mm a').format(receipt.createdAt!),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
              trailing: Text(
                _currencyFormat.format(receipt.totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'received':
        return AppColors.warning;
      case 'deposited':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
