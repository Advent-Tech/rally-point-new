import 'package:flutter/material.dart';

class StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? stepLabels;
  final Color activeColor;
  final Color inactiveColor;
  final Color completedColor;
  final double height;
  final double circleSize;

  const StepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels,
    this.activeColor = const Color(0xFF7C3AED),
    this.inactiveColor = const Color(0xFFE0E0E0),
    this.completedColor = const Color(0xFF22C55E),
    this.height = 4,
    this.circleSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveInactiveColor = isDark
        ? Colors.grey.shade700
        : inactiveColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            final isCompleted = index < currentStep;
            final isCurrent = index == currentStep;

            return Expanded(
              child: Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: isCompleted || isCurrent
                              ? (isCompleted ? completedColor : activeColor)
                              : effectiveInactiveColor,
                          borderRadius: BorderRadius.horizontal(
                            left: index == 1
                                ? Radius.circular(height / 2)
                                : Radius.zero,
                            right: index == totalSteps - 1
                                ? Radius.circular(height / 2)
                                : Radius.zero,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? completedColor
                          : isCurrent
                          ? activeColor
                          : effectiveInactiveColor,
                      shape: BoxShape.circle,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: activeColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        if (stepLabels != null && stepLabels!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: stepLabels!.asMap().entries.map((entry) {
              final isCompleted = entry.key < currentStep;
              final isCurrent = entry.key == currentStep;
              return Expanded(
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent || isCompleted
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isCompleted
                        ? completedColor
                        : isCurrent
                        ? activeColor
                        : Colors.grey,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class VerticalStepper extends StatelessWidget {
  final int currentStep;
  final List<VerticalStepperItem> steps;
  final double iconSize;
  final Color? activeColor;
  final Color? completedColor;

  const VerticalStepper({
    super.key,
    required this.currentStep,
    required this.steps,
    this.iconSize = 24,
    this.activeColor,
    this.completedColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveActiveColor = activeColor ?? const Color(0xFF7C3AED);
    final effectiveCompletedColor = completedColor ?? const Color(0xFF22C55E);
    final inactiveColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? effectiveCompletedColor
                          : isCurrent
                          ? effectiveActiveColor
                          : inactiveColor,
                      shape: BoxShape.circle,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: effectiveActiveColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : step.customIcon ??
                                Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isCurrent
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                    ),
                  ),
                  if (index < steps.length - 1)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: isCompleted
                              ? LinearGradient(
                                  colors: [
                                    effectiveCompletedColor,
                                    effectiveCompletedColor,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : null,
                          color: isCompleted ? null : inactiveColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: index < steps.length - 1 ? 24 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isCurrent || isCompleted
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.grey,
                        ),
                      ),
                      if (step.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          step.subtitle!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (step.content != null) ...[
                        const SizedBox(height: 8),
                        step.content!,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class VerticalStepperItem {
  final String title;
  final String? subtitle;
  final Widget? content;
  final Widget? customIcon;

  const VerticalStepperItem({
    required this.title,
    this.subtitle,
    this.content,
    this.customIcon,
  });
}
