import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'dart:math';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _themeOptions = <_ThemeOptionData>[
    _ThemeOptionData(ThemeMode.system, 'Auto', Icons.brightness_auto),
    _ThemeOptionData(ThemeMode.light, 'Light', Icons.wb_sunny),
    _ThemeOptionData(ThemeMode.dark, 'Dark', Icons.nightlight_round),
  ];

  static final List<String> _funnyMessages = [
    "Oops! Nothing here yet 😅",
    "Coming soon… maybe 😎",
    "Your click has been registered… invisibly 🕵️‍♂️",
    "This feature is just pretending to work 🤡",
    "Fun fact: clicking here does nothing 🤔",
    "Hold on! Still loading… forever ⏳",
    "You found the secret invisible button 👻",
  ];

  void _showRandomFunnySnackbar(BuildContext context) {
    final random = Random();
    final message = _funnyMessages[random.nextInt(_funnyMessages.length)];
    SnackbarUtils.showInfo(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: Theme.of(context).brightness,
        systemNavigationBarColor: Theme.of(context).colorScheme.background,
      ),
      child: Scaffold(
        body: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 140,
                  collapsedHeight: 80,
                  stretch: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Settings',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onBackground,
                        ),
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorScheme.primary.withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _SettingsSection(
                        title: "APPEARANCE",
                        icon: Icons.palette,
                        children: [
                          _ModernThemeSelector(
                            options: _themeOptions,
                            current: state.themeMode,
                            onSelected: (selectedMode) {
                              if (selectedMode != state.themeMode) {
                                HapticFeedback.lightImpact();
                                AppLogger.info(
                                  'Changing theme to $selectedMode',
                                );
                                context.read<SettingsBloc>().add(
                                  ChangeThemeMode(selectedMode),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _SettingsSection(
                        title: "PREFERENCES",
                        icon: Icons.settings,
                        children: [
                          _ModernSettingsTile(
                            icon: Icons.language,
                            title: "Language & Region",
                            subtitle: "English • United States",
                            trailing: Icons.arrow_forward_ios,
                            onTap: () => _showRandomFunnySnackbar(context),
                            hasDivider: true,
                          ),
                          _ModernSettingsTile(
                            icon: Icons.notifications,
                            title: "Notifications",
                            subtitle: "Customize your alerts",
                            trailing: Icons.arrow_forward_ios,
                            onTap: () => _showRandomFunnySnackbar(context),
                            hasDivider: true,
                          ),
                          _ModernSettingsTile(
                            icon: Icons.security,
                            title: "Privacy & Security",
                            subtitle: "Manage your data",
                            trailing: Icons.arrow_forward_ios,
                            onTap: () => _showRandomFunnySnackbar(context),
                            hasDivider: true,
                          ),
                          _ModernSettingsTile(
                            icon: Icons.cloud_upload,
                            title: "Backup & Sync",
                            subtitle: "Last backup: Today",
                            trailing: Icons.arrow_forward_ios,
                            onTap: () => _showRandomFunnySnackbar(context),
                            hasDivider: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _SettingsSection(
                        title: "SUPPORT",
                        icon: Icons.help,
                        children: [
                          _ModernSettingsTile(
                            icon: Icons.help_center,
                            title: "Help Center",
                            subtitle: "Get answers to your questions",
                            trailing: Icons.arrow_forward_ios,
                            onTap: () => _showRandomFunnySnackbar(context),
                            hasDivider: true,
                          ),
                          _ModernSettingsTile(
                            icon: Icons.info,
                            title: "About Vlone Blog",
                            subtitle: "Version 2.4.1 • Build 825",
                            trailing: Icons.arrow_forward_ios,
                            onTap: () => _showRandomFunnySnackbar(context),
                            hasDivider: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      _AppFooter(),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onBackground.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _ModernThemeSelector extends StatelessWidget {
  final List<_ThemeOptionData> options;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelected;

  const _ModernThemeSelector({
    required this.options,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme Preference',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose how the app looks and feels',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onBackground.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colorScheme.onBackground.withOpacity(0.02),
              border: Border.all(
                color: colorScheme.onBackground.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: options.map((opt) {
                final bool isSelected = opt.mode == current;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubicEmphasized,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colorScheme.primary.withOpacity(0.9),
                                  colorScheme.primary.withOpacity(0.7),
                                ],
                              )
                            : null,
                        color: isSelected ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSelected(opt.mode),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    opt.icon,
                                    size: 20,
                                    color: isSelected
                                        ? colorScheme.onPrimary
                                        : colorScheme.onBackground.withOpacity(
                                            0.6,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: theme.textTheme.labelMedium!.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? colorScheme.onPrimary
                                        : colorScheme.onBackground.withOpacity(
                                            0.6,
                                          ),
                                  ),
                                  child: Text(opt.label),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback onTap;
  final bool hasDivider;

  const _ModernSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    required this.hasDivider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onBackground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onBackground.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    trailing,
                    size: 18,
                    color: colorScheme.onBackground.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasDivider)
          Padding(
            padding: const EdgeInsets.only(left: 76),
            child: Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.onBackground.withOpacity(0.1),
            ),
          ),
      ],
    );
  }
}

class _AppFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 24, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.onBackground.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Vlone Blog v2.4.1',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onBackground.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Crafted with ❤️ by Engineer Fred',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onBackground.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Inspired by modern design systems',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onBackground.withOpacity(0.3),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionData {
  final ThemeMode mode;
  final String label;
  final IconData icon;
  const _ThemeOptionData(this.mode, this.label, this.icon);
}
