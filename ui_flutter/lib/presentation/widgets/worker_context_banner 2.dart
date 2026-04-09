import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class WorkerContextBanner extends StatelessWidget {
  final String workerName;
  final VoidCallback? onTap;

  const WorkerContextBanner({super.key, required this.workerName, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  (isDark
                          ? AppColors.buttonPrimaryDark
                          : AppColors.buttonPrimaryLight)
                      .withOpacity(0.1),
              child: Text(
                workerName.isNotEmpty ? workerName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isDark
                      ? AppColors.buttonPrimaryDark
                      : AppColors.buttonPrimaryLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Viewing:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    workerName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
          ],
        ),
      ),
    );
  }
}
