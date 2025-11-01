import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/settings/presentation/bloc/settings_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Helper function to build the interactive theme option buttons
    Widget _buildThemeOption({
      required IconData icon,
      required String label,
      required ThemeMode mode,
      required ThemeMode currentMode,
    }) {
      final isSelected = mode == currentMode;
      final colorScheme = Theme.of(context).colorScheme;

      final color = isSelected
          ? colorScheme.onPrimaryContainer
          : Theme.of(context).textTheme.bodyMedium!.color;
      final backgroundColor = isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surface;

      return Expanded(
        child: InkWell(
          onTap: () {
            if (mode != currentMode) {
              AppLogger.info('Changing theme to $mode');
              context.read<SettingsBloc>().add(ChangeThemeMode(mode));
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : Theme.of(context).dividerColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // Restructured body to use Column for sticky footer layout
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final currentMode = state.themeMode;
          return Column(
            children: [
              // Expanded ListView for main scrollable content (Theme Selection)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Theme Selection - IMPROVED UI/UX
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme Preference',
                              style: Theme.of(context).textTheme.titleMedium!
                                  .copyWith(
                                    // Explicitly set text color to ensure it follows the theme's surface contrast
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildThemeOption(
                                  icon: Icons.brightness_auto,
                                  label: 'System',
                                  mode: ThemeMode.system,
                                  currentMode: currentMode,
                                ),
                                _buildThemeOption(
                                  icon: Icons.light_mode,
                                  label: 'Light',
                                  mode: ThemeMode.light,
                                  currentMode: currentMode,
                                ),
                                _buildThemeOption(
                                  icon: Icons.dark_mode,
                                  label: 'Dark',
                                  mode: ThemeMode.dark,
                                  currentMode: currentMode,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Sticky Footer Content (Developer Info)
              Padding(
                padding: const EdgeInsets.only(
                  top: 8.0,
                  bottom: 24.0,
                  left: 16.0,
                  right: 16.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Copyright text - Now using hintColor for reliable theme-aware subtlety
                    const Divider(height: 1),
                    const SizedBox(height: 5),
                    Text(
                      '© Engineer Fred 2025',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    // Inspiration text - Now using hintColor for reliable theme-aware subtlety
                    Text(
                      'Inspired by Instagram and Flutter clean architecture.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
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
