import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/delivery_model.dart';
import '../../../data/repositories/territory_repository.dart';
import '../../../services/coach_marks_service.dart';
import '../../blocs/delivery/delivery_bloc.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/animations/staggered_fade_in.dart';
import '../../widgets/animations/success_check.dart';
import '../../widgets/stepper/step_progress_bar.dart';
import '../../widgets/states/empty_state.dart';

/// Date filter options
enum DateFilter { today, thisWeek, thisMonth, all }

class _BookOption {
  final String code;
  final String title;
  final String language;
  final double unitPrice;
  final String assetPath;

  const _BookOption({
    required this.code,
    required this.title,
    required this.language,
    required this.unitPrice,
    required this.assetPath,
  });
}

const List<_BookOption> _bookCatalog = [
  _BookOption(
    code: 'GC_EN',
    title: 'The Great Controversy Book, Thrive Magazine, & Doorknob Bag',
    language: 'english',
    unitPrice: 2.50,
    assetPath: 'assets/books/great_contoversy.png',
  ),
  _BookOption(
    code: 'GC_ES',
    title: 'The Great Controversy Book, Thrive Magazine, & Doorknob Bag (Spanish)',
    language: 'spanish',
    unitPrice: 2.50,
    assetPath: 'assets/books/great_contoversy_spanish.png',
  ),
  _BookOption(
    code: 'WLD_EN',
    title: 'When Light and Darkness Collide, Thrive Magazine, & Doorknob Bag',
    language: 'english',
    unitPrice: 2.50,
    assetPath: 'assets/books/whenLDcollide.png',
  ),
  _BookOption(
    code: 'WLD_ES',
    title: 'When Light and Darkness Collide, Thrive Magazine, & Doorknob Bag (Spanish)',
    language: 'spanish',
    unitPrice: 2.50,
    assetPath: 'assets/books/whenLDcollide_spanish.png',
  ),
];

