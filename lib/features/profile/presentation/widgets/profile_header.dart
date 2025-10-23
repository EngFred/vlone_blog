import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  @override
  Widget build(BuildContext context) {
    // Determine if the follow button should be shown
    final showFollowButton =
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
          // 1. Avatar
          CircleAvatar(
            radius: 54,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: profile.profileImageUrl != null
                ? CachedNetworkImageProvider(profile.profileImageUrl!)
                : null,
            child: profile.profileImageUrl == null
                ? Icon(
                    Icons.person,
                    size: 54,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
          const SizedBox(height: 12),

          // 2. Username and Email
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

          // 3. Bio
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

          // 4. Stats
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
          const SizedBox(height: 16),

          // 5. Follow/Unfollow Button (If not own profile)
          if (showFollowButton)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isProcessingFollow
                      ? null
                      : () => onFollowToggle!(!isFollowing!),
                  icon: isProcessingFollow
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isFollowing! ? Icons.person_remove : Icons.person_add,
                        ),
                  label: Text(
                    isFollowing! ? 'Following' : 'Follow',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing!
                        ? Theme.of(context).colorScheme.surfaceVariant
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: isFollowing!
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: isFollowing! ? 0 : 4,
                  ),
                ),
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
