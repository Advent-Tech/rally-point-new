import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/storage/local_storage.dart';

part 'theme_event.dart';
part 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  late LocalStorage _localStorage;

  ThemeBloc() : super(ThemeState(themeMode: ThemeMode.light)) {
    on<ThemeInitialize>(_onInitialize);
    on<ThemeChanged>(_onThemeChanged);
  }

  Future<void> _onInitialize(
    ThemeInitialize event,
    Emitter<ThemeState> emit,
  ) async {
    _localStorage = await LocalStorage.getInstance();

    final savedTheme = _localStorage.getThemeMode();
    ThemeMode mode = ThemeMode.light;

    if (savedTheme != null) {
      switch (savedTheme) {
        case 'light':
          mode = ThemeMode.light;
          break;
        case 'dark':
          mode = ThemeMode.dark;
          break;
        default:
          mode = ThemeMode.light;
      }
    }

    emit(ThemeState(themeMode: mode));
  }

  Future<void> _onThemeChanged(
    ThemeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    String themeString;
    switch (event.themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      default:
        themeString = 'light';
    }

    await _localStorage.saveThemeMode(themeString);
    emit(ThemeState(themeMode: event.themeMode));
  }
}
