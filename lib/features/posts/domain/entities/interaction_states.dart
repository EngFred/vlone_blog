class InteractionStates {
  final Set<String> likedPostIds;
  final Set<String> favoritedPostIds;

  const InteractionStates({
    required this.likedPostIds,
    required this.favoritedPostIds,
  });

  InteractionStates copyWith({
    Set<String>? likedPostIds,
    Set<String>? favoritedPostIds,
  }) {
    return InteractionStates(
      likedPostIds: likedPostIds ?? this.likedPostIds,
      favoritedPostIds: favoritedPostIds ?? this.favoritedPostIds,
    );
  }

  bool isLiked(String postId) => likedPostIds.contains(postId);
  bool isFavorited(String postId) => favoritedPostIds.contains(postId);
}
