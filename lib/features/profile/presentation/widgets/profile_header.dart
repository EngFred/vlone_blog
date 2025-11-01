import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/service/media_download_service.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';

class ProfileHeader extends StatelessWidget {
  final ProfileEntity profile;
  final bool isOwnProfile;
  final bool? isFollowing;
  final bool isProcessingFollow;
  final Function(bool)? onFollowToggle;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    this.isFollowing,
    this.isProcessingFollow = false,
    this.onFollowToggle,
  });

  static const Duration _followDebounce = Duration(milliseconds: 400);

  /// Show the full-screen profile image overlay with download option
  void _showProfileImageOverlay(BuildContext context, String? imageUrl) {
    if (imageUrl == null) return;

    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool _isDownloading = false;
        double _downloadProgress = 0.0;

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> _startDownload() async {
              if (_isDownloading) return;

              if (!sl.isRegistered<MediaDownloadService>()) {
                AppLogger.error('MediaDownloadService not registered in GetIt');
                SnackbarUtils.showError(
                  dialogContext,
                  'Download service unavailable. Restart the app.',
                );
                return;
              }

              final MediaDownloadService downloadService =
                  sl<MediaDownloadService>();

              setState(() {
                _isDownloading = true;
                _downloadProgress = 0.0;
              });

              SnackbarUtils.showInfo(dialogContext, 'Starting download...');

              try {
                final result = await downloadService.downloadAndSaveMedia(
                  imageUrl,
                  'image',
                  onReceiveProgress: (received, total) {
                    if (!dialogContext.mounted) return;
                    if (total > 0) {
                      setState(() {
                        _downloadProgress = received / total;
                      });
                    }
                  },
                );

                if (!dialogContext.mounted) return;

                setState(() => _isDownloading = false);

                switch (result.status) {
                  case DownloadResultStatus.success:
                    SnackbarUtils.showSuccess(
                      dialogContext,
                      'Image saved to gallery!',
                    );
                    break;
                  case DownloadResultStatus.failure:
                    AppLogger.error(
                      'Profile image download failed: ${result.message}',
                    );
                    SnackbarUtils.showError(
                      dialogContext,
                      result.message ?? 'Download failed.',
                    );
                    break;
                  case DownloadResultStatus.permissionDenied:
                    SnackbarUtils.showWarning(
                      dialogContext,
                      'Storage permission is required to save images.',
                    );
                    break;
                  case DownloadResultStatus.permissionPermanentlyDenied:
                    SnackbarUtils.showWarning(
                      dialogContext,
                      'Permission denied. Please enable storage access in app settings.',
                      action: SnackBarAction(
                        label: 'SETTINGS',
                        textColor: Colors.white,
                        onPressed: openAppSettings,
                      ),
                    );
                    break;
                }
              } catch (e, st) {
                AppLogger.error(
                  'Unhandled download error',
                  error: e,
                  stackTrace: st,
                );
                if (!dialogContext.mounted) return;
                setState(() => _isDownloading = false);
                SnackbarUtils.showError(
                  dialogContext,
                  'Download failed unexpectedly. Please try again.',
                );
              }
            }

            final theme = Theme.of(context);

            return Scaffold(
              backgroundColor: Colors.black.withOpacity(0.9),
              body: Stack(
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Center(
                      child: Hero(
                        tag: 'profileImage-${profile.id}',
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          placeholder: (c, u) => Center(
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          errorWidget: (c, u, e) => const Icon(
                            Icons.error,
                            color: Colors.white,
                            size: 80,
                          ),
                          fit: BoxFit.contain,
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                        ),
                      ),
                    ),
                  ),

                  // Close Button (Top Right)
                  Positioned(
                    top: 36.0,
                    right: 16.0,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 30,
                        ),
                        tooltip: 'Close image view',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                  ),

                  // Download Button (Top Left)
                  Positioned(
                    top: 36.0,
                    left: 16.0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: _isDownloading
                            ? Container(
                                width: 40,
                                height: 40,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 1,
                                  ),
                                ),
                                child:
                                    _downloadProgress > 0 &&
                                        _downloadProgress <= 1.0
                                    ? Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              value: _downloadProgress,
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      ),
                              )
                            : InkWell(
                                onTap: _startDownload,
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.download_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFollowIconOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final icon = isFollowing! ? Icons.check : Icons.add;
    final backgroundColor = isFollowing!
        ? theme.colorScheme.surfaceVariant
        : theme.colorScheme.primary;
    final foregroundColor = isFollowing!
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onPrimary;

    return GestureDetector(
      onTap: isProcessingFollow || onFollowToggle == null
          ? null
          : () {
              Debouncer.instance.debounce(
                'follow_${profile.id}',
                _followDebounce,
                () {
                  onFollowToggle!(!isFollowing!);
                },
              );
            },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.surface, width: 3),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: foregroundColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFollowOverlay =
        !isOwnProfile && isFollowing != null && onFollowToggle != null;

    return Container(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar
              GestureDetector(
                onTap: () =>
                    _showProfileImageOverlay(context, profile.profileImageUrl),
                child: Hero(
                  tag: 'profileImage-${profile.id}',
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    backgroundImage: profile.profileImageUrl != null
                        ? CachedNetworkImageProvider(profile.profileImageUrl!)
                        : null,
                    child: profile.profileImageUrl == null
                        ? Icon(
                            Icons.person,
                            size: 54,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                ),
              ),

              if (showFollowOverlay && !isProcessingFollow)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildFollowIconOverlay(context),
                ),

              if (showFollowOverlay && isProcessingFollow)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Username & Email
          Text(
            profile.username,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            profile.email,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                profile.bio!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCountColumn(context, 'Posts', profile.postsCount, null),
                const SizedBox(height: 40, child: VerticalDivider(width: 1)),
                _buildCountColumn(
                  context,
                  'Followers',
                  profile.followersCount,
                  '/followers/${profile.id}',
                ),
                const SizedBox(height: 40, child: VerticalDivider(width: 1)),
                _buildCountColumn(
                  context,
                  'Following',
                  profile.followingCount,
                  '/following/${profile.id}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountColumn(
    BuildContext context,
    String label,
    int count,
    String? route,
  ) {
    return Expanded(
      child: InkWell(
        onTap: route != null ? () => context.push(route) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
