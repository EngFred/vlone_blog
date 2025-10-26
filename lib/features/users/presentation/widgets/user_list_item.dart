import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/features/users/domain/entities/user_list_entity.dart';

class UserListItem extends StatefulWidget {
  final UserListEntity user;
  final String currentUserId;
  final Function(String, bool) onFollowToggle;
  final bool isLoading;

  const UserListItem({
    super.key,
    required this.user,
    required this.currentUserId,
    required this.onFollowToggle,
    this.isLoading = false,
  });

  @override
  State<UserListItem> createState() => _UserListItemState();
}

class _UserListItemState extends State<UserListItem> {
  static const Duration _debounceDuration = Duration(milliseconds: 400);

  void _handleFollowTap() {
    final key = 'user_follow_${widget.user.id}';
    // Use the central Debouncer
    Debouncer.instance.debounce(key, _debounceDuration, () {
      widget.onFollowToggle(widget.user.id, !widget.user.isFollowing);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFollowing = widget.user.isFollowing;
    final isSelf = widget.user.id == widget.currentUserId;

    return GestureDetector(
      onTap: () => context.push('${Constants.profileRoute}/${widget.user.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: widget.user.profileImageUrl != null
                  ? NetworkImage(widget.user.profileImageUrl!)
                  : null,
              child: widget.user.profileImageUrl == null
                  ? const Icon(Icons.person, size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.user.username,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.user.bio ?? 'No bio available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            if (!isSelf)
              SizedBox(
                width: 90,
                height: 36,
                child: ElevatedButton(
                  onPressed: widget.isLoading ? null : _handleFollowTap,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                      side: BorderSide(
                        color: isFollowing
                            ? theme.dividerColor
                            : theme.colorScheme.primary,
                        width: isFollowing ? 1.0 : 0.0,
                      ),
                    ),
                    backgroundColor: isFollowing
                        ? theme.colorScheme.surface
                        : theme.colorScheme.primary,
                    foregroundColor: isFollowing
                        ? theme.textTheme.bodyMedium?.color
                        : theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                  ),
                  child: widget.isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isFollowing
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
