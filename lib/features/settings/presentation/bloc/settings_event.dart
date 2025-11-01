part of 'settings_bloc.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object> get props => [];
}

class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

class ChangeThemeMode extends SettingsEvent {
  final ThemeMode mode;

  const ChangeThemeMode(this.mode);

  @override
  List<Object> get props => [mode];
}
