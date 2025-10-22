import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
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
  DateTime? _lastTapTime;
  static const _debounceDuration = Duration(milliseconds: 500);

  void _handleFollowTap() {
    final now = DateTime.now();

    // Debounce: ignore if tapped within debounce duration
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _debounceDuration) {
      return;
    }

    _lastTapTime = now;
    widget.onFollowToggle(widget.user.id, !widget.user.isFollowing);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: widget.user.profileImageUrl != null
            ? NetworkImage(widget.user.profileImageUrl!)
            : null,
        child: widget.user.profileImageUrl == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(widget.user.username),
      subtitle: Text(widget.user.bio ?? 'No bio'),
      trailing: SizedBox(
        width: 100,
        child: ElevatedButton(
          onPressed: widget.isLoading ? null : _handleFollowTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.user.isFollowing ? Colors.grey : null,
            foregroundColor: widget.user.isFollowing ? Colors.white : null,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.user.isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(fontSize: 13),
                ),
        ),
      ),
      onTap: () => context.push('${Constants.profileRoute}/${widget.user.id}'),
    );
  }
}
