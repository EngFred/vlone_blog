import 'package:dartz/dartz.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/interaction_states.dart';
import 'package:vlone_blog_app/features/posts/domain/repositories/posts_repository.dart';

class GetPostInteractionsParams {
  final String userId;
  final List<String> postIds;

  GetPostInteractionsParams({required this.userId, required this.postIds});
}

class GetPostInteractionsUseCase
    implements UseCase<InteractionStates, GetPostInteractionsParams> {
  final PostsRepository repository;

  GetPostInteractionsUseCase(this.repository);

  @override
  Future<Either<Failure, InteractionStates>> call(
    GetPostInteractionsParams params,
  ) {
    return repository.getPostInteractions(
      userId: params.userId,
      postIds: params.postIds,
    );
  }
}
