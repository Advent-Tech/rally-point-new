import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../../core/theme/app_colors.dart';

/// Widget for capturing signatures in surveys
class SignaturePadWidget extends StatefulWidget {
  final String? initialSignature;
  final bool isRequired;
  final ValueChanged<Uint8List?> onSignatureChanged;

  const SignaturePadWidget({
    super.key,
    this.initialSignature,
    this.isRequired = false,
    required this.onSignatureChanged,
  });

  @override
  State<SignaturePadWidget> createState() => _SignaturePadWidgetState();
}

class _SignaturePadWidgetState extends State<SignaturePadWidget> {
  late SignatureController _controller;
  Uint8List? _signatureData;
  bool _hasSignature = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
      exportPenColor: Colors.black,
      onDrawStart: () => setState(() => _hasSignature = true),
      onDrawEnd: () => _saveSignature(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      _signatureData = null;
      widget.onSignatureChanged(null);
      return;
    }

    try {
      final signature = await _controller.toPngBytes();
      if (signature != null) {
        setState(() => _signatureData = signature);
        widget.onSignatureChanged(signature);
      }
    } catch (e) {
      debugPrint('Error saving signature: $e');
    }
  }

  void _clearSignature() {
    _controller.clear();
    setState(() {
      _hasSignature = false;
      _signatureData = null;
    });
    widget.onSignatureChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Signature pad
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasSignature
                  ? AppColors.primary
                  : AppColors.borderLight,
              width: _hasSignature ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Signature(
              controller: _controller,
              height: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Instructions and actions
        Row(
          children: [
            Expanded(
              child: Text(
                _hasSignature
                    ? 'Signature captured'
                    : 'Sign above using your finger',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
            ),
            if (_hasSignature)
              TextButton.icon(
                onPressed: _clearSignature,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
          ],
        ),

        // Preview signature if captured
        if (_signatureData != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withAlpha(50)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Signature saved',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
