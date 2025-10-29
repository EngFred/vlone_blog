import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';

class LoadMoreCommentsUseCase
    implements UseCase<List<CommentEntity>, LoadMoreCommentsParams> {
  final CommentsRepository repository;

  LoadMoreCommentsUseCase(this.repository);

  @override
  Future<Either<Failure, List<CommentEntity>>> call(
    LoadMoreCommentsParams params,
  ) {
    return repository.loadMoreComments(
      params.postId,
      lastCreatedAt: params.lastCreatedAt,
      lastId: params.lastId,
      pageSize: params.pageSize,
    );
  }
}

class LoadMoreCommentsParams extends Equatable {
  final String postId;
  final DateTime lastCreatedAt;
  final String lastId;
  final int pageSize;

  const LoadMoreCommentsParams({
    required this.postId,
    required this.lastCreatedAt,
    required this.lastId,
    this.pageSize = 20,
  });

  @override
  List<Object> get props => [postId, lastCreatedAt, lastId, pageSize];
}
