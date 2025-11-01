part of 'settings_bloc.dart';

abstract class SettingsState extends Equatable {
  final ThemeMode themeMode;

  const SettingsState(this.themeMode);

  @override
  List<Object> get props => [themeMode];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial(super.themeMode);
}

class SettingsLoaded extends SettingsState {
  const SettingsLoaded(super.themeMode);
}
