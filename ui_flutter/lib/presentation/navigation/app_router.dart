import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/team_map/team_map_bloc.dart';
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
import '../screens/team_leader/territory_assignment_screen.dart';
import '../screens/team_leader/team_members_screen.dart';
import '../screens/team_leader/reports_screen.dart';
import '../screens/team_leader/schedule_screen.dart';
import '../screens/team_leader/team_map_screen.dart';
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
import '../widgets/bottom_nav_shell.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router(AuthBloc authBloc) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      debugLogDiagnostics: true,
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final isLoggingIn = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/forgot-password';
        final isSplash = state.matchedLocation == '/splash';

        // If still checking auth status, stay on splash
        if (authState is AuthInitial || authState is AuthLoading) {
          return isSplash ? null : '/splash';
        }

        // If not authenticated and not on login/register/forgot-password, redirect to login
        if (authState is AuthUnauthenticated) {
          return isLoggingIn ? null : '/login';
        }

        // If authenticated, handle role-based routing
        if (authState is AuthAuthenticated) {
          if (isLoggingIn || isSplash) {
            // Redirect based on user role
            if (authState.user.isTeamLeader) {
              return '/leader/dashboard';
            } else if (authState.user.isAdmin) {
              return '/admin/dashboard';
            }
            return '/home';
          }

          // Prevent workers from accessing leader routes
          if (authState.user.isWorker && state.matchedLocation.startsWith('/leader')) {
            return '/home';
          }

          // Prevent workers from viewing prayer requests list (they can only create)
          if (authState.user.isWorker && state.matchedLocation == '/prayer-requests') {
            return '/home';
          }

          // Prevent team leaders from accessing worker bottom nav routes
          if (authState.user.isTeamLeader) {
            final workerRoutes = ['/home', '/territory', '/delivery', '/survey'];
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

        // Auth Routes
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'];
            return ForgotPasswordScreen(initialEmail: email);
          },
        ),

        // Worker Routes - Main App Shell with Bottom Navigation
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => BottomNavShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomeScreen(),
              ),
            ),
            GoRoute(
              path: '/territory',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: TerritoryScreen(),
              ),
            ),
            GoRoute(
              path: '/delivery',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DeliveryScreen(),
              ),
            ),
            GoRoute(
              path: '/survey',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SurveyScreen(),
              ),
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ProfileScreen(),
              ),
            ),
            GoRoute(
              path: '/log-visit',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: LogVisitScreen(),
              ),
            ),
            GoRoute(
              path: '/walkie',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: WalkieScreen(),
              ),
            ),
            GoRoute(
              path: '/my-schedule',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: MyScheduleScreen(),
              ),
            ),
            GoRoute(
              path: '/field-actions',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: FieldActionScreen(),
              ),
            ),
            GoRoute(
              path: '/chat',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ConversationsScreen(),
              ),
            ),
            GoRoute(
              path: '/chat/team/:teamId',
              pageBuilder: (context, state) {
                final teamId = state.pathParameters['teamId'] ?? '';
                final teamName = state.uri.queryParameters['name'];
                return NoTransitionPage(
                  child: TeamChatScreen(teamId: teamId, teamName: teamName),
                );
              },
            ),
            GoRoute(
              path: '/chat/:conversationId',
              pageBuilder: (context, state) {
                final conversationId = state.pathParameters['conversationId'] ?? '';
                return NoTransitionPage(
                  child: ChatScreen(conversationId: conversationId),
                );
              },
            ),
            GoRoute(
              path: '/blogs',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: BlogScreen(),
              ),
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

        // Prayer request form route (accessible from anywhere)
        GoRoute(
          path: '/prayer-requests/new',
          builder: (context, state) => BlocProvider(
            create: (_) => PrayerRequestBloc(),
            child: const PrayerRequestFormScreen(),
          ),
        ),

        // Blog detail route (accessible from anywhere)
        GoRoute(
          path: '/blogs/:id',
          builder: (context, state) {
            final blogId = state.pathParameters['id'] ?? '';
            return BlogDetailScreen(blogId: blogId);
          },
        ),

        // Team Leader Routes - Stack Navigation (no bottom nav)
        GoRoute(
          path: '/leader/dashboard',
          builder: (context, state) => const TeamLeaderDashboard(),
        ),
        GoRoute(
          path: '/leader/territory-assignment',
          builder: (context, state) {
            // Get pre-selected worker from query params (from Team Members screen)
            final workerId = state.uri.queryParameters['workerId'];
            final workerName = state.uri.queryParameters['workerName'];
            return TerritoryAssignmentScreen(
              preSelectedWorkerId: workerId,
              preSelectedWorkerName: workerName,
            );
          },
        ),
        GoRoute(
          path: '/leader/team-members',
          builder: (context, state) => const TeamMembersScreen(),
        ),
        GoRoute(
          path: '/leader/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/leader/schedule',
          builder: (context, state) => const ScheduleScreen(),
        ),
        GoRoute(
          path: '/leader/team-map',
          builder: (context, state) => BlocProvider(
            create: (_) => TeamMapBloc(),
            child: const TeamMapScreen(),
          ),
        ),
        GoRoute(
          path: '/leader/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/leader/worker-activity/:workerId',
          builder: (context, state) {
            final workerId = state.pathParameters['workerId'] ?? '';
            final workerName = state.uri.queryParameters['name'] ?? 'Worker';
            return WorkerActivityScreen(
              workerId: workerId,
              workerName: workerName,
            );
          },
        ),
        // Worker assignments - shows territory assignments for a specific worker
        GoRoute(
          path: '/leader/worker-assignments/:workerId',
          builder: (context, state) {
            final workerId = state.pathParameters['workerId'] ?? '';
            final workerName = state.uri.queryParameters['name'] ?? 'Worker';
            // Reuse WorkerActivityScreen which shows territory sessions
            return WorkerActivityScreen(
              workerId: workerId,
              workerName: workerName,
            );
          },
        ),
        // Team Leader Worker Verification Route
        GoRoute(
          path: '/leader/worker-verification',
          builder: (context, state) => const WorkerVerificationScreen(),
        ),
        // Team Leader Survey Route
        GoRoute(
          path: '/leader/survey',
          builder: (context, state) => const SurveyScreen(),
        ),
        // Team Leader Chat Routes
        GoRoute(
          path: '/leader/chat',
          builder: (context, state) => const ConversationsScreen(),
        ),
        GoRoute(
          path: '/leader/chat/team/:teamId',
          builder: (context, state) {
            final teamId = state.pathParameters['teamId'] ?? '';
            final teamName = state.uri.queryParameters['name'];
            return TeamChatScreen(teamId: teamId, teamName: teamName);
          },
        ),
        GoRoute(
          path: '/leader/chat/:conversationId',
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId'] ?? '';
            return ChatScreen(conversationId: conversationId);
          },
        ),
        // Team Leader Blog Route
        GoRoute(
          path: '/leader/blogs',
          builder: (context, state) => const BlogScreen(),
        ),
        // Team Leader Prayer Request Routes
        GoRoute(
          path: '/leader/prayer-requests',
          builder: (context, state) => BlocProvider(
            create: (_) => PrayerRequestBloc(),
            child: const PrayerRequestScreen(),
          ),
        ),
        GoRoute(
          path: '/leader/prayer-requests/new',
          builder: (context, state) => BlocProvider(
            create: (_) => PrayerRequestBloc(),
            child: const PrayerRequestFormScreen(),
          ),
        ),

        // Admin Routes (placeholder for future implementation)
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const _PlaceholderScreen(title: 'Admin Dashboard'),
        ),
      ],
    );
  }
}

// Helper class to listen to BLoC stream for GoRouter refresh
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream stream) {
    notifyListeners();
    stream.listen((_) => notifyListeners());
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
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
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
