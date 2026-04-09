import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class TodaysPlanCard extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final VoidCallback? onTaskTap;

  const TodaysPlanCard({super.key, this.tasks = const [], this.onTaskTap});

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
              Icon(
                Icons.calendar_today,
                color: isDark
                    ? AppColors.buttonPrimaryDark
                    : AppColors.buttonPrimaryLight,
              ),
              const SizedBox(width: 8),
              Text(
                "Today's Plan",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No tasks scheduled for today',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            )
          else
            ...tasks.map((task) => _TaskItem(task: task, isDark: isDark)),
        ],
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isDark;

  const _TaskItem({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final title = task['title']?.toString() ?? 'Task';
    final time = task['time']?.toString() ?? '';
    final isCompleted = task['is_completed'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.success : AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
          ),
          if (isCompleted)
            Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ],
      ),
    );
  }
}
