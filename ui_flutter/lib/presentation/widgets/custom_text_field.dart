import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Input field type for autofill hints
enum InputFieldType {
  text,
  email,
  password,
  newPassword,
  name,
  phone,
  address,
  postalCode,
  url,
}

/// A customizable text field with accessibility and autofill support.
///
/// Example:
/// ```dart
/// CustomTextField(
///   controller: _emailController,
///   label: 'Email',
///   hint: 'Enter your email',
///   fieldType: InputFieldType.email,
///   prefixIcon: Icons.email_outlined,
/// )
/// ```
class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final void Function()? onTap;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final bool filled;

  /// Semantic label for screen readers (defaults to label)
  final String? semanticLabel;

  /// Input field type for autofill hints
  final InputFieldType? fieldType;

  /// Whether to show character counter
  final bool showCounter;

  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.prefix,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.contentPadding,
    this.fillColor,
    this.filled = true,
    this.semanticLabel,
    this.fieldType,
    this.showCounter = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine keyboard type from field type if not explicitly set
    final effectiveKeyboardType = keyboardType ?? _getKeyboardType();

    // Get autofill hints
    final autofillHints = _getAutofillHints();

    Widget field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
          ),
          SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          keyboardType: effectiveKeyboardType,
          textInputAction: textInputAction ?? TextInputAction.next,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTap: onTap,
          focusNode: focusNode,
          autofillHints: autofillHints,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
          buildCounter: showCounter
              ? null
              : (context,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  null,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            errorText: errorText,
            filled: filled,
            fillColor: fillColor ??
                (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            contentPadding: contentPadding ??
                EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    size: AppSpacing.iconMd + 2,
                  )
                : prefix,
            suffixIcon: suffixIcon ?? suffix,
            border: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMd,
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMd,
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMd,
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMd,
              borderSide: const BorderSide(
                color: AppColors.error,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMd,
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMd,
              borderSide: BorderSide(
                color: (isDark ? AppColors.borderDark : AppColors.borderLight)
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );

    // Wrap with semantics
    return Semantics(
      textField: true,
      label: semanticLabel ?? label ?? hint,
      enabled: enabled,
      child: field,
    );
  }

  TextInputType? _getKeyboardType() {
    return switch (fieldType) {
      InputFieldType.email => TextInputType.emailAddress,
      InputFieldType.phone => TextInputType.phone,
      InputFieldType.url => TextInputType.url,
      InputFieldType.address => TextInputType.streetAddress,
      InputFieldType.postalCode => TextInputType.number,
      InputFieldType.password ||
      InputFieldType.newPassword =>
        TextInputType.visiblePassword,
      _ => null,
    };
  }

  List<String>? _getAutofillHints() {
    return switch (fieldType) {
      InputFieldType.email => [AutofillHints.email],
      InputFieldType.password => [AutofillHints.password],
      InputFieldType.newPassword => [AutofillHints.newPassword],
      InputFieldType.name => [AutofillHints.name],
      InputFieldType.phone => [AutofillHints.telephoneNumber],
      InputFieldType.address => [AutofillHints.fullStreetAddress],
      InputFieldType.postalCode => [AutofillHints.postalCode],
      InputFieldType.url => [AutofillHints.url],
      _ => null,
    };
  }
}

/// Search variant of the text field with pill shape
class CustomSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final void Function()? onClear;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;

  const CustomSearchField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  });

  @override
  State<CustomSearchField> createState() => _CustomSearchFieldState();
}

class _CustomSearchFieldState extends State<CustomSearchField> {
  late TextEditingController _controller;
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _showClear = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final shouldShow = _controller.text.isNotEmpty;
    if (_showClear != shouldShow) {
      setState(() => _showClear = shouldShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      textField: true,
      label: widget.semanticLabel ?? 'Search',
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hint ?? 'Search...',
          filled: true,
          fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smd,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          suffixIcon: _showClear
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onClear?.call();
                    widget.onChanged?.call('');
                  },
                  tooltip: 'Clear search',
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// A text area variant for multi-line input
class CustomTextArea extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool showCounter;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final String? semanticLabel;

  const CustomTextArea({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.minLines = 3,
    this.maxLines = 6,
    this.maxLength,
    this.enabled = true,
    this.showCounter = true,
    this.validator,
    this.onChanged,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      errorText: errorText,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      showCounter: showCounter,
      validator: validator,
      onChanged: onChanged,
      semanticLabel: semanticLabel,
      textInputAction: TextInputAction.newline,
      keyboardType: TextInputType.multiline,
    );
  }
}
