import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import '../blocs/auth/auth_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _floatAnimation = Tween<double>(begin: 0.0, end: -10.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // Check auth status after animation
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        context.read<AuthBloc>().add(const AuthCheckStatus());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colors based on theme
    final backgroundGradient = LinearGradient(
      colors: isDark
          ? const [AppColors.backgroundDark, AppColors.navyBlue]
          : const [AppColors.backgroundLight, Color(0xFFEFF6FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final titleColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final indicatorColor = isDark
        ? AppColors.buttonPrimaryDark
        : AppColors.buttonPrimaryLight;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: backgroundGradient),
            ),
          ),
          Positioned(
            top: -90,
            left: -60,
            child: _GlassBlob(
              color: (isDark ? AppColors.accent : AppColors.secondary)
                  .withValues(alpha: 0.35),
              size: 240,
            ),
          ),
          Positioned(
            bottom: -110,
            right: -90,
            child: _GlassBlob(
              color: indicatorColor.withValues(alpha: 0.28),
              size: 280,
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GlassLogoCard(
                    isDark: isDark,
                    accent: indicatorColor,
                    child: const AppLogo(
                      width: 150,
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Rally Point',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Field Ministry Management',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
                  ),
                  const SizedBox(height: 44),
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      value: _progressAnimation.value == 0
                          ? null
                          : _progressAnimation.value,
                      valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
                      strokeWidth: 3,
                      backgroundColor: indicatorColor.withValues(
                        alpha: isDark ? 0.25 : 0.18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassLogoCard extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final Widget child;

  const _GlassLogoCard({
    required this.isDark,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.50)
        : AppColors.surfaceLight.withValues(alpha: 0.65);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: const SizedBox(width: 240, height: 160),
          ),
          Container(
            width: 240,
            height: 160,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -55,
                  child: _GlassBlob(
                    color: accent.withValues(alpha: 0.25),
                    size: 160,
                  ),
                ),
                Positioned(
                  bottom: -45,
                  left: -50,
                  child: _GlassBlob(
                    color: (isDark ? AppColors.accent : AppColors.secondary)
                        .withValues(alpha: 0.22),
                    size: 170,
                  ),
                ),
                Center(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlassBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(width: size, height: size, color: color),
      ),
    );
  }
}
