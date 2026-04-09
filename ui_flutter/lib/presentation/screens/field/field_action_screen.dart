import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../blocs/work_session/work_session_bloc.dart';
import '../../blocs/delivery/delivery_bloc.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../../data/models/delivery_model.dart';

/// Unified Field Action Screen for quick on-spot tasks
/// Provides simplified forms for deliveries, donations, and surveys
class FieldActionScreen extends StatefulWidget {
  const FieldActionScreen({super.key});

  @override
  State<FieldActionScreen> createState() => _FieldActionScreenState();
}

class _FieldActionScreenState extends State<FieldActionScreen> {
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permission permanently denied';
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location: ${e.toString()}';
        _isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Actions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Location & Session Status
            _LocationStatusCard(
              position: _currentPosition,
              isLoading: _isLoadingLocation,
              error: _locationError,
              onRefresh: _getCurrentLocation,
            ),
            const SizedBox(height: 24),

            // Quick Actions Grid
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.add_location_alt,
                    label: 'Log Visit',
                    description: 'Record a household visit',
                    color: AppColors.primary,
                    onTap: () => context.go('/log-visit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.local_shipping,
                    label: 'Quick Delivery',
                    description: 'Complete delivery on-spot',
                    color: AppColors.accent,
                    onTap: () => _showQuickDeliverySheet(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.volunteer_activism,
                    label: 'Collect Donation',
                    description: 'Record donation instantly',
                    color: AppColors.success,
                    onTap: () => _showQuickDonationSheet(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.assignment,
                    label: 'Take Survey',
                    description: 'Fill survey at location',
                    color: AppColors.warning,
                    onTap: () => context.go('/survey'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Activity Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity (Today)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // View all activity
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RecentActivityList(isDark: isDark),
          ],
        ),
      ),
    );
  }

  void _showQuickDeliverySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<DeliveryBloc>(),
        child: _QuickDeliverySheet(currentPosition: _currentPosition),
      ),
    );
  }

  void _showQuickDonationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _QuickDonationSheet(currentPosition: _currentPosition),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  final Position? position;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _LocationStatusCard({
    required this.position,
    required this.isLoading,
    this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isLoading
                      ? AppColors.warning.withOpacity(0.2)
                      : error != null
                          ? AppColors.error.withOpacity(0.2)
                          : AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        error != null ? Icons.location_off : Icons.my_location,
                        color: error != null ? AppColors.error : AppColors.success,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading
                          ? 'Getting Location...'
                          : error != null
                              ? 'Location Unavailable'
                              : 'Location Ready',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (position != null)
                      Text(
                        '${position!.latitude.toStringAsFixed(5)}, ${position!.longitude.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      )
                    else if (error != null)
                      Text(
                        error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Session status
          BlocBuilder<WorkSessionBloc, WorkSessionState>(
            builder: (context, state) {
              final isActive = state is WorkSessionActive;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.play_circle_filled : Icons.pause_circle_filled,
                      color: isActive ? AppColors.success : AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isActive
                          ? 'Session Active - ${(state as WorkSessionActive).session.territoryName ?? "Unknown Territory"}'
                          : 'No Active Session',
                      style: TextStyle(
                        color: isActive ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final bool isDark;

  const _RecentActivityList({required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Placeholder - would load from BLoC
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 8),
            Text(
              'No activity today',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your visits, deliveries, and donations will appear here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick Delivery Sheet - Simplified form for on-spot delivery completion
class _QuickDeliverySheet extends StatefulWidget {
  final Position? currentPosition;

  const _QuickDeliverySheet({this.currentPosition});

  @override
  State<_QuickDeliverySheet> createState() => _QuickDeliverySheetState();
}

class _QuickDeliverySheetState extends State<_QuickDeliverySheet> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _notesController = TextEditingController();
  String _deliveryType = 'door_to_door';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
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
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Delivery',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Create and complete a delivery in one step',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),

            // Delivery Type
            Text(
              'Delivery Type',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TypeOption(
                    icon: Icons.door_front_door,
                    label: 'Door to Door',
                    isSelected: _deliveryType == 'door_to_door',
                    onTap: () => setState(() => _deliveryType = 'door_to_door'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeOption(
                    icon: Icons.person_pin_circle,
                    label: 'Person to Person',
                    isSelected: _deliveryType == 'person_to_person',
                    onTap: () => setState(() => _deliveryType = 'person_to_person'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            CustomTextField(
              controller: _recipientController,
              label: 'Recipient Name (Optional)',
              hint: 'Leave blank for door-to-door',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _notesController,
              label: 'Items/Notes',
              hint: 'What was delivered?',
              prefixIcon: Icons.inventory_2_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 8),

            // Location status
            if (widget.currentPosition != null)
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'GPS location will be recorded',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.warning, size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    'No GPS location available',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Complete Delivery',
                icon: Icons.check_circle,
                isLoading: _isSubmitting,
                onPressed: _submitQuickDelivery,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitQuickDelivery() {
    setState(() => _isSubmitting = true);

    // Create and immediately complete delivery
    // For now, just show success and close
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery completed successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }
}

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick Donation Sheet - Simplified form for on-spot donation collection
class _QuickDonationSheet extends StatefulWidget {
  final Position? currentPosition;

  const _QuickDonationSheet({this.currentPosition});

  @override
  State<_QuickDonationSheet> createState() => _QuickDonationSheetState();
}

class _QuickDonationSheetState extends State<_QuickDonationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _donorNameController = TextEditingController();
  String _paymentType = 'cash';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _donorNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
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
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.volunteer_activism, color: AppColors.success),
                ),
                const SizedBox(width: 12),
                Text(
                  'Collect Donation',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Record donation with GPS location',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),

            CustomTextField(
              controller: _amountController,
              label: 'Amount',
              hint: 'Enter donation amount',
              prefixIcon: Icons.attach_money,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _donorNameController,
              label: 'Donor Name (Optional)',
              hint: 'Enter donor name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 16),

            // Payment Type
            Text(
              'Payment Type',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TypeOption(
                    icon: Icons.money,
                    label: 'Cash',
                    isSelected: _paymentType == 'cash',
                    onTap: () => setState(() => _paymentType = 'cash'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeOption(
                    icon: Icons.receipt_long,
                    label: 'Check',
                    isSelected: _paymentType == 'check',
                    onTap: () => setState(() => _paymentType = 'check'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeOption(
                    icon: Icons.more_horiz,
                    label: 'Other',
                    isSelected: _paymentType == 'other',
                    onTap: () => setState(() => _paymentType = 'other'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location status
            if (widget.currentPosition != null)
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'GPS location will be recorded',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.warning, size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    'No GPS location available',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Record Donation',
                icon: Icons.check_circle,
                isLoading: _isSubmitting,
                onPressed: _submitDonation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitDonation() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSubmitting = true);

      // Record donation
      // For now, just show success and close
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Donation of \$${_amountController.text} recorded!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }
}
