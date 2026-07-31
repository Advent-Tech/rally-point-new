import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isDark),
            const SizedBox(height: 24),
            _buildSection(
              context,
              isDark,
              '1. Information We Collect',
              'We collect information you provide directly, including:\n\n'
                  '• Account information (name, email address, phone number)\n'
                  '• Location data during active tracking sessions\n'
                  '• Activity logs including visits, deliveries, and task completions\n'
                  '• Profile photos and team assignments\n'
                  '• Communication data within the platform',
            ),
            _buildSection(
              context,
              isDark,
              '2. How We Use Your Information',
              'Your information is used to:\n\n'
                  '• Provide and maintain the Light Point service\n'
                  '• Track field activities and generate performance reports\n'
                  '• Enable real-time team coordination and location sharing\n'
                  '• Send important service notifications and updates\n'
                  '• Improve app functionality and user experience\n'
                  '• Ensure platform security and prevent unauthorized access',
            ),
            _buildSection(
              context,
              isDark,
              '3. Location Data',
              'Light Point collects location data to:\n\n'
                  '• Enable team leaders to monitor field operations\n'
                  '• Verify visit and delivery completions\n'
                  '• Generate accurate activity reports\n'
                  '• Provide territory compliance monitoring\n\n'
                  'Location tracking is only active during work sessions and can be paused at any time by the user.',
            ),
            _buildSection(
              context,
              isDark,
              '4. Data Sharing',
              'We do not sell your personal information. Data may be shared with:\n\n'
                  '• Team members within your organization as authorized by administrators\n'
                  '• Service providers who assist in operating the platform\n'
                  '• Law enforcement when required by legal obligation',
            ),
            _buildSection(
              context,
              isDark,
              '5. Data Security',
              'We implement industry-standard security measures including:\n\n'
                  '• End-to-end encryption for data transmission\n'
                  '• Secure cloud storage with access controls\n'
                  '• Regular security audits and vulnerability assessments\n'
                  '• Two-factor authentication support',
            ),
            _buildSection(
              context,
              isDark,
              '6. Data Retention',
              'Your data is retained for as long as your account is active. You may request data deletion by contacting your organization administrator. Upon account termination, personal data is removed within 30 days.',
            ),
            _buildSection(
              context,
              isDark,
              '7. Your Rights',
              'You have the right to:\n\n'
                  '• Access your personal data\n'
                  '• Correct inaccurate information\n'
                  '• Request deletion of your data\n'
                  '• Export your data in a portable format\n'
                  '• Opt out of non-essential data collection',
            ),
            _buildSection(
              context,
              isDark,
              '8. Changes to This Policy',
              'We may update this privacy policy from time to time. Users will be notified of significant changes through the application or via email.',
            ),
            _buildSection(
              context,
              isDark,
              '9. Contact Us',
              'For questions about this privacy policy or our data practices, please contact us at:\n\n'
                  'Email: privacy@lightsquads.com\n'
                  'Website: https://lightsquads.com',
            ),
            const SizedBox(height: 32),
            Text(
              'Last updated: August 2026',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Privacy Policy',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Light Point is committed to protecting your privacy and personal data.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    bool isDark,
    String title,
    String content,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
