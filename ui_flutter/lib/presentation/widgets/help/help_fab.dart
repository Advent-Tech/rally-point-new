import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HelpFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isHelpMode;

  const HelpFab({super.key, this.onPressed, this.isHelpMode = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: isHelpMode
          ? (isDark
                ? AppColors.buttonPrimaryDark
                : AppColors.buttonPrimaryLight)
          : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
      child: Icon(
        isHelpMode ? Icons.close : Icons.help_outline,
        color: isHelpMode
            ? Colors.white
            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
      ),
    );
  }
}
