import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

class UserListItem extends StatelessWidget {
  final UserListEntity user;
  final String currentUserId;
  final void Function(String, bool) onFollowToggle;
  final bool isLoading;

  const UserListItem({
    super.key,
    required this.user,
    required this.currentUserId,
    required this.onFollowToggle,
    this.isLoading = false,
  });

  static const Duration _debounceDuration = Duration(milliseconds: 400);

  void _handleFollowTap() {
    final key = 'user_follow_${user.id}';
    Debouncer.instance.debounce(key, _debounceDuration, () {
      onFollowToggle(user.id, !user.isFollowing);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFollowing = user.isFollowing;
    final isSelf = user.id == currentUserId;

    final borderColor = theme.brightness == Brightness.light
        ? Colors.grey[300]
        : theme.dividerColor;

    return InkWell(
      onTap: () => context.push('${Constants.profileRoute}/${user.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surfaceContainer,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: user.profileImageUrl != null
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? Icon(
                      Icons.person,
                      size: 28,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.bio ?? 'No bio available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!isSelf)
              SizedBox(
                height: 38,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: isLoading
                      ? SizedBox(
                          width: 86,
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isFollowing
                                      ? colorScheme.primary
                                      : colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 64,
                            maxWidth: 140,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _handleFollowTap,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18.0),
                              ),
                              backgroundColor: isFollowing
                                  ? colorScheme.surface
                                  : colorScheme.primary,
                              foregroundColor: isFollowing
                                  ? colorScheme.onSurface
                                  : colorScheme.onPrimary,
                              side: isFollowing
                                  ? BorderSide(color: borderColor!)
                                  : BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                                vertical: 8.0,
                              ),
                            ),
                            icon: Icon(
                              isFollowing ? Icons.check : Icons.person_add,
                              size: 16,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
