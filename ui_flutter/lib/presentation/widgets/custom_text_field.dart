import 'dart:async';
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
///   realtimeValidation: true,
/// )
/// ```
class CustomTextField extends StatefulWidget {
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

  /// Enable real-time validation as the user types (debounced 500ms).
  /// Shows a green checkmark on valid fields and animates error text.
  final bool realtimeValidation;

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
    this.realtimeValidation = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  GlobalKey<FormFieldState>? _fieldKey;
  Timer? _debounceTimer;
  bool _isValid = false;
  bool _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    if (widget.realtimeValidation) {
      _fieldKey = GlobalKey<FormFieldState>();
      widget.controller?.addListener(_onTextChanged);
    }
  }

  @override
  void didUpdateWidget(CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.realtimeValidation != widget.realtimeValidation) {
      if (oldWidget.realtimeValidation) {
        oldWidget.controller?.removeListener(_onTextChanged);
      }
      if (widget.realtimeValidation) {
        widget.controller?.addListener(_onTextChanged);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.realtimeValidation) {
      widget.controller?.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    _hasInteracted = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        final isValid = _fieldKey?.currentState?.validate() ?? false;
        if (_isValid != isValid) {
          setState(() => _isValid = isValid);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine keyboard type from field type if not explicitly set
    final effectiveKeyboardType = widget.keyboardType ?? _getKeyboardType();

    // Get autofill hints
    final autofillHints = _getAutofillHints();

    // Build effective suffix icon with optional green check
    final showValidState = widget.realtimeValidation &&
        widget.validator != null &&
        _hasInteracted &&
        _isValid &&
        (widget.controller?.text.isNotEmpty ?? false);

    Widget? effectiveSuffixIcon = widget.suffixIcon ?? widget.suffix;
    if (showValidState) {
      const checkIcon = Padding(
        padding: EdgeInsets.only(right: 4),
        child: Icon(Icons.check_circle, color: AppColors.success, size: 20),
      );
      if (effectiveSuffixIcon != null) {
        effectiveSuffixIcon = Row(
          mainAxisSize: MainAxisSize.min,
          children: [checkIcon, effectiveSuffixIcon],
        );
      } else {
        effectiveSuffixIcon = checkIcon;
      }
    }

    Widget fieldColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
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
          key: _fieldKey,
            controller: widget.controller,
            obscureText: widget.obscureText,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            keyboardType: effectiveKeyboardType,
            textInputAction: widget.textInputAction ?? TextInputAction.next,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            focusNode: widget.focusNode,
            autofillHints: autofillHints,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
            buildCounter: widget.showCounter
                ? null
                : (context,
                        {required currentLength,
                        required isFocused,
                        required maxLength}) =>
                    null,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helperText,
              errorText: widget.errorText,
              filled: widget.filled,
              fillColor: widget.fillColor ??
                  (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
              contentPadding: widget.contentPadding ??
                  EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      size: AppSpacing.iconMd + 2,
                    )
                  : widget.prefix,
              suffixIcon: effectiveSuffixIcon,
              border: OutlineInputBorder(
                borderRadius: AppSpacing.borderRadiusMd,
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppSpacing.borderRadiusMd,
                borderSide: BorderSide(
                  color: showValidState
                      ? AppColors.success
                      : (isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppSpacing.borderRadiusMd,
                borderSide: BorderSide(
                  color:
                      showValidState ? AppColors.success : AppColors.primary,
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

    // Only wrap in AnimatedSize when realtime validation is active
    final Widget field = widget.realtimeValidation
        ? AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: fieldColumn,
          )
        : fieldColumn;

    // Wrap with semantics
    return Semantics(
      textField: true,
      label: widget.semanticLabel ?? widget.label ?? widget.hint,
      enabled: widget.enabled,
      child: field,
    );
  }

  TextInputType? _getKeyboardType() {
    return switch (widget.fieldType) {
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
    return switch (widget.fieldType) {
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
  final bool realtimeValidation;

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
    this.realtimeValidation = false,
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
      realtimeValidation: realtimeValidation,
    );
  }
}
