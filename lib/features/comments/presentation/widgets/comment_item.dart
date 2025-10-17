import 'package:flutter/material.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/profile/domain/usecases/get_profile_usecase.dart';

class CommentItem extends StatefulWidget {
  final CommentEntity comment;
  final String? parentUsername; // Pass if reply

  const CommentItem({super.key, required this.comment, this.parentUsername});

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  String? _username;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final result = await sl<GetProfileUseCase>()(widget.comment.userId);
    result.fold(
      (failure) => null,
      (profile) => setState(() {
        _username = profile.username;
        _profileImageUrl = profile.profileImageUrl;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: _profileImageUrl != null
            ? NetworkImage(_profileImageUrl!)
            : null,
      ),
      title: Text(_username ?? 'Loading...'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.parentUsername != null)
            Text('Replying to @$widget.parentUsername'),
          Text(widget.comment.text),
        ],
      ),
      trailing: Text(widget.comment.formattedCreatedAt),
      contentPadding: EdgeInsets.only(
        left: widget.comment.parentCommentId != null ? 32 : 16,
      ),
    );
  }
}
