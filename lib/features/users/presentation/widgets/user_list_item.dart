// lib/features/users/presentation/widgets/user_list_item.dart
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
    Debouncer.instance.debounce(key, _debounceDuration, () {
      widget.onFollowToggle(widget.user.id, !widget.user.isFollowing);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme; // Access color scheme here
    final isFollowing = widget.user.isFollowing;
    final isSelf = widget.user.id == widget.currentUserId;

    // Determine the border color based on the current theme brightness
    // This is safer than using theme.dividerColor which might be less defined in M3
    final borderColor = theme.brightness == Brightness.light
        ? Colors.grey[300]
        : theme.dividerColor;

    return InkWell(
      onTap: () => context.push('${Constants.profileRoute}/${widget.user.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          // Use a subtle background color derived from the surface for distinction
          color: colorScheme.surfaceContainer,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: widget.user.profileImageUrl != null
                  ? NetworkImage(widget.user.profileImageUrl!)
                  : null,
              child: widget.user.profileImageUrl == null
                  ? Icon(
                      Icons.person,
                      size: 28,
                      // FIX 1: Set explicit color for the fallback icon
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
                    widget.user.username,
                    style: theme.textTheme.titleMedium?.copyWith(
                      // FIX 2: Set explicit color for the username text
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.bio ?? 'No bio available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      // The bio text color is already theme-aware, which is good.
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
              // Responsive follow button container
              SizedBox(
                height: 38,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: widget.isLoading
                      ? SizedBox(
                          width: 86,
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  // This is fine, using primary and onPrimary correctly
                                  isFollowing
                                      ? colorScheme.primary
                                      : colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        )
                      : ConstrainedBox(
                          // allow the button to size to its content, but cap width
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
                                  ? colorScheme
                                        .surface // Unfollow button background is surface
                                  : colorScheme
                                        .primary, // Follow button background is primary
                              foregroundColor: isFollowing
                                  ? colorScheme
                                        .onSurface // Unfollow button text/icon is onSurface
                                  : colorScheme
                                        .onPrimary, // Follow button text/icon is onPrimary
                              side: isFollowing
                                  ? BorderSide(
                                      color: borderColor!,
                                    ) // Use the calculated border color
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
                            // Use FittedBox so the label scales down instead of being cut off
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
