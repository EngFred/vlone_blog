import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';

class ProfileHeader extends StatelessWidget {
  final ProfileEntity profile;
  final bool isOwnProfile; // Pass from page to show navigable counts

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: profile.profileImageUrl != null
                ? CachedNetworkImageProvider(profile.profileImageUrl!)
                : null,
            child: profile.profileImageUrl == null
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            profile.username,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(profile.email, style: const TextStyle(color: Colors.grey)),
          if (profile.bio != null) Text(profile.bio!),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCountColumn(context, 'Posts', profile.postsCount, null),
              _buildCountColumn(
                context,
                'Followers',
                profile.followersCount,
                '/followers/${profile.id}',
              ),
              _buildCountColumn(
                context,
                'Following',
                profile.followingCount,
                '/following/${profile.id}',
              ),
              // _buildCountColumn(context, 'Favorites', profile.favoritesCount, '/favorites'), // Assume own favorites
            ],
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
    return GestureDetector(
      onTap: route != null ? () => context.push(route) : null,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(label),
        ],
      ),
    );
  }
}
