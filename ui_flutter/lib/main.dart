import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/theme/theme_bloc.dart';
import 'presentation/blocs/territory/territory_bloc.dart';
import 'presentation/blocs/location/location_bloc.dart';
import 'presentation/blocs/delivery/delivery_bloc.dart';

import 'presentation/blocs/team_map/team_map_bloc.dart';
import 'presentation/blocs/schedule/schedule_bloc.dart';
import 'presentation/blocs/survey/survey_bloc.dart';
import 'presentation/blocs/profile/profile_bloc.dart';
import 'presentation/navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const RallyPointApp());
}

class RallyPointApp extends StatelessWidget {
  const RallyPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
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
    );
  }
}