/// Simplified Delivery Screen for field workers
/// Workers record donations on the spot - no pending states
class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  DateFilter _selectedFilter = DateFilter.all;

  // Coach mark keys
  final _showcaseSummary = GlobalKey();
  final _showcaseRecord = GlobalKey();
  final _showcaseFilters = GlobalKey();
  bool _coachMarksChecked = false;

  static const _tooltipTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1E293B),
    letterSpacing: -0.2,
  );
  static const _tooltipDescStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: Color(0xFF64748B),
    height: 1.4,
  );
  static final _tooltipRadius = BorderRadius.circular(14);
  static const _tooltipPadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  );

  @override
  void initState() {
    super.initState();
    context.read<DeliveryBloc>().add(const DeliveryLoadList());
  }

  List<DeliveryModel> _filterDeliveries(List<DeliveryModel> deliveries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    return deliveries.where((d) {
      final createdAt = d.createdAt ?? d.completedAt;
      if (createdAt == null) return false;

      // Convert to local time for proper date comparison (backend returns UTC)
      final localCreatedAt = createdAt.toLocal();
      final localDate = DateTime(
        localCreatedAt.year,
        localCreatedAt.month,
        localCreatedAt.day,
      );

      switch (_selectedFilter) {
        case DateFilter.today:
          return localDate.isAtSameMomentAs(today) || localDate.isAfter(today);
        case DateFilter.thisWeek:
          return localDate.isAtSameMomentAs(weekStart) ||
              localDate.isAfter(weekStart);
        case DateFilter.thisMonth:
          return localDate.isAtSameMomentAs(monthStart) ||
              localDate.isAfter(monthStart);
        case DateFilter.all:
          return true;
      }
    }).toList();
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case DateFilter.today:
        return "Today's Activity";
      case DateFilter.thisWeek:
        return "This Week";
      case DateFilter.thisMonth:
        return "This Month";
      case DateFilter.all:
        return "All Activity";
    }
  }

  void _maybeShowCoachMarks() {
    if (_coachMarksChecked) return;
    _coachMarksChecked = true;
    CoachMarksService().hasBeenShown('delivery').then((shown) {
      if (!shown && mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            ShowcaseView.get().startShowCase([
              _showcaseSummary,
              _showcaseRecord,
              _showcaseFilters,
            ]);
            CoachMarksService().markAsShown('delivery');
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ignore: deprecated_member_use
    return ShowCaseWidget(
      onFinish: () {},
      enableAutoScroll: true,
      builder: (_) {
        _maybeShowCoachMarks();
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            title: const Text('Field Activity'),
            actions: [
              const RoleBadge(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<DeliveryBloc>().add(const DeliveryRefresh());
                },
              ),
            ],
          ),
          body: BlocConsumer<DeliveryBloc, DeliveryState>(
            listener: (context, state) {
              if (state is DeliveryError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.error,
                  ),
                );
              } else if (state is DeliveryCreateSuccess) {
                SuccessOverlay.show(
                  context,
                  message: 'Recorded successfully!',
                ).then((_) {
                  if (context.mounted) {
                    context.read<DeliveryBloc>().add(const DeliveryLoadList());
                  }
                });
              }
            },
            builder: (context, state) {
              List<DeliveryModel> filteredDeliveries = [];
              List<DeliveryModel> todayDeliveries = [];

              if (state is DeliveryListLoaded) {
                filteredDeliveries = _filterDeliveries(state.deliveries);
                // Always calculate today's totals for the summary card
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                todayDeliveries = state.deliveries.where((d) {
                  final createdAt = d.createdAt ?? d.completedAt;
                  if (createdAt == null) return false;
                  // Convert to local time for proper date comparison (backend returns UTC)
                  final localCreatedAt = createdAt.toLocal();
                  final localDate = DateTime(
                    localCreatedAt.year,
                    localCreatedAt.month,
                    localCreatedAt.day,
                  );
                  return localDate.isAtSameMomentAs(today);
                }).toList();
              }

              // Calculate today's totals for summary
              final donations = todayDeliveries.where((d) => d.isDonation).toList();
              final bookSales = todayDeliveries.where((d) => d.isBookSale).toList();
              final totalDonationAmount = donations.fold<double>(
                0,
                (sum, d) => sum + (d.donationAmount ?? 0),
              );
              final totalBookSalesAmount = bookSales.fold<double>(
                0,
                (sum, d) => sum + (d.donationAmount ?? 0),
              );

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<DeliveryBloc>().add(const DeliveryRefresh());
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Today's Summary Card
                      Showcase(
                        key: _showcaseSummary,
                        title: "Today's Summary",
                        description:
                            'See your daily donation totals at a glance. This updates as you record donations.',
                        titleTextStyle: _tooltipTitleStyle,
                        descTextStyle: _tooltipDescStyle,
                        tooltipBorderRadius: _tooltipRadius,
                        tooltipPadding: _tooltipPadding,
                        targetBorderRadius: BorderRadius.circular(20),
                        child: _TodaySummaryCard(
                          donationsCount: donations.length,
                          donationsAmount: totalDonationAmount,
                          bookSalesCount: bookSales.length,
                          bookSalesAmount: totalBookSalesAmount,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: Showcase(
                              key: _showcaseRecord,
                              title: 'Record Donation',
                              description:
                                  'Tap here to record a new donation. Your GPS location is automatically captured.',
                              titleTextStyle: _tooltipTitleStyle,
                              descTextStyle: _tooltipDescStyle,
                              tooltipBorderRadius: _tooltipRadius,
                              tooltipPadding: _tooltipPadding,
                              targetBorderRadius: BorderRadius.circular(16),
                              child: _ActionButton(
                                icon: Icons.volunteer_activism,
                                label: 'Record Donation',
                                color: AppColors.success,
                                onTap: () => _showRecordSheet(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.menu_book_rounded,
                              label: 'Record Book Sale',
                              color: AppColors.primary,
                              onTap: () => _showBookSaleSheet(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Date Filter Chips
                      Showcase(
                        key: _showcaseFilters,
                        title: 'Filter Activity',
                        description:
                            'Filter your donation history by Today, This Week, This Month, or view All records.',
                        titleTextStyle: _tooltipTitleStyle,
                        descTextStyle: _tooltipDescStyle,
                        tooltipBorderRadius: _tooltipRadius,
                        tooltipPadding: _tooltipPadding,
                        targetBorderRadius: BorderRadius.circular(20),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: DateFilter.values.map((filter) {
                              final isSelected = _selectedFilter == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(_getChipLabel(filter)),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() => _selectedFilter = filter);
                                  },
                                  selectedColor: AppColors.primary.withAlpha(
                                    40,
                                  ),
                                  checkmarkColor: AppColors.primary,
                                  backgroundColor: isDark
                                      ? AppColors.surfaceDark
                                      : AppColors.surfaceLight,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Activity List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getFilterLabel(),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${filteredDeliveries.length} records',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (state is DeliveryLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (filteredDeliveries.isEmpty)
                        const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No records yet',
                          description:
                              'Tap above to record a donation or book sale.',
                          compact: true,
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredDeliveries.length,
                          itemBuilder: (context, index) {
                            final delivery = filteredDeliveries[index];
                            return StaggeredFadeIn(
                              index: index,
                              child: _ActivityCard(
                                delivery: delivery,
                                isDark: isDark,
                                onTap: () =>
                                    _showDetailSheet(context, delivery),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getChipLabel(DateFilter filter) {
    switch (filter) {
      case DateFilter.today:
        return 'Today';
      case DateFilter.thisWeek:
        return 'This Week';
      case DateFilter.thisMonth:
        return 'This Month';
      case DateFilter.all:
        return 'All';
    }
  }

  void _showRecordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<DeliveryBloc>(),
        child: const _RecordDonationSheet(),
      ),
    );
  }

  void _showBookSaleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<DeliveryBloc>(),
        child: const _RecordBookSaleSheet(),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, DeliveryModel delivery) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _DeliveryDetailSheet(delivery: delivery, isDark: isDark),
    );
  }
}

class _DeliveryDetailSheet extends StatelessWidget {
  final DeliveryModel delivery;
  final bool isDark;

  const _DeliveryDetailSheet({required this.delivery, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (delivery.isBookSale
                            ? AppColors.primary
                            : AppColors.success)
                        .withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    delivery.isBookSale
                        ? Icons.menu_book_rounded
                        : Icons.volunteer_activism,
                    color: delivery.isBookSale
                        ? AppColors.primary
                        : AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery.recipientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        delivery.isBookSale ? 'Book Sale' : 'Donation',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${(delivery.donationAmount ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow(label: 'Address', value: delivery.address),
            if (delivery.isBookSale && delivery.bookTitle != null)
              _DetailRow(label: 'Book', value: delivery.bookTitle!),
            if (delivery.isBookSale && delivery.bookQuantity != null)
              _DetailRow(label: 'Quantity', value: '${delivery.bookQuantity}'),
            if (delivery.isBookSale && delivery.bookLanguage != null)
              _DetailRow(label: 'Language', value: delivery.bookLanguage!),
            if (delivery.recipientPhone != null)
              _DetailRow(label: 'Phone', value: delivery.recipientPhone!),
            if (delivery.paymentMethod != null)
              _DetailRow(
                label: 'Payment',
                value: delivery.paymentMethod!.toUpperCase(),
              ),
            if (delivery.receiptNumber != null)
              _DetailRow(label: 'Receipt #', value: delivery.receiptNumber!),
            if (delivery.createdAt != null)
              _DetailRow(
                label: 'Time',
                value: DateFormat(
                  'MMM d, yyyy h:mm a',
                ).format(delivery.createdAt!),
              ),
            if (delivery.latitude != null && delivery.longitude != null)
              _DetailRow(
                label: 'Location',
                value:
                    '${delivery.latitude!.toStringAsFixed(5)}, ${delivery.longitude!.toStringAsFixed(5)}',
              ),
            const SizedBox(height: 16),
            // View Receipt Button
            if (delivery.receiptNumber != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showReceipt(context, delivery),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('View Digital Receipt'),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReceipt(BuildContext context, DeliveryModel delivery) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _ReceiptDialog(delivery: delivery),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final int donationsCount;
  final double donationsAmount;
  final int bookSalesCount;
  final double bookSalesAmount;
  final bool isDark;

  const _TodaySummaryCard({
    required this.donationsCount,
    required this.donationsAmount,
    required this.bookSalesCount,
    required this.bookSalesAmount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.success, AppColors.success.withBlue(150)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Total",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${donationsAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$donationsCount donations',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${bookSalesAmount.toStringAsFixed(2)} from $bookSalesCount book sales',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final DeliveryModel delivery;
  final bool isDark;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.delivery,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBookSale = delivery.isBookSale;
    final color = isBookSale ? AppColors.primary : AppColors.success;
    final time = delivery.createdAt ?? delivery.completedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isBookSale
                      ? Icons.menu_book_rounded
                      : Icons.volunteer_activism,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.recipientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (delivery.receiptNumber != null) ...[
                          Icon(Icons.receipt, size: 12, color: color),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            isBookSale && (delivery.bookTitle?.isNotEmpty ?? false)
                                ? delivery.bookTitle!
                                : delivery.address,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${(delivery.donationAmount ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  if (time != null)
                    Text(
                      DateFormat('h:mm a').format(time),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet for recording donations with payment processing
class _RecordDonationSheet extends StatefulWidget {
  const _RecordDonationSheet();

  @override
  State<_RecordDonationSheet> createState() => _RecordDonationSheetState();
}

class _RecordDonationSheetState extends State<_RecordDonationSheet> {
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMethod = 'cash';
  bool _isSubmitting = false;
  bool _isProcessingPayment = false;
  bool _isGettingLocation = false;
  double? _latitude;
  double? _longitude;
  String? _teamId;
  String? _workerId;
  String? _territoryId;
  String? _territoryName;

  static const _stepLabels = ['Donor Info', 'Amount & Method', 'Review'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getCurrentLocation();
  }

  Future<void> _loadUserData() async {
    try {
      final storage = await LocalStorage.getInstance();
      final userData = storage.getUserData();
      setState(() {
        _teamId =
            userData?['team_id']?.toString() ?? userData?['teamId']?.toString();
        _workerId =
            userData?['id']?.toString() ?? userData?['worker_id']?.toString();
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isGettingLocation = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isGettingLocation = false;
      });
      await _findTerritory();
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _findTerritory() async {
    if (_latitude == null || _longitude == null || _workerId == null) return;
    try {
      final repository = TerritoryRepository();
      final result = await repository.getMyAssignments(workerId: _workerId);
      if (result is ApiSuccess) {
        final assignments = (result as ApiSuccess).data;
        for (final assignment in assignments) {
          if (assignment.geometry == null) continue;
          if (_isPointInTerritory(
            _latitude!,
            _longitude!,
            assignment.geometry!,
          )) {
            setState(() {
              _territoryId = assignment.territoryId;
              _territoryName = assignment.entityName;
            });
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding territory: $e');
    }
  }

  bool _isPointInTerritory(
    double lat,
    double lng,
    Map<String, dynamic> geometry,
  ) {
    final type = geometry['type'] as String?;
    final coordinates = geometry['coordinates'];
    if (coordinates == null) return false;
    if (type == 'Polygon') {
      final ring = (coordinates[0] as List).map<List<double>>((coord) {
        final c = coord as List;
        return [c[0].toDouble(), c[1].toDouble()];
      }).toList();
      return _isPointInPolygon(lat, lng, ring);
    } else if (type == 'MultiPolygon') {
      for (var poly in coordinates) {
        final ring = (poly[0] as List).map<List<double>>((coord) {
          final c = coord as List;
          return [c[0].toDouble(), c[1].toDouble()];
        }).toList();
        if (_isPointInPolygon(lat, lng, ring)) return true;
      }
    }
    return false;
  }

  bool _isPointInPolygon(double lat, double lng, List<List<double>> polygon) {
    bool inside = false;
    final n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = polygon[i][0], yi = polygon[i][1];
      final xj = polygon[j][0], yj = polygon[j][1];
      if (((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _generateReceiptNumber() {
    final now = DateTime.now();
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'RCP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  Future<bool> _processPayment(double amount) async {
    // Cash payment - immediate completion
    if (_paymentMethod == 'cash') {
      setState(() => _isProcessingPayment = true);
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _isProcessingPayment = false);
      return true;
    }

    // Online payment - send payment link via SMS
    if (_paymentMethod == 'online') {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number is required for online payment'),
            backgroundColor: AppColors.error,
          ),
        );
        return false;
      }

      // Show waiting dialog and send payment link
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _PaymentLinkDialog(
          amount: amount,
          phoneNumber: phone,
          recipientName: _nameController.text.trim(),
        ),
      );
      return result ?? false;
    }

    return true;
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      return _step1Key.currentState?.validate() ?? false;
    }
    if (_currentStep == 1) {
      return _step2Key.currentState?.validate() ?? false;
    }
    return true;
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 2) {
      _goToStep(_currentStep + 1);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _submit() async {
    if (_teamId == null || _teamId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be assigned to a team'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;

    // Process payment first
    final paymentSuccess = await _processPayment(amount);
    if (!paymentSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment failed. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final receiptNumber = _generateReceiptNumber();

      final request = CreateDeliveryRequest(
        teamId: _teamId!,
        recipientName: _nameController.text.trim(),
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : 'Location recorded',
        recipientPhone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        latitude: _latitude,
        longitude: _longitude,
        deliveryType: 'donation',
        donationAmount: amount,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        territoryId: _territoryId,
        territoryName: _territoryName,
        items: [],
      );

      context.read<DeliveryBloc>().add(DeliveryCreate(request: request));
      Navigator.pop(context);

      // Show receipt dialog
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        _showReceiptConfirmation(context, receiptNumber, amount);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showReceiptConfirmation(
    BuildContext context,
    String receiptNumber,
    double amount,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: AppColors.success,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Receipt: $receiptNumber',
              style: const TextStyle(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header + Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.volunteer_activism,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Record Donation',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Step ${_currentStep + 1} of 3 — ${_stepLabels[_currentStep]}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StepProgressBar(
                  currentStep: _currentStep,
                  totalSteps: 3,
                  activeColor: AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Location status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    (_latitude != null ? AppColors.success : AppColors.warning)
                        .withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isGettingLocation)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _latitude != null
                          ? Icons.location_on
                          : Icons.location_off,
                      size: 16,
                      color: _latitude != null
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _isGettingLocation
                        ? 'Getting location...'
                        : _latitude != null
                        ? 'Location captured${_territoryName != null ? ' ($_territoryName)' : ''}'
                        : 'Location not available',
                    style: TextStyle(
                      fontSize: 12,
                      color: _latitude != null
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Step pages
          Flexible(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(isDark),
                _buildStep2(isDark),
                _buildStep3(isDark),
              ],
            ),
          ),

          // Navigation buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: _currentStep == 0 ? 1 : 1,
                  child: _currentStep < 2
                      ? FilledButton.icon(
                          onPressed: _nextStep,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('Next'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _isSubmitting || _isProcessingPayment
                              ? null
                              : _submit,
                          icon: _isSubmitting || _isProcessingPayment
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: Text(
                            _isSubmitting || _isProcessingPayment
                                ? 'Processing...'
                                : 'Confirm & Submit',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Donor Info
  Widget _buildStep1(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: _nameController,
              label: 'Donor Name',
              prefixIcon: Icons.person_outline,
              realtimeValidation: true,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Name is required'
                  : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _addressController,
              label: 'Address (optional)',
              prefixIcon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phoneController,
              label: 'Phone (optional)',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  // Step 2: Amount & Payment Method
  Widget _buildStep2(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: _amountController,
              label: 'Donation Amount (\$)',
              prefixIcon: Icons.attach_money,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              realtimeValidation: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Amount is required';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Method',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _PaymentChip(
                  label: 'Cash',
                  icon: Icons.money,
                  isSelected: _paymentMethod == 'cash',
                  onTap: () => setState(() => _paymentMethod = 'cash'),
                ),
                const SizedBox(width: 12),
                _PaymentChip(
                  label: 'Send Payment Link',
                  icon: Icons.send,
                  isSelected: _paymentMethod == 'online',
                  onTap: () => setState(() => _paymentMethod = 'online'),
                ),
              ],
            ),
            if (_paymentMethod == 'online') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A payment link will be sent to the phone number. The donor will complete payment on their own device.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            CustomTextField(
              controller: _notesController,
              label: 'Notes (optional)',
              prefixIcon: Icons.notes,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Review & Confirm
  Widget _buildStep3(bool isDark) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Donation',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _ReviewRow(
              label: 'Donor',
              value: _nameController.text.trim().isNotEmpty
                  ? _nameController.text.trim()
                  : '—',
              color: secondaryColor,
            ),
            const Divider(height: 24),
            _ReviewRow(
              label: 'Amount',
              value: amount > 0 ? '\$${amount.toStringAsFixed(2)}' : '—',
              valueStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.success,
              ),
              color: secondaryColor,
            ),
            const Divider(height: 24),
            _ReviewRow(
              label: 'Payment',
              value: _paymentMethod == 'cash' ? 'Cash' : 'Payment Link',
              color: secondaryColor,
            ),
            if (_addressController.text.trim().isNotEmpty) ...[
              const Divider(height: 24),
              _ReviewRow(
                label: 'Address',
                value: _addressController.text.trim(),
                color: secondaryColor,
              ),
            ],
            if (_phoneController.text.trim().isNotEmpty) ...[
              const Divider(height: 24),
              _ReviewRow(
                label: 'Phone',
                value: _phoneController.text.trim(),
                color: secondaryColor,
              ),
            ],
            if (_notesController.text.trim().isNotEmpty) ...[
              const Divider(height: 24),
              _ReviewRow(
                label: 'Notes',
                value: _notesController.text.trim(),
                color: secondaryColor,
              ),
            ],
            if (_territoryName != null) ...[
              const Divider(height: 24),
              _ReviewRow(
                label: 'Territory',
                value: _territoryName!,
                color: secondaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final TextStyle? valueStyle;

  const _ReviewRow({
    required this.label,
    required this.value,
    required this.color,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordBookSaleSheet extends StatefulWidget {
  const _RecordBookSaleSheet();

  @override
  State<_RecordBookSaleSheet> createState() => _RecordBookSaleSheetState();
}

class _RecordBookSaleSheetState extends State<_RecordBookSaleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  int _selectedBookIndex = 0;
  String _paymentMethod = 'cash';
  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  double? _latitude;
  double? _longitude;
  String? _teamId;
  String? _workerId;
  String? _territoryId;
  String? _territoryName;

  _BookOption get _selectedBook => _bookCatalog[_selectedBookIndex];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final storage = await LocalStorage.getInstance();
      final userData = storage.getUserData();
      setState(() {
        _teamId =
            userData?['team_id']?.toString() ?? userData?['teamId']?.toString();
        _workerId =
            userData?['id']?.toString() ?? userData?['worker_id']?.toString();
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isGettingLocation = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isGettingLocation = false;
      });
      await _findTerritory();
    } catch (_) {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _findTerritory() async {
    if (_latitude == null || _longitude == null || _workerId == null) return;
    try {
      final repository = TerritoryRepository();
      final result = await repository.getMyAssignments(workerId: _workerId);
      if (result is ApiSuccess) {
        final assignments = (result as ApiSuccess).data;
        for (final assignment in assignments) {
          if (assignment.geometry == null) continue;
          if (_isPointInTerritory(
            _latitude!,
            _longitude!,
            assignment.geometry!,
          )) {
            setState(() {
              _territoryId = assignment.territoryId;
              _territoryName = assignment.entityName;
            });
            break;
          }
        }
      }
    } catch (_) {}
  }

  bool _isPointInTerritory(
    double lat,
    double lng,
    Map<String, dynamic> geometry,
  ) {
    final type = geometry['type'] as String?;
    final coordinates = geometry['coordinates'];
    if (coordinates == null) return false;
    if (type == 'Polygon') {
      final ring = (coordinates[0] as List).map<List<double>>((coord) {
        final c = coord as List;
        return [c[0].toDouble(), c[1].toDouble()];
      }).toList();
      return _isPointInPolygon(lat, lng, ring);
    } else if (type == 'MultiPolygon') {
      for (var poly in coordinates) {
        final ring = (poly[0] as List).map<List<double>>((coord) {
          final c = coord as List;
          return [c[0].toDouble(), c[1].toDouble()];
        }).toList();
        if (_isPointInPolygon(lat, lng, ring)) return true;
      }
    }
    return false;
  }

  bool _isPointInPolygon(double lat, double lng, List<List<double>> polygon) {
    bool inside = false;
    final n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = polygon[i][0], yi = polygon[i][1];
      final xj = polygon[j][0], yj = polygon[j][1];
      if (((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_teamId == null || _teamId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be assigned to a team'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is required. Please enable GPS and retry.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    final totalAmount = _selectedBook.unitPrice * quantity;
    final languageLabel = _selectedBook.language == 'spanish'
        ? 'Spanish'
        : 'English';

    final request = CreateDeliveryRequest(
      teamId: _teamId!,
      recipientName: _nameController.text.trim(),
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : 'Location recorded',
      recipientPhone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      latitude: _latitude,
      longitude: _longitude,
      deliveryType: 'book_sale',
      donationAmount: totalAmount,
      paymentMethod: _paymentMethod,
      bookCode: _selectedBook.code,
      bookTitle: _selectedBook.title,
      bookLanguage: _selectedBook.language,
      bookQuantity: quantity,
      bookUnitPrice: _selectedBook.unitPrice,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      territoryId: _territoryId,
      territoryName: _territoryName,
      // Keep one explicit item for backward compatibility with older backend validation.
      items: [
        DeliveryItem(
          name: _selectedBook.title,
          quantity: quantity,
          description: 'book_code=${_selectedBook.code};language=$languageLabel',
        ),
      ],
    );

    context.read<DeliveryBloc>().add(DeliveryCreate(request: request));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    final totalAmount = _selectedBook.unitPrice * quantity;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Record Book Sale',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Text(
                    'Book',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _bookCatalog.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final book = _bookCatalog[index];
                        final isSelected = _selectedBookIndex == index;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedBookIndex = index),
                          child: Container(
                            width: 180,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                          ? AppColors.borderDark
                                          : AppColors.borderLight),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Image.asset(
                                    book.assetPath,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => Container(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '\$${book.unitPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _nameController,
                    label: 'Buyer Name *',
                    hint: 'Enter buyer name',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Buyer name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'Address (optional)',
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _phoneController,
                    label: 'Phone',
                    hint: 'Phone (optional)',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _quantityController,
                    label: 'Quantity *',
                    hint: 'Enter quantity',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final q = int.tryParse(value ?? '');
                      if (q == null || q <= 0) return 'Enter valid quantity';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _PaymentChip(
                        label: 'Cash',
                        icon: Icons.payments,
                        isSelected: _paymentMethod == 'cash',
                        onTap: () => setState(() => _paymentMethod = 'cash'),
                      ),
                      const SizedBox(width: 8),
                      _PaymentChip(
                        label: 'Online',
                        icon: Icons.link,
                        isSelected: _paymentMethod == 'online',
                        onTap: () => setState(() => _paymentMethod = 'online'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _notesController,
                    label: 'Notes',
                    hint: 'Optional notes',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selected: ${_selectedBook.title}'),
                        const SizedBox(height: 4),
                        Text(
                          'Total: \$${totalAmount.toStringAsFixed(2)} (${_selectedBook.unitPrice.toStringAsFixed(2)} x $quantity)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (_isGettingLocation)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('Detecting location...'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSubmitting
                      ? 'Saving...'
                      : 'Record Sale (\$${totalAmount.toStringAsFixed(2)})',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Payment Link Dialog - Sends SMS and waits for payment
class _PaymentLinkDialog extends StatefulWidget {
  final double amount;
  final String phoneNumber;
  final String recipientName;

  const _PaymentLinkDialog({
    required this.amount,
    required this.phoneNumber,
    required this.recipientName,
  });

  @override
  State<_PaymentLinkDialog> createState() => _PaymentLinkDialogState();
}

class _PaymentLinkDialogState extends State<_PaymentLinkDialog> {
  String _status = 'sending'; // sending, waiting, completed, failed
  String? _errorMessage;
  String? _paymentSessionId;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int maxPolls = 60; // 5 minutes (5 second intervals)

  @override
  void initState() {
    super.initState();
    _sendPaymentLink();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendPaymentLink() async {
    try {
      final apiClient = ApiClient();

      // Call backend to create payment link and send SMS
      final response = await apiClient.dio.post(
        ApiConstants.sendPaymentLink,
        data: {
          'recipient_phone': widget.phoneNumber,
          'recipient_name': widget.recipientName,
          'amount': (widget.amount * 100).toInt(), // Convert to cents
          'currency': 'usd',
          'description': 'Donation',
        },
      );

      if (!mounted) return;

      final data = response.data;
      _paymentSessionId = data['session_id'];

      final smsSent = data['sms_sent'] ?? false;
      if (!smsSent && data['sms_error'] != null) {
        debugPrint('SMS Error: ${data['sms_error']}');
      }

      setState(() => _status = 'waiting');

      // Start polling for payment status
      _startPolling();
    } on DioException catch (e) {
      if (mounted) {
        String message = 'Failed to send payment link';
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          message = data['error'].toString();
        } else if (data is String && data.isNotEmpty) {
          message = data;
        }
        setState(() {
          _status = 'failed';
          _errorMessage = message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'failed';
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_pollCount >= maxPolls || _status != 'waiting' || !mounted) {
        timer.cancel();
        if (_status == 'waiting' && mounted) {
          setState(() {
            _status = 'failed';
            _errorMessage = 'Payment timeout. Please try again.';
          });
        }
        return;
      }

      _pollCount++;
      await _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_paymentSessionId == null) return;

    try {
      final apiClient = ApiClient();

      final response = await apiClient.dio.get(
        '${ApiConstants.paymentStatus}/$_paymentSessionId',
      );

      if (!mounted) return;

      final data = response.data;
      final status = data['status'] as String?;

      if (status == 'completed') {
        _pollTimer?.cancel();
        setState(() => _status = 'completed');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context, true);
      } else if (status == 'failed' || status == 'expired') {
        _pollTimer?.cancel();
        setState(() {
          _status = 'failed';
          _errorMessage = status == 'expired'
              ? 'Payment link expired. Please try again.'
              : 'Payment failed. Please try again.';
        });
      }
      // If still pending, continue polling
    } catch (e) {
      debugPrint('Error checking payment status: $e');
      // Continue polling on error
    }
  }

  String _formatPhone(String phone) {
    if (phone.length >= 4) {
      return '***-***-${phone.substring(phone.length - 4)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon based on status
          if (_status == 'sending' || _status == 'waiting')
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: _status == 'sending'
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Icon(
                      Icons.hourglass_top,
                      color: AppColors.primary,
                      size: 32,
                    ),
            )
          else if (_status == 'completed')
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: AppColors.success,
                size: 32,
              ),
            )
          else
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 32,
              ),
            ),

          const SizedBox(height: 20),

          // Title
          Text(
            _status == 'sending'
                ? 'Sending Payment Link...'
                : _status == 'waiting'
                ? 'Waiting for Payment'
                : _status == 'completed'
                ? 'Payment Received!'
                : 'Payment Failed',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Amount
          Text(
            '\$${widget.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _status == 'completed'
                  ? AppColors.success
                  : AppColors.primary,
            ),
          ),

          const SizedBox(height: 8),

          // Phone number
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.phone,
                size: 16,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                _formatPhone(widget.phoneNumber),
                style: const TextStyle(color: AppColors.textSecondaryLight),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Status message
          if (_status == 'sending')
            const Text(
              'Sending payment link via SMS...',
              style: TextStyle(color: AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            )
          else if (_status == 'waiting')
            Column(
              children: [
                Text(
                  'Payment link sent to ${widget.recipientName}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Waiting for them to complete payment...',
                  style: TextStyle(color: AppColors.textSecondaryLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _pollCount / maxPolls,
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ],
            )
          else if (_status == 'failed')
            Text(
              _errorMessage ?? 'Payment could not be processed',
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 20),

          // Action buttons
          if (_status == 'waiting')
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            )
          else if (_status == 'failed')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _status = 'sending';
                      _pollCount = 0;
                      _errorMessage = null;
                    });
                    _sendPaymentLink();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Receipt dialog showing digital receipt
class _ReceiptDialog extends StatelessWidget {
  final DeliveryModel delivery;

  const _ReceiptDialog({required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RECEIPT',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Receipt content
            const SizedBox(height: 8),
            Text(
              'Rally Point',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              delivery.isBookSale ? 'Book Sale Receipt' : 'Donation Receipt',
              style: const TextStyle(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 16),

            // Receipt number
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                delivery.receiptNumber ?? 'N/A',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Details
            _ReceiptRow(
              label: 'Date',
              value: DateFormat(
                'MMM d, yyyy h:mm a',
              ).format(delivery.createdAt ?? DateTime.now()),
            ),
            _ReceiptRow(
              label: delivery.isBookSale ? 'Buyer' : 'Donor',
              value: delivery.recipientName,
            ),
            if (delivery.isBookSale && delivery.bookTitle != null)
              _ReceiptRow(label: 'Book', value: delivery.bookTitle!),
            if (delivery.isBookSale && delivery.bookQuantity != null)
              _ReceiptRow(label: 'Qty', value: '${delivery.bookQuantity}'),
            _ReceiptRow(
              label: 'Payment Method',
              value: (delivery.paymentMethod ?? 'cash').toUpperCase(),
            ),
            if (delivery.territoryName != null)
              _ReceiptRow(label: 'Territory', value: delivery.territoryName!),
            const SizedBox(height: 16),
            const Divider(),

            // Amount
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${(delivery.donationAmount ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Footer
            const Text(
              'Thank you!',
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Share receipt
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Share feature coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondaryLight),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
