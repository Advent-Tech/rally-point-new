import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/worker_tracking/worker_tracking_bloc.dart';
import '../blocs/prayer_request/prayer_request_bloc.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/territory/territory_screen.dart';
import '../screens/delivery/delivery_screen.dart';
import '../screens/survey/survey_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/team_leader/team_leader_dashboard.dart';
import '../screens/team_leader/team_members_screen.dart';
import '../screens/team_leader/reports_screen.dart';
import '../screens/team_leader/schedule_screen.dart';
import '../screens/team_leader/leader_targets_screen.dart';
import '../screens/team_leader/worker_detail_screen.dart';
import '../screens/team_leader/command_center/command_center_screen.dart';
import '../screens/team_leader/command_center/command_center_state.dart';
import '../screens/team_leader/worker_activity_screen.dart';
import '../screens/team_leader/worker_verification_screen.dart';
import '../screens/home/log_visit_screen.dart';
import '../screens/walkie/walkie_screen.dart';
import '../screens/worker/my_schedule_screen.dart';
import '../screens/field/field_action_screen.dart';
import '../screens/chat/conversations_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/team_chat_screen.dart';
import '../screens/blog/blog_screen.dart';
import '../screens/blog/blog_detail_screen.dart';
import '../screens/prayer/prayer_request_screen.dart';
import '../screens/prayer/prayer_request_form_screen.dart';
import '../screens/notification/notification_center_screen.dart';
import '../screens/notification/notification_settings_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/worker/targets_screen.dart';
import '../screens/worker/achievements_screen.dart';
import '../widgets/bottom_nav_shell.dart';
import '../../core/navigation/page_transitions.dart';

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();
  static final _leaderShellNavigatorKey = GlobalKey<NavigatorState>();

  /// Pre-loaded onboarding status set from main.dart to avoid async in redirect
  static bool onboardingCompleted = false;

  static GoRouter router(AuthBloc authBloc) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: onboardingCompleted ? '/splash' : '/onboarding',
      debugLogDiagnostics: true,
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final isAuthPage =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/forgot-password';
        final isSplash = state.matchedLocation == '/splash';
        final isOnboarding = state.matchedLocation == '/onboarding';

        // Always allow onboarding screen access (it handles its own exit)
        if (isOnboarding) return null;

        // If still checking auth status, stay on splash
        if (authState is AuthInitial || authState is AuthLoading) {
          return isSplash ? null : '/splash';
        }

        // Handle intermediate auth states - don't redirect, let the page handle it
        // These states are handled by BlocListeners on the auth pages
        if (authState is AuthRegistrationSuccess ||
            authState is AuthPendingVerification ||
            authState is AuthEmailVerificationRequired ||
            authState is AuthAccountRejected ||
            authState is AuthForgotPasswordSuccess ||
            authState is AuthEmailVerified ||
            authState is AuthPasswordResetSuccess ||
            authState is AuthResendVerificationSuccess ||
            authState is AuthError) {
          // Stay on current auth page to show dialog/message
          return isAuthPage ? null : '/login';
        }

        // If not authenticated and not on auth pages, redirect to login
        if (authState is AuthUnauthenticated) {
          return isAuthPage ? null : '/login';
        }

        // If authenticated, handle role-based routing
        if (authState is AuthAuthenticated) {
          if (isAuthPage || isSplash) {
            // Redirect based on user role
            if (authState.user.isTeamLeader) {
              return '/leader/dashboard';
            } else if (authState.user.isAdmin) {
              return '/admin/dashboard';
            }
            return '/home';
          }

          // Prevent workers from accessing leader routes
          if (authState.user.isWorker &&
              state.matchedLocation.startsWith('/leader')) {
            return '/home';
          }

          // Prevent workers from viewing prayer requests list (they can only create)
          if (authState.user.isWorker &&
              state.matchedLocation == '/prayer-requests') {
            return '/home';
          }

          // Prevent team leaders from accessing worker bottom nav routes
          if (authState.user.isTeamLeader) {
            final workerRoutes = [
              '/home',
              '/territory',
              '/delivery',
              '/survey',
            ];
            if (workerRoutes.contains(state.matchedLocation)) {
              return '/leader/dashboard';
            }
          }
        }

        return null;
      },
      routes: [
        // Splash Screen
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),

        // Onboarding
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),

        // Auth Routes
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => AppPageTransitions.fade(
            key: state.pageKey,
            child: const LoginScreen(),
          ),
        ),
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) => AppPageTransitions.fade(
            key: state.pageKey,
            child: const RegisterScreen(),
          ),
        ),
        GoRoute(
          path: '/forgot-password',
          pageBuilder: (context, state) {
            final email = state.uri.queryParameters['email'];
            return AppPageTransitions.fade(
              key: state.pageKey,
              child: ForgotPasswordScreen(initialEmail: email),
            );
          },
        ),

        // Worker Routes - Main App Shell with Bottom Navigation
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => BottomNavShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomeScreen()),
            ),
            GoRoute(
              path: '/territory',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: TerritoryScreen()),
            ),
            GoRoute(
              path: '/delivery',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DeliveryScreen()),
            ),
            GoRoute(
              path: '/survey',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SurveyScreen()),
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProfileScreen()),
            ),
            GoRoute(
              path: '/log-visit',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: LogVisitScreen()),
            ),
            GoRoute(
              path: '/walkie',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: WalkieScreen()),
            ),
            GoRoute(
              path: '/my-schedule',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: MyScheduleScreen()),
            ),
            GoRoute(
              path: '/field-actions',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: FieldActionScreen()),
            ),
            GoRoute(
              path: '/chat',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ConversationsScreen()),
            ),
            GoRoute(
              path: '/blogs',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: BlogScreen()),
            ),
            GoRoute(
              path: '/prayer-requests',
              pageBuilder: (context, state) => NoTransitionPage(
                child: BlocProvider(
                  create: (_) => PrayerRequestBloc(),
                  child: const PrayerRequestScreen(),
                ),
              ),
            ),
          ],
        ),

        // Worker chat conversation routes (outside shell — no bottom nav)
        GoRoute(
          path: '/chat/team/:teamId',
          pageBuilder: (context, state) {
            final teamId = state.pathParameters['teamId'] ?? '';
            final teamName = state.uri.queryParameters['name'];
            return AppPageTransitions.slide(
              key: state.pageKey,
              child: TeamChatScreen(teamId: teamId, teamName: teamName),
            );
          },
        ),
        GoRoute(
          path: '/chat/:conversationId',
          pageBuilder: (context, state) {
            final conversationId = state.pathParameters['conversationId'] ?? '';
            return AppPageTransitions.slide(
              key: state.pageKey,
              child: ChatScreen(conversationId: conversationId),
            );
          },
        ),

        // Notification routes (accessible from anywhere)
        GoRoute(
          path: '/notifications',
          pageBuilder: (context, state) => AppPageTransitions.slide(
            key: state.pageKey,
            child: const NotificationCenterScreen(),
          ),
        ),
        GoRoute(
          path: '/notifications/settings',
          pageBuilder: (context, state) => AppPageTransitions.slideUp(
            key: state.pageKey,
            child: const NotificationSettingsScreen(),
          ),
        ),

        // Prayer request form route (accessible from anywhere)
        GoRoute(
          path: '/prayer-requests/new',
          pageBuilder: (context, state) => AppPageTransitions.slideUp(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => PrayerRequestBloc(),
              child: const PrayerRequestFormScreen(),
            ),
          ),
        ),

        // Blog detail route (accessible from anywhere)
        GoRoute(
          path: '/blogs/:id',
          pageBuilder: (context, state) {
            final blogId = state.pathParameters['id'] ?? '';
            return AppPageTransitions.slide(
              key: state.pageKey,
              child: BlogDetailScreen(blogId: blogId),
            );
          },
        ),

        // Targets route (accessible from anywhere)
        GoRoute(
          path: '/targets',
          pageBuilder: (context, state) => AppPageTransitions.slide(
            key: state.pageKey,
            child: const TargetsScreen(),
          ),
        ),

        // Achievements route (accessible from anywhere)
        GoRoute(
          path: '/achievements',
          pageBuilder: (context, state) => AppPageTransitions.slide(
            key: state.pageKey,
            child: const AchievementsScreen(),
          ),
        ),

        // Team Leader Routes - Main App Shell with Bottom Navigation
        ShellRoute(
          navigatorKey: _leaderShellNavigatorKey,
          builder: (context, state, child) => BottomNavShell(child: child),
          routes: [
            GoRoute(
              path: '/leader/dashboard',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: TeamLeaderDashboard()),
            ),
            GoRoute(
              path: '/leader/team-members',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: TeamMembersScreen()),
            ),
            GoRoute(
              path: '/leader/survey',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SurveyScreen()),
            ),
            GoRoute(
              path: '/leader/targets',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: LeaderTargetsScreen()),
            ),
            GoRoute(
              path: '/leader/reports',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ReportsScreen()),
            ),
          ],
        ),

        // Team Leader Deep/Stack Routes (no bottom nav)

        // ── Unified Command Center (replaces team-map, worker-tracking, territory-assignment) ──
        GoRoute(
          path: '/leader/command-center',
          pageBuilder: (context, state) {
            final modeParam = state.uri.queryParameters['mode'];
            final initialMode = switch (modeParam) {
              'workers' => MapMode.workers,
              'territories' => MapMode.territories,
              _ => MapMode.overview,
            };
            return AppPageTransitions.slide(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => WorkerTrackingBloc(),
                child: CommandCenterScreen(
                  initialMode: initialMode,
                  deepLinkWorkerId: state.uri.queryParameters['workerId'],
                  deepLinkWorkerName: state.uri.queryParameters['workerName'],
                  preSelectedWorkerId:
                      state.uri.queryParameters['preSelectedWorkerId'],
                  preSelectedWorkerName:
                      state.uri.queryParameters['preSelectedWorkerName'],
                ),
              ),
            );
          },
        ),

        // ── Worker Detail Screen (from reports or map markers) ──
        GoRoute(
          path: '/leader/worker/:workerId',
          pageBuilder: (context, state) {
            final workerId = state.pathParameters['workerId'] ?? '';
            final workerName = state.uri.queryParameters['name'];
            final teamId = state.uri.queryParameters['teamId'];
            return AppPageTransitions.slide(
              key: state.pageKey,
              child: WorkerDetailScreen(
                workerId: workerId,
                workerName: workerName,
                teamId: teamId,
              ),
            );
          },
        ),

        // ── Redirects for old routes → Command Center ──
        GoRoute(
          path: '/leader/team-map',
          redirect: (_, __) => '/leader/command-center?mode=overview',
        ),
        GoRoute(
          path: '/leader/worker-tracking',
          redirect: (_, __) => '/leader/command-center?mode=workers',
        ),
        GoRoute(
          path: '/leader/worker-trail/:workerId',
          redirect: (_, state) {
            final workerId = state.pathParameters['workerId'] ?? '';
            final workerName = state.uri.queryParameters['name'] ?? 'Worker';
            return '/leader/command-center?mode=workers&workerId=$workerId&workerName=${Uri.encodeComponent(workerName)}';
          },
        ),
        GoRoute(
          path: '/leader/territory-assignment',
          redirect: (_, state) {
            final workerId = state.uri.queryParameters['workerId'];
            final workerName = state.uri.queryParameters['workerName'];
            var target = '/leader/command-center?mode=territories';
            if (workerId != null) target += '&preSelectedWorkerId=$workerId';
            if (workerName != null)
              target +=
                  '&preSelectedWorkerName=${Uri.encodeComponent(workerName)}';
            return target;
          },
        ),

        GoRoute(
          path: '/leader/schedule',
          pageBuilder: (context, state) => AppPageTransitions.slide(
            key: state.pageKey,
            child: const ScheduleScreen(),
          ),
        ),
        GoRoute(
          path: '/leader/profile',
          pageBuilder: (context, state) => AppPageTransitions.slide(
            key: state.pageKey,
            child: const ProfileScreen(),
          ),
        ),
        GoRoute(
          path: '/leader/worker-activity/:workerId',
          pageBuilder: (context, state) {
            final workerId = state.pathParameters['workerId'] ?? '';
            final workerName = state.uri.queryParameters['name'] ?? 'Worker';
            return AppPageTransitions.slide(
              key: state.pageKey,
              child: WorkerActivityScreen(
                workerId: workerId,
                workerName: workerName,
              ),
            );
          },
        ),
        GoRoute(
          path: '/leader/worker-assignments/:workerId',
          pageBuilder: (context, state) {
            final workerId = state.pathParameters['workerId'] ?? '';
            final workerName = state.uri.queryParameters['name'] ?? 'Worker';
            return AppPageTransitions.slide(
              key: state.pageKey,
              child: WorkerActivityScreen(
                workerId: workerId,
                workerName: workerName,
              ),
            );
          },
        ),
        GoRoute(
          path: '/leader/worker-verification',
          pageBuilder: (context, state) => AppPageTransitions.slide(
            key: state.pageKey,
            child: const WorkerVerificationScreen(),
          ),
        ),
        // Team Leader Chat Routes
        GoRoute(
          path: '/leader/chat',
          pageBuilder: (context, state) => AppPageTransitions.slide(
            key: state.pageKey,
            child: const ConversationsScreen(),
          ),
        ),
        GoRoute(
          path: '/leader/chat/team/:teamId',
          pageBuilder: (context, state) {
            final teamId = state.pathParameters['teamId'] ?? '';
            final teamName = state.uri.queryParameters['name'];
            return AppPageTransitions.slide(
              key: state.pageKey,
              child: TeamChatScreen(teamId: teamId, teamName: teamName),
            );
          },
        ),
        GoRoute(
          path: '/leader/chat/:conversationId',
          pageBuilder: (context, state) {
            final conversationId = state.pathParameters['conversationId'] ?? '';
            return AppPageTransitions.slide(
              key: state.pageKey,
              child: ChatScreen(conversationId: conversationId),
            );
          },
        ),
        // Team Leader Walkie Talkie Route
        GoRoute(
          path: '/leader/walkie',
          pageBuilder: (context, state) => AppPageTransitions.slide(
            key: state.pageKey,
            child: const WalkieScreen(),
          ),
        ),
        // Team Leader Blog Route
        GoRoute(
          path: '/leader/blogs',
          pageBuilder: (context, state) => AppPageTransitions.slide(
            key: state.pageKey,
            child: const BlogScreen(),
          ),
        ),
        // Team Leader Prayer Request Routes
        GoRoute(
          path: '/leader/prayer-requests',
          pageBuilder: (context, state) => AppPageTransitions.slide(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => PrayerRequestBloc(),
              child: const PrayerRequestScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/leader/prayer-requests/new',
          pageBuilder: (context, state) => AppPageTransitions.slideUp(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => PrayerRequestBloc(),
              child: const PrayerRequestFormScreen(),
            ),
          ),
        ),

        // Admin Routes (placeholder for future implementation)
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) =>
              const _PlaceholderScreen(title: 'Admin Dashboard'),
        ),
      ],
    );
  }
}

// Helper class to listen to BLoC stream for GoRouter refresh
// Only notifies on actual authentication state changes, not intermediate states
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    stream.listen((state) {
      // Only refresh router for these states - NOT for intermediate states like
      // AuthRegistrationSuccess, AuthPendingVerification, etc.
      // Those states are handled by listeners on the pages themselves
      if (state is AuthInitial ||
          state is AuthLoading ||
          state is AuthAuthenticated ||
          state is AuthUnauthenticated) {
        print('🔄 GoRouter refresh for state: ${state.runtimeType}');
        notifyListeners();
      } else {
        print('⏭️ GoRouter skipping refresh for state: ${state.runtimeType}');
      }
    });
  }
}

// Placeholder screen for routes not yet implemented
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Coming soon...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
