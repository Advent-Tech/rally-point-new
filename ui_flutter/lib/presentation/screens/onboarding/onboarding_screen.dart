import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/local_storage.dart';
import '../../widgets/app_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: 'Welcome to RallyPoint',
      description: 'Track territories, visits, and prayer — together.',
      accentColors: [AppColors.buttonPrimaryLight, AppColors.accent],
      heroBuilder: (context) =>
          const AppLogo(width: 160, height: 90, fit: BoxFit.contain),
    ),
    OnboardingSlide(
      title: 'Track your field work',
      description:
          'See assigned territories, check in, and log visits in seconds.',
      accentColors: [AppColors.secondary, AppColors.primary],
      heroBuilder: (context) =>
          const Icon(Icons.map_outlined, size: 72, color: Colors.white),
    ),
    OnboardingSlide(
      title: 'Stay connected',
      description:
          'Coordinate with your team and follow progress in real time.',
      accentColors: [AppColors.success, AppColors.accent],
      heroBuilder: (context) =>
          const Icon(Icons.groups_2_outlined, size: 72, color: Colors.white),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final storage = await LocalStorage.getInstance();
    await storage.setOnboardingCompleted(true);
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.buttonPrimaryDark
        : AppColors.buttonPrimaryLight;

    final backgroundGradient = LinearGradient(
      colors: isDark
          ? const [AppColors.backgroundDark, AppColors.navyBlue]
          : const [AppColors.backgroundLight, Color(0xFFEFF6FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: backgroundGradient),
              ),
            ),
            Positioned(
              top: -80,
              left: -60,
              child: _GlassBlob(
                color: (isDark ? AppColors.accent : AppColors.secondary)
                    .withValues(alpha: 0.35),
                size: 220,
              ),
            ),
            Positioned(
              bottom: -100,
              right: -80,
              child: _GlassBlob(
                color: primaryColor.withValues(alpha: 0.30),
                size: 260,
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 72,
                        child: _currentPage < _slides.length - 1
                            ? TextButton(
                                onPressed: _skip,
                                child: Text(
                                  'Skip',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      _PageIndicator(
                        count: _slides.length,
                        index: _currentPage,
                        color: primaryColor,
                      ),
                      SizedBox(
                        width: 72,
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(
                            'Sign in',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return _OnboardingPage(
                        key: ValueKey('onboarding-page-$index'),
                        slide: slide,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: isDark
                                ? Colors.black
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 8,
                            shadowColor: primaryColor.withValues(alpha: 0.35),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _currentPage < _slides.length - 1
                                  ? 'Next'
                                  : 'Get Started',
                              key: ValueKey(_currentPage),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _currentPage < _slides.length - 1
                            ? 'You can change this later in settings'
                            : 'Welcome — let\'s get started',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
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

class OnboardingSlide {
  final String title;
  final String description;
  final List<Color> accentColors;
  final WidgetBuilder heroBuilder;

  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.accentColors,
    required this.heroBuilder,
  });
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingSlide slide;
  final bool isDark;

  const _OnboardingPage({super.key, required this.slide, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: isDark ? Colors.white : AppColors.textPrimaryLight,
    );

    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: isDark
          ? AppColors.textSecondaryDark
          : AppColors.textSecondaryLight,
      height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.96, end: 1.0),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: _GlassHero(
              isDark: isDark,
              accentColors: slide.accentColors,
              child: slide.heroBuilder(context),
            ),
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              slide.title,
              key: ValueKey(slide.title),
              style: titleStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              slide.description,
              key: ValueKey(slide.description),
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassHero extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final List<Color> accentColors;

  const _GlassHero({
    required this.child,
    required this.isDark,
    required this.accentColors,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.55)
        : AppColors.surfaceLight.withValues(alpha: 0.65);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: const SizedBox(width: 320, height: 200),
          ),
          Container(
            width: 320,
            height: 200,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -50,
                  child: _GlassBlob(
                    color: accentColors.first.withValues(alpha: 0.35),
                    size: 150,
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: -45,
                  child: _GlassBlob(
                    color: accentColors.last.withValues(alpha: 0.30),
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

class _PageIndicator extends StatelessWidget {
  final int count;
  final int index;
  final Color color;

  const _PageIndicator({
    required this.count,
    required this.index,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == i ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == i ? color : color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
