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
    AppLogger.info('Loading profile for user: ${widget.userId}');
    context.read<ProfileBloc>().add(GetProfileEvent(widget.userId));
    context.read<ProfileBloc>().add(GetUserPostsEvent(userId: widget.userId));
    _checkIfOwnProfile();
  }

  Future<void> _checkIfOwnProfile() async {
    try {
      AppLogger.info(
        'Checking if profile belongs to current user: ${widget.userId}',
      );
      final result = await sl<GetCurrentUserUseCase>()(NoParams());
      result.fold(
        (failure) {
          AppLogger.error('Failed to check current user: ${failure.message}');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        },
        (user) {
          AppLogger.info(
            'Current user checked: ${user.id}, isOwnProfile: ${user.id == widget.userId}',
          );
          setState(() => _isOwnProfile = user.id == widget.userId);
        },
      );
    } catch (e) {
      AppLogger.error('Unexpected error checking user: $e', error: e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error checking user: $e')));
    }
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
              onPressed: () {
                AppLogger.info(
                  'Opening edit profile dialog for user: ${widget.userId}',
                );
                _showEditDialog(context);
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            BlocBuilder<ProfileBloc, ProfileState>(
              buildWhen: (prev, curr) =>
                  curr is ProfileLoaded ||
                  curr is ProfileLoading ||
                  curr is ProfileError,
              builder: (context, state) {
                if (state is ProfileLoading) {
                  return const LoadingIndicator();
                } else if (state is ProfileLoaded) {
                  return ProfileHeader(
                    profile: state.profile,
                    isOwnProfile: _isOwnProfile,
                  );
                } else if (state is ProfileError) {
                  return CustomErrorWidget(
                    message: state.message,
                    onRetry: () {
                      AppLogger.info(
                        'Retrying profile load for user: ${widget.userId}',
                      );
                      context.read<ProfileBloc>().add(
                        GetProfileEvent(widget.userId),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            ProfilePostsList(userId: widget.userId),
          ],
        ),
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
            ElevatedButton(
              onPressed: () async {
                AppLogger.info(
                  'Picking profile image for user: ${widget.userId}',
                );
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
              AppLogger.info(
                'Saving profile changes for user: ${widget.userId}',
              );
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

  @override
  void dispose() {
    AppLogger.info('Disposing ProfilePage');
    super.dispose();
  }
}
