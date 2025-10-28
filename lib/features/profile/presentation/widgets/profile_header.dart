import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
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

  // UPDATED: Helper function to show the full-screen image overlay.
  // Overlay now only exits via the Close button.
  void _showProfileImageOverlay(BuildContext context, String? imageUrl) {
    if (imageUrl == null) {
      return;
    }

    showDialog(
      context: context,
      useSafeArea: false,
      // ⚠️ IMPORTANT: Prevents closing when tapping outside the dialog
      // (the black area) or pressing the device's back button.
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Scaffold(
          // Use Scaffold to properly handle the overlay and AppBar style actions
          backgroundColor: Colors.black.withOpacity(0.9),
          body: Stack(
            children: [
              // 1. Image Content (Center)
              GestureDetector(
                // ❌ REMOVED: onTap handler is removed here to prevent closing on image tap
                onTap: () {},
                child: Center(
                  child: Hero(
                    tag: 'profileImage-${profile.id}',
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
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

              // 2. Close Button (Top Right) - This is now the ONLY way to exit.
              Positioned(
                top:
                    36.0, // Space from the status bar (adjust as needed for aesthetics)
                right: 16.0,
                child: SafeArea(
                  // Ensure button is below the notch/status bar
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
            ],
          ),
        );
      },
    );
  }

  // NEW: Follow icon overlay widget
  Widget _buildFollowIconOverlay(BuildContext context) {
    final theme = Theme.of(context);
    // Determine the icon and background color based on following status
    final icon = isFollowing! ? Icons.check : Icons.add;
    final backgroundColor = isFollowing!
        ? theme
              .colorScheme
              .surfaceVariant // Muted background if following
        : theme.colorScheme.primary; // Primary color if not following

    final foregroundColor = isFollowing!
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onPrimary;

    return GestureDetector(
      onTap: isProcessingFollow || onFollowToggle == null
          ? null
          : () {
              // Apply the same debouncing logic as the old button
              final key = 'follow_${profile.id}';
              Debouncer.instance.debounce(key, _followDebounce, () {
                onFollowToggle!(!isFollowing!);
              });
            },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.surface, // Matches scaffold background
            width: 3,
          ),
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
          // ⚠️ CHANGED: Avatar is now inside a Stack for the overlay
          Stack(
            clipBehavior:
                Clip.none, // Allows the icon to sit outside the circle
            children: [
              // 1. Avatar (Wrapped in GestureDetector and Hero)
              GestureDetector(
                onTap: () =>
                    _showProfileImageOverlay(context, profile.profileImageUrl),
                child: Hero(
                  tag: 'profileImage-${profile.id}', // Hero source tag
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

              // 2. Follow Overlay (if not own profile)
              if (showFollowOverlay && !isProcessingFollow)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildFollowIconOverlay(context),
                ),

              // 3. Loading Spinner Overlay (while processing follow request)
              if (showFollowOverlay && isProcessingFollow)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32, // Match size of icon overlay
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

          // Username & email
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

          // Stats row
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
          // ❌ REMOVED: The large follow/unfollow button is no longer needed
          const SizedBox(height: 16),
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
