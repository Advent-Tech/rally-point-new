import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'help_content.dart';

class HelpOverlay extends StatefulWidget {
  final List<HelpContent> contents;
  final VoidCallback? onComplete;

  const HelpOverlay({super.key, required this.contents, this.onComplete});

  static void show(BuildContext context, List<HelpContent> contents) {
    showDialog(
      context: context,
      builder: (context) => HelpOverlay(contents: contents),
    );
  }

  @override
  State<HelpOverlay> createState() => _HelpOverlayState();
}

class _HelpOverlayState extends State<HelpOverlay> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = widget.contents[_currentIndex];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              content.content,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.contents.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _currentIndex ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _currentIndex
                        ? (isDark
                              ? AppColors.buttonPrimaryDark
                              : AppColors.buttonPrimaryLight)
                        : AppColors.textSecondaryLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentIndex > 0)
                  TextButton(
                    onPressed: () => setState(() => _currentIndex--),
                    child: const Text('Previous'),
                  )
                else
                  const SizedBox(),
                ElevatedButton(
                  onPressed: () {
                    if (_currentIndex < widget.contents.length - 1) {
                      setState(() => _currentIndex++);
                    } else {
                      Navigator.of(context).pop();
                      widget.onComplete?.call();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.buttonPrimaryDark
                        : AppColors.buttonPrimaryLight,
                  ),
                  child: Text(
                    _currentIndex < widget.contents.length - 1
                        ? 'Next'
                        : 'Done',
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
