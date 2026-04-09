import 'package:flutter/material.dart';

class SuccessCheck extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;
  final VoidCallback? onComplete;

  const SuccessCheck({
    super.key,
    this.size = 80,
    this.color = Colors.green,
    this.duration = const Duration(milliseconds: 800),
    this.onComplete,
  });

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CustomPaint(
              painter: _CheckPainter(
                progress: _checkAnimation.value,
                color: widget.color,
                strokeWidth: widget.size * 0.1,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    canvas.drawCircle(center, radius, paint);

    if (progress > 0) {
      final path = Path();
      final startX = size.width * 0.25;
      final startY = size.height * 0.5;
      final midX = size.width * 0.45;
      final midY = size.height * 0.7;
      final endX = size.width * 0.75;
      final endY = size.height * 0.35;

      if (progress <= 0.5) {
        final t = progress * 2;
        path.moveTo(startX, startY);
        path.lineTo(startX + (midX - startX) * t, startY + (midY - startY) * t);
      } else {
        final t = (progress - 0.5) * 2;
        path.moveTo(startX, startY);
        path.lineTo(midX, midY);
        path.lineTo(midX + (endX - midX) * t, midY + (endY - midY) * t);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class SuccessOverlay extends StatefulWidget {
  final String? message;
  final VoidCallback? onDismiss;
  final Duration duration;

  const SuccessOverlay({
    super.key,
    this.message,
    this.onDismiss,
    this.duration = const Duration(seconds: 2),
  });

  static Future<void> show(
    BuildContext context, {
    String? message,
    VoidCallback? onDismiss,
    Duration? duration,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SuccessOverlay(
        message: message,
        duration: duration ?? const Duration(seconds: 2),
        onDismiss: () {
          Navigator.of(ctx).pop();
          onDismiss?.call();
        },
      ),
    );
  }

  @override
  State<SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<SuccessOverlay> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SuccessCheck(size: 100, color: Colors.green, onComplete: () {}),
            if (widget.message != null) ...[
              const SizedBox(height: 24),
              Text(
                widget.message!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
