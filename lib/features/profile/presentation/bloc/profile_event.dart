part of 'profile_bloc.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class GetProfileDataEvent extends ProfileEvent {
  final String userId;
  // ADDED: Optional completer for RefreshIndicator
  final Completer<void>? refreshCompleter;

  const GetProfileDataEvent(this.userId, {this.refreshCompleter});

  @override
  List<Object?> get props => [userId, refreshCompleter];
}

class StartProfileRealtimeEvent extends ProfileEvent {
  final String userId;
  const StartProfileRealtimeEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class StopProfileRealtimeEvent extends ProfileEvent {
  const StopProfileRealtimeEvent();
}

class _RealtimeProfileUpdatedEvent extends ProfileEvent {
  final Map<String, dynamic> updateData;
  const _RealtimeProfileUpdatedEvent(this.updateData);

  @override
  List<Object?> get props => [updateData];
}
