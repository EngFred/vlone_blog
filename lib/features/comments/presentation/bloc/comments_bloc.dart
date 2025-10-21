import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/features/comments/domain/entities/comment_entity.dart';
import 'package:vlone_blog_app/features/comments/domain/repositories/comments_repository.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/add_comment_usecase.dart';
import 'package:vlone_blog_app/features/comments/domain/usecases/get_comments_usecase.dart';

part 'comments_event.dart';
part 'comments_state.dart';

class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  final AddCommentUseCase addCommentUseCase;
  final GetCommentsUseCase getCommentsUseCase;
  final CommentsRepository repository;

  CommentsBloc({
    required this.addCommentUseCase,
    required this.getCommentsUseCase,
    required this.repository,
  }) : super(CommentsInitial()) {
    on<GetCommentsEvent>((event, emit) async {
      emit(CommentsLoading());
      final result = await getCommentsUseCase(event.postId);
      result.fold(
        (failure) => emit(CommentsError(failure.message)),
        (rootComments) => emit(CommentsLoaded(rootComments)),
      );
    });

    on<AddCommentEvent>((event, emit) async {
      final result = await addCommentUseCase(
        AddCommentParams(
          postId: event.postId,
          userId: event.userId,
          text: event.text,
          parentCommentId: event.parentCommentId,
        ),
      );
      result.fold(
        (failure) => emit(CommentsError(failure.message)),
        (_) {}, // Success handled by stream
      );
    });

    on<SubscribeToCommentsEvent>((event, emit) {
      repository
          .getCommentsStream(event.postId)
          .listen(
            (rootComments) {
              add(NewCommentsEvent(rootComments));
            },
            onError: (error) {
              emit(CommentsError(error.toString()));
            },
          );
    });

    on<NewCommentsEvent>((event, emit) {
      emit(CommentsLoaded(event.newComments));
    });
  }
}
