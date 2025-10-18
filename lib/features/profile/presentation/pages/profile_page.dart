import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:vlone_blog_app/features/profile/presentation/widgets/profile_posts_list.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _checkIfOwnProfile();
    final bloc = context.read<ProfileBloc>();
    final currentState = bloc.state;
    if (!(currentState is ProfileDataLoaded &&
        currentState.profile.id == widget.userId)) {
      bloc.add(GetProfileDataEvent(widget.userId));
    }
  }

  Future<void> _checkIfOwnProfile() async {
    final result = await sl<GetCurrentUserUseCase>()(NoParams());
    result.fold(
      (failure) =>
          AppLogger.error('Failed to check current user: ${failure.message}'),
      (user) {
        if (mounted) {
          setState(() => _isOwnProfile = user.id == widget.userId);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditDialog(context),
            ),
        ],
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading || state is ProfileInitial) {
            return const Center(child: LoadingIndicator());
          }
          if (state is ProfileError) {
            return Center(
              child: CustomErrorWidget(
                message: state.message,
                onRetry: () {
                  context.read<ProfileBloc>().add(
                    GetProfileDataEvent(widget.userId),
                  );
                },
              ),
            );
          }
          if (state is ProfileDataLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<ProfileBloc>().add(
                  GetProfileDataEvent(widget.userId),
                );
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    ProfileHeader(
                      profile: state.profile,
                      isOwnProfile: _isOwnProfile,
                    ),
                    // Pass all the post-related data to the list widget
                    ProfilePostsList(
                      posts: state.posts,
                      isLoading: state.arePostsLoading,
                      error: state.postsError,
                      onRetry: () {
                        context.read<ProfileBloc>().add(
                          GetProfileDataEvent(widget.userId),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final bioController = TextEditingController();
    XFile? selectedImage;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bioController,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final picker = ImagePicker();
                selectedImage = await picker.pickImage(
                  source: ImageSource.gallery,
                );
              },
              child: const Text('Pick Profile Image'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ctx.pop();
              context.read<ProfileBloc>().add(
                UpdateProfileEvent(
                  userId: widget.userId,
                  bio: bioController.text.isEmpty ? null : bioController.text,
                  profileImage: selectedImage,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
