import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:vlone_blog_app/core/domain/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/settings/domain/usecases/get_theme_mode.dart';
import 'package:vlone_blog_app/features/settings/domain/usecases/save_theme_mode.dart';

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final GetThemeMode getThemeMode;
  final SaveThemeMode saveThemeMode;

  SettingsBloc(this.getThemeMode, this.saveThemeMode)
    : super(const SettingsInitial(ThemeMode.system)) {
    on<LoadSettings>(_onLoadSettings);
    on<ChangeThemeMode>(_onChangeThemeMode);

    // Automatically load saved settings when bloc is created.
    // We dispatch the event after handlers are registered.
    add(LoadSettings());
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final result = await getThemeMode(NoParams());
    result.fold(
      (failure) {
        AppLogger.error('Failed to load theme mode: $failure');
        emit(SettingsLoaded(state.themeMode));
      },
      (modeStr) {
        ThemeMode mode = ThemeMode.system;
        if (modeStr != null) {
          switch (modeStr) {
            case 'light':
              mode = ThemeMode.light;
              break;
            case 'dark':
              mode = ThemeMode.dark;
              break;
            default:
              mode = ThemeMode.system;
          }
        }
        AppLogger.info('Loaded theme mode: $mode');
        emit(SettingsLoaded(mode));
      },
    );
  }

  Future<void> _onChangeThemeMode(
    ChangeThemeMode event,
    Emitter<SettingsState> emit,
  ) async {
    final modeStr = event.mode == ThemeMode.light
        ? 'light'
        : event.mode == ThemeMode.dark
        ? 'dark'
        : 'system';
    final result = await saveThemeMode(modeStr);
    result.fold(
      (failure) {
        AppLogger.error('Failed to save theme mode: $failure');
        // If saving fails we still reflect the user's choice in UI (so user sees their change),
        emit(SettingsLoaded(event.mode));
      },
      (_) {
        AppLogger.info('Changed theme mode to: ${event.mode}');
        emit(SettingsLoaded(event.mode));
      },
    );
  }
}
