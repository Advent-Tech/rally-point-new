import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('About'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppInfo(context, isDark),
            const SizedBox(height: 32),
            _buildSection(
              context,
              isDark,
              'About Light Point',
              'Light Point is a comprehensive field workforce management platform designed to streamline team coordination, '
                  'task tracking, and real-time location monitoring. Built for organizations that manage distributed teams '
                  'in the field, Light Point provides the tools needed to optimize operations and improve accountability.',
            ),
            _buildSection(
              context,
              isDark,
              'Key Features',
              '• Real-time GPS tracking and location monitoring\n'
                  '• Visit and delivery verification with photo evidence\n'
                  '• Team coordination and communication tools\n'
                  '• Performance analytics and reporting\n'
                  '• Territory management and compliance tracking\n'
                  '• Survey and data collection capabilities\n'
                  '• Offline support for areas with limited connectivity',
            ),
            _buildSection(
              context,
              isDark,
              'Platform',
              'Light Point is available on iOS and Android devices, with a web-based admin panel for team leaders and administrators.',
            ),
            _buildSection(
              context,
              isDark,
              'Support',
              'For support or inquiries, please contact:\n\n'
                  'Email: support@lightsquads.com\n'
                  'Website: https://lightsquads.com',
            ),
            const SizedBox(height: 32),
            _buildVersionInfo(context, isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfo(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.light_mode,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Light Point',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Field Workforce Management',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
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

  Widget _buildVersionInfo(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Version 1.0.1',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\u00a9 2026 Light Point. All rights reserved.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
