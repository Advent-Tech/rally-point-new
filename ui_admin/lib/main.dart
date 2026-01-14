import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/storage/secure_storage.dart';
import 'core/network/api_client.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/admin_layout.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/users/users_screen.dart';
import 'presentation/screens/territories/territories_screen.dart';
import 'presentation/screens/surveys/surveys_screen.dart';
import 'presentation/screens/donations/donations_screen.dart';
import 'presentation/screens/teams/teams_screen.dart';
import 'presentation/screens/admins/admins_screen.dart';
import 'presentation/screens/blogs/blogs_screen.dart';
import 'presentation/screens/prayer_requests/prayer_requests_screen.dart';
import 'presentation/screens/analytics/analytics_screen.dart';
import 'presentation/screens/map/admin_map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RallyAdminApp());
}

class RallyAdminApp extends StatefulWidget {
  const RallyAdminApp({super.key});

  @override
  State<RallyAdminApp> createState() => _RallyAdminAppState();
}

class _RallyAdminAppState extends State<RallyAdminApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc();
    _router = _createRouter();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    // Set up auth failure callback to trigger logout
    ApiClient.setAuthFailureCallback(() {
      _authBloc.add(const AuthLogout());
    });

    final storage = await SecureStorage.getInstance();
    final token = await storage.getAccessToken();
    if (token != null) {
      _authBloc.add(const AuthCheckStatus());
    }
  }

  GoRouter _createRouter() {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: GoRouterRefreshStream(_authBloc.stream),
      redirect: (context, state) {
        final authState = _authBloc.state;
        final isAuthenticated = authState is AuthAuthenticated;
        final isLoggingIn = state.matchedLocation == '/login';

        if (!isAuthenticated && !isLoggingIn) {
          return '/login';
        }

        if (isAuthenticated && isLoggingIn) {
          return '/dashboard';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => AdminLayout(
            currentPath: state.matchedLocation,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/users',
              builder: (context, state) => const UsersScreen(),
            ),
            GoRoute(
              path: '/teams',
              builder: (context, state) => const TeamsScreen(),
            ),
            GoRoute(
              path: '/territories',
              builder: (context, state) => const TerritoriesScreen(),
            ),
            GoRoute(
              path: '/surveys',
              builder: (context, state) => const SurveysScreen(),
            ),
            GoRoute(
              path: '/donations',
              builder: (context, state) => const DonationsScreen(),
            ),
            GoRoute(
              path: '/blogs',
              builder: (context, state) => const BlogsScreen(),
            ),
            GoRoute(
              path: '/prayer-requests',
              builder: (context, state) => const PrayerRequestsScreen(),
            ),
            GoRoute(
              path: '/analytics',
              builder: (context, state) => const AnalyticsScreen(),
            ),
            GoRoute(
              path: '/activity-map',
              builder: (context, state) => const AdminMapScreen(),
            ),
            GoRoute(
              path: '/admins',
              builder: (context, state) => const AdminsScreen(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'Rally Point Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}

/// A helper class to refresh GoRouter when auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
