import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/settings/presentation/bloc/settings_bloc.dart';

/// Modernized SettingsPage — segmented theme selector with animations, accessibility,
/// and improved spacing/tap targets.
/// Requires: SettingsBloc with `ChangeThemeMode(ThemeMode)` event and `state.themeMode`.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // Small helper to map ThemeMode to a readable label and icon
  static const _options = <_ThemeOptionData>[
    _ThemeOptionData(ThemeMode.system, 'System', Icons.brightness_auto),
    _ThemeOptionData(ThemeMode.light, 'Light', Icons.light_mode),
    _ThemeOptionData(ThemeMode.dark, 'Dark', Icons.dark_mode),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final current = state.themeMode;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  children: [
                    // Header
                    Text('Appearance'),
                    const SizedBox(height: 12),

                    // Card with segmented control
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme Preference',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Segmented control
                            _SegmentedThemeControl(
                              options: _options,
                              current: current,
                              onSelected: (selectedMode) {
                                if (selectedMode != current) {
                                  HapticFeedback.selectionClick();
                                  AppLogger.info(
                                    'Changing theme to $selectedMode',
                                  );
                                  context.read<SettingsBloc>().add(
                                    ChangeThemeMode(selectedMode),
                                  );
                                }
                              },
                            ),

                            const SizedBox(height: 12),

                            // Optional explanatory subtitle
                            Text(
                              'Choose how the app should present colors and surfaces.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Other settings (placeholder) — keeps page from feeling empty
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.language,
                          color: colorScheme.primary,
                        ),
                        title: Text('Language'),
                        subtitle: Text('English (US)'),
                        onTap: () {
                          // keep this expandable later
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Sticky footer / developer info
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  top: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Text(
                      '© Engineer Fred 2025',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inspired by Instagram and Flutter clean architecture.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Internal widget: segmented control with animated selection and accessible taps.
class _SegmentedThemeControl extends StatelessWidget {
  final List<_ThemeOptionData> options;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelected;

  const _SegmentedThemeControl({
    required this.options,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: 'Theme selection',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: options.map((opt) {
            final bool isSelected = opt.mode == current;

            // Animated visual using AnimatedContainer for smooth transitions
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 210),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            // subtle lift for selected
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : theme.dividerColor.withOpacity(0.12),
                      width: isSelected ? 1.3 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelected(opt.mode),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          opt.icon,
                          size: 20,
                          // selected => more contrast
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : theme.iconTheme.color,
                        ),
                        const SizedBox(width: 8),
                        // label with weight contrast
                        Text(
                          opt.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Small data holder
class _ThemeOptionData {
  final ThemeMode mode;
  final String label;
  final IconData icon;
  const _ThemeOptionData(this.mode, this.label, this.icon);
}
