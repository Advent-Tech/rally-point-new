import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/survey_model.dart';
import '../custom_text_field.dart';
import 'photo_capture_widget.dart';
import 'signature_pad_widget.dart';

/// Dynamic survey field that renders different input types based on question type
class DynamicSurveyField extends StatelessWidget {
  final SurveyQuestion question;
  final dynamic currentValue;
  final ValueChanged<dynamic> onValueChanged;
  final TextEditingController? textController;

  const DynamicSurveyField({
    super.key,
    required this.question,
    required this.currentValue,
    required this.onValueChanged,
    this.textController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (question.questionType) {
      case QuestionType.text:
        return _buildTextField(context);

      case QuestionType.textarea:
        return _buildTextareaField(context);

      case QuestionType.number:
        return _buildNumberField(context);

      case QuestionType.date:
        return _buildDatePicker(context, isDark);

      case QuestionType.select:
        return _buildDropdown(context, isDark);

      case QuestionType.radio:
      case QuestionType.multipleChoice:
        return _buildRadioOptions(context, isDark);

      case QuestionType.checkbox:
        return _buildCheckboxOptions(context, isDark);

      case QuestionType.photo:
        return _buildPhotoCapture(context);

      case QuestionType.signature:
        return _buildSignaturePad(context);

      case QuestionType.rating:
        return _buildRatingInput(context, isDark);

      case QuestionType.boolean:
      case QuestionType.yesNo:
        return _buildBooleanOptions(context, isDark);

      default:
        return _buildTextField(context);
    }
  }

  Widget _buildTextField(BuildContext context) {
    return CustomTextField(
      controller: textController,
      label: 'Your answer',
      hint: question.placeholder ?? 'Type your answer here',
      onChanged: (value) => onValueChanged(value),
      validator: question.isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'This question is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildTextareaField(BuildContext context) {
    return CustomTextField(
      controller: textController,
      label: 'Your answer',
      hint: question.placeholder ?? 'Type your detailed answer here',
      maxLines: 5,
      onChanged: (value) => onValueChanged(value),
      validator: question.isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'This question is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildNumberField(BuildContext context) {
    return CustomTextField(
      controller: textController,
      label: 'Your answer',
      hint: question.placeholder ?? 'Enter a number',
      keyboardType: TextInputType.number,
      onChanged: (value) => onValueChanged(value),
      validator: question.isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'This question is required';
              }
              if (double.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDatePicker(BuildContext context, bool isDark) {
    final selectedDate = currentValue as String?;

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          onValueChanged(date.toIso8601String().split('T')[0]);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              selectedDate ?? 'Select a date',
              style: TextStyle(
                color: selectedDate != null
                    ? (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight)
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(BuildContext context, bool isDark) {
    final options = question.options ?? [];
    final selectedValue = currentValue as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          hint: Text(
            question.placeholder ?? 'Select an option',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (value) => onValueChanged(value),
        ),
      ),
    );
  }

  Widget _buildRadioOptions(BuildContext context, bool isDark) {
    final options = question.options ?? [];
    final selectedValue = currentValue as String?;

    return Column(
      children: options.map((option) {
        final isSelected = selectedValue == option;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withAlpha(20)
                : isDark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: RadioListTile<String>(
            title: Text(
              option,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            value: option,
            groupValue: selectedValue,
            onChanged: (value) => onValueChanged(value),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCheckboxOptions(BuildContext context, bool isDark) {
    final options = question.options ?? [];
    final selectedValues = (currentValue as List<String>?) ?? [];

    return Column(
      children: options.map((option) {
        final isSelected = selectedValues.contains(option);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withAlpha(20)
                : isDark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: CheckboxListTile(
            title: Text(
              option,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            value: isSelected,
            onChanged: (checked) {
              final current = List<String>.from(selectedValues);
              if (checked == true) {
                current.add(option);
              } else {
                current.remove(option);
              }
              onValueChanged(current);
            },
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotoCapture(BuildContext context) {
    final photos = (currentValue as List<String>?) ?? [];

    return PhotoCaptureWidget(
      initialPhotos: photos,
      maxPhotos: 5,
      isRequired: question.isRequired,
      onPhotosChanged: (photos) => onValueChanged(photos),
    );
  }

  Widget _buildSignaturePad(BuildContext context) {
    return SignaturePadWidget(
      isRequired: question.isRequired,
      onSignatureChanged: (signature) => onValueChanged(signature),
    );
  }

  Widget _buildRatingInput(BuildContext context, bool isDark) {
    final selectedRating = currentValue as int? ?? 0;
    const maxRating = 5;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxRating, (index) {
            final rating = index + 1;
            final isSelected = rating <= selectedRating;
            return GestureDetector(
              onTap: () => onValueChanged(rating),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  isSelected ? Icons.star : Icons.star_border,
                  size: 48,
                  color: isSelected ? AppColors.warning : AppColors.borderLight,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Text(
          selectedRating > 0 ? '$selectedRating / $maxRating' : 'Tap to rate',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
        ),
      ],
    );
  }

  Widget _buildBooleanOptions(BuildContext context, bool isDark) {
    final selectedValue = currentValue as String?;

    return Row(
      children: [
        Expanded(
          child: _buildBooleanButton(
            context: context,
            label: 'Yes',
            isSelected: selectedValue == 'yes',
            onTap: () => onValueChanged('yes'),
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildBooleanButton(
            context: context,
            label: 'No',
            isSelected: selectedValue == 'no',
            onTap: () => onValueChanged('no'),
            color: AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildBooleanButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : null,
            ),
          ),
        ),
      ),
    );
  }
}
