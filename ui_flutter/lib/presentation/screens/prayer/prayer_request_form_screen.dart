import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/prayer_request_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/prayer_request/prayer_request_bloc.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/animations/success_check.dart';

class PrayerRequestFormScreen extends StatefulWidget {
  const PrayerRequestFormScreen({super.key});

  @override
  State<PrayerRequestFormScreen> createState() =>
      _PrayerRequestFormScreenState();
}

class _PrayerRequestFormScreenState extends State<PrayerRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _requesterNameController = TextEditingController();
  final _requesterPhoneController = TextEditingController();
  final _requesterEmailController = TextEditingController();
  final _requesterAddressController = TextEditingController();
  final _prayerSubjectController = TextEditingController();
  final _prayerDetailsController = TextEditingController();
  final _preferredVisitDateController = TextEditingController();
  final _preferredVisitTimeController = TextEditingController();
  final _notesController = TextEditingController();

  // State
  String _selectedRequestType = PrayerRequestType.churchPrayer;
  String _selectedCategory = PrayerCategory.general;
  String _selectedUrgency = PrayerUrgency.normal;
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _requesterNameController.dispose();
    _requesterPhoneController.dispose();
    _requesterEmailController.dispose();
    _requesterAddressController.dispose();
    _prayerSubjectController.dispose();
    _prayerDetailsController.dispose();
    _preferredVisitDateController.dispose();
    _preferredVisitTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission denied', isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permission permanently denied', isError: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('Could not get location: $e');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    context.read<PrayerRequestBloc>().add(
      PrayerRequestCreate(
        requesterName: _requesterNameController.text.trim(),
        requesterPhone: _requesterPhoneController.text.trim().isNotEmpty
            ? _requesterPhoneController.text.trim()
            : null,
        requesterEmail: _requesterEmailController.text.trim().isNotEmpty
            ? _requesterEmailController.text.trim()
            : null,
        requesterAddress: _requesterAddressController.text.trim().isNotEmpty
            ? _requesterAddressController.text.trim()
            : null,
        latitude: _latitude,
        longitude: _longitude,
        prayerSubject: _prayerSubjectController.text.trim(),
        prayerDetails: _prayerDetailsController.text.trim(),
        prayerCategory: _selectedCategory,
        requestType: _selectedRequestType,
        preferredVisitDate:
            _selectedRequestType == PrayerRequestType.homeVisit &&
                _preferredVisitDateController.text.trim().isNotEmpty
            ? _preferredVisitDateController.text.trim()
            : null,
        preferredVisitTime:
            _selectedRequestType == PrayerRequestType.homeVisit &&
                _preferredVisitTimeController.text.trim().isNotEmpty
            ? _preferredVisitTimeController.text.trim()
            : null,
        urgency: _selectedUrgency,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      _preferredVisitDateController.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null && mounted) {
      _preferredVisitTimeController.text = time.format(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<PrayerRequestBloc, PrayerRequestState>(
      listener: (context, state) {
        if (state is PrayerRequestSubmitSuccess) {
          SuccessOverlay.show(
            context,
            message: 'Prayer request submitted!',
          ).then((_) {
            if (context.mounted) {
              final authState = context.read<AuthBloc>().state;
              if (authState is AuthAuthenticated) {
                final isLeader =
                    authState.user.role == 'team_leader' ||
                    authState.user.role == 'admin';
                context.go(
                  isLeader ? '/leader/prayer-requests' : '/prayer-requests',
                );
              } else {
                context.go('/prayer-requests');
              }
            }
          });
        } else if (state is PrayerRequestError) {
          setState(() => _isSubmitting = false);
          _showSnackBar(state.message, isError: true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Prayer Request'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _showExitConfirmation(context),
          ),
          actions: [
            if (_latitude != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'GPS',
                      style: TextStyle(color: AppColors.success, fontSize: 12),
                    ),
                  ],
                ),
              )
            else if (_isGettingLocation)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Request Type Selection
              _buildSectionHeader('Request Type', isRequired: true),
              const SizedBox(height: 8),
              _buildRequestTypeSelector(isDark),
              const SizedBox(height: 24),

              // Requester Information
              _buildSectionHeader('Requester Information', isRequired: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _requesterNameController,
                label: 'Name',
                icon: Icons.person_outline,
                isRequired: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _requesterPhoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _requesterEmailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _requesterAddressController,
                label: 'Address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Prayer Details
              _buildSectionHeader('Prayer Details', isRequired: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _prayerSubjectController,
                label: 'Prayer Subject',
                icon: Icons.subject,
                isRequired: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _prayerDetailsController,
                label: 'Prayer Details',
                icon: Icons.description_outlined,
                maxLines: 4,
                isRequired: true,
              ),
              const SizedBox(height: 12),
              _buildDropdownField(
                label: 'Prayer Category',
                value: _selectedCategory,
                items: PrayerCategory.all
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(PrayerCategory.getDisplayName(c)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategory = value!),
                icon: Icons.category_outlined,
              ),
              const SizedBox(height: 12),
              _buildDropdownField(
                label: 'Urgency',
                value: _selectedUrgency,
                items: PrayerUrgency.all
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Text(PrayerUrgency.getDisplayName(u)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedUrgency = value!),
                icon: Icons.priority_high,
              ),
              const SizedBox(height: 24),

              // Home Visit Details (only shown for home visit type)
              if (_selectedRequestType == PrayerRequestType.homeVisit) ...[
                _buildSectionHeader('Home Visit Preferences'),
                const SizedBox(height: 8),
                _buildDateField(
                  controller: _preferredVisitDateController,
                  label: 'Preferred Visit Date',
                  onTap: _selectDate,
                ),
                const SizedBox(height: 12),
                _buildTimeField(
                  controller: _preferredVisitTimeController,
                  label: 'Preferred Visit Time',
                  onTap: _selectTime,
                ),
                const SizedBox(height: 24),
              ],

              // Additional Notes
              _buildSectionHeader('Additional Notes'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _notesController,
                label: 'Notes (optional)',
                icon: Icons.note_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Submit Button
              CustomButton(
                text: 'Submit Prayer Request',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submitForm,
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (isRequired)
          const Text(' *', style: TextStyle(color: AppColors.error)),
      ],
    );
  }

  Widget _buildRequestTypeSelector(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildRequestTypeCard(
            type: PrayerRequestType.churchPrayer,
            title: 'Church Prayer',
            subtitle: 'Pray at church',
            icon: Icons.church_outlined,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRequestTypeCard(
            type: PrayerRequestType.homeVisit,
            title: 'Home Visit',
            subtitle: 'Preacher visits',
            icon: Icons.home_outlined,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestTypeCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedRequestType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedRequestType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(20)
              : isDark
              ? AppColors.cardDark
              : AppColors.cardLight,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      autovalidateMode: isRequired ? AutovalidateMode.onUserInteraction : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        suffixIcon: const Icon(Icons.arrow_drop_down),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.access_time_outlined),
        suffixIcon: const Icon(Icons.arrow_drop_down),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate back to home based on user role
              final authState = context.read<AuthBloc>().state;
              if (authState is AuthAuthenticated) {
                final isLeader =
                    authState.user.role == 'team_leader' ||
                    authState.user.role == 'admin';
                context.go(isLeader ? '/leader/dashboard' : '/home');
              } else {
                context.go('/home');
              }
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
