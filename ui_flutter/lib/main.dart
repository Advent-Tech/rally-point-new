import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/map_constants.dart';
import 'core/storage/local_storage.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/theme/theme_bloc.dart';
import 'presentation/blocs/territory/territory_bloc.dart';
import 'presentation/blocs/location/location_bloc.dart';
import 'presentation/blocs/delivery/delivery_bloc.dart';

import 'presentation/blocs/team_map/team_map_bloc.dart';
import 'presentation/blocs/schedule/schedule_bloc.dart';
import 'presentation/blocs/survey/survey_bloc.dart';
import 'presentation/blocs/profile/profile_bloc.dart';
import 'presentation/widgets/help/help_mode_provider.dart';
import 'services/push_notification_service.dart';

/// Background FCM handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Initialize Mapbox access token
  MapboxOptions.setAccessToken(MapConstants.mapboxAccessToken);

  // Pre-initialize LocalStorage and load onboarding status for sync router access
  final localStorage = await LocalStorage.getInstance();
  AppRouter.onboardingCompleted = localStorage.isOnboardingCompleted();
  print('🚀 main: onboardingCompleted=${AppRouter.onboardingCompleted}');

  // Load persisted help mode setting
  final helpEnabled = await loadHelpMode();

  runApp(RallyPointApp(helpModeEnabled: helpEnabled));
}

class RallyPointApp extends StatelessWidget {
  final bool helpModeEnabled;

  const RallyPointApp({super.key, this.helpModeEnabled = false});

  @override
  Widget build(BuildContext context) {
    return HelpModeProvider(
      notifier: ValueNotifier<bool>(helpModeEnabled),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(create: (context) => AuthBloc()),
          BlocProvider<ThemeBloc>(
            create: (context) => ThemeBloc()..add(const ThemeInitialize()),
          ),
          BlocProvider<TerritoryBloc>(create: (context) => TerritoryBloc()),
          BlocProvider<LocationBloc>(create: (context) => LocationBloc()),
          BlocProvider<DeliveryBloc>(create: (context) => DeliveryBloc()),
          BlocProvider<TeamMapBloc>(create: (context) => TeamMapBloc()),
          BlocProvider<ScheduleBloc>(create: (context) => ScheduleBloc()),
          BlocProvider<SurveyBloc>(create: (context) => SurveyBloc()),
          BlocProvider<ProfileBloc>(create: (context) => ProfileBloc()),
        ],
        child: const _AppContent(),
      ),
    );
  }
}

class _AppContent extends StatefulWidget {
  const _AppContent();

  @override
  State<_AppContent> createState() => _AppContentState();
}

class _AppContentState extends State<_AppContent> {
  late final _router = AppRouter.router(context.read<AuthBloc>());
  bool _pushInitialized = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated && !_pushInitialized) {
          _pushInitialized = true;
          PushNotificationService.instance.initialize();
        } else if (state is AuthInitial || state is AuthError) {
          if (_pushInitialized) {
            _pushInitialized = false;
            PushNotificationService.instance.removeToken();
          }
        }
      },
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: 'Rally Point',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeState.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
