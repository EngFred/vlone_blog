import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:vlone_blog_app/core/utils/crop_utils.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/features/auth/domain/entities/user_entity.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/edit_profile_bloc.dart';

class EditProfilePage extends StatefulWidget {
  final String userId;
  const EditProfilePage({super.key, required this.userId});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;

      if (authState is AuthAuthenticated) {
        final currentUser = authState.user;

        // 🌟 FIX: Create ProfileEntity from UserEntity and pass it directly.
        final initialProfileData = ProfileEntity(
          id: currentUser.id,
          username: currentUser.username,
          profileImageUrl: currentUser.profileImageUrl,
          bio: currentUser.bio,
          email: currentUser.email,
        );

        context.read<EditProfileBloc>().add(
          LoadInitialProfileEvent(initialProfileData), // Pass the entity
        );
      } else {
        // Handle case where AuthState is not authenticated (shouldn't happen here)
        SnackbarUtils.showError(
          context,
          'Authentication error: Cannot load profile data.',
        );
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedXFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedXFile != null) {
        final imageFile = File(pickedXFile.path);
        final croppedFile = await cropImageFile(
          context,
          imageFile,
          lockSquare: true,
        );
        if (croppedFile != null) {
          context.read<EditProfileBloc>().add(
            SelectImageEvent(XFile(croppedFile.path)),
          );
        }
      }
    } catch (e) {
      SnackbarUtils.showError(context, 'Failed to pick or load image.');
      debugPrint('Error picking or loading image: $e');
    }
  }

  InputDecoration _getInputDecoration(
    String labelText, {
    String? hintText,
    String? errorText,
  }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final borderColor = isLight
        ? theme.colorScheme.onSurface.withOpacity(0.08)
        : theme.colorScheme.outline.withOpacity(0.6);
    final fillColor = isLight
        ? theme.colorScheme.surfaceVariant.withOpacity(0.04)
        : theme.colorScheme.surfaceVariant.withOpacity(0.06);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      errorText: errorText,
      filled: true,
      fillColor: fillColor,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      hintStyle: theme.textTheme.bodySmall,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: borderColor, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: borderColor, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: false,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        elevation: 0,
      ),
      body: BlocConsumer<EditProfileBloc, EditProfileState>(
        listenWhen: (prev, current) {
          // 1. Listen for one-time events (snackbars, navigation)
          if (current is EditProfileSuccess || current is EditProfileError) {
            return true;
          }
          // 2. Listen for the *first* time we enter the editing state
          //    so we can populate the controllers. (We keep this for good measure)
          if (prev is! EditProfileEditing && current is EditProfileEditing) {
            return true;
          }
          return false;
        },
        listener: (context, state) {
          if (state is EditProfileEditing) {
            if (_usernameController.text.isEmpty) {
              _usernameController.text = state.initialUsername;
            }
            if (_bioController.text.isEmpty) {
              _bioController.text = state.initialBio;
            }
          } else if (state is EditProfileSuccess) {
            SnackbarUtils.showSuccess(context, 'Profile updated successfully!');
            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated) {
              final updatedUser = UserEntity(
                id: state.updatedProfile.id,
                email: authState.user.email,
                username: state.updatedProfile.username,
                profileImageUrl: state.updatedProfile.profileImageUrl,
                bio: state.updatedProfile.bio,
                followersCount: authState.user.followersCount,
                followingCount: authState.user.followingCount,
                postsCount: authState.user.postsCount,
                totalLikes: authState.user.totalLikes,
              );
              // Update AuthBloc with new user data
              context.read<AuthBloc>().add(UpdateUserEvent(updatedUser));
            }
            context.pop();
          } else if (state is EditProfileError) {
            // This error is from the *initial load*
            SnackbarUtils.showError(context, state.message);
          }
        },
        // 🌟🌟🌟 THE FIX IS HERE 🌟🌟🌟
        buildWhen: (prev, current) {
          // Don't rebuild for success, that's handled by the listener.
          if (current is EditProfileSuccess) {
            return false;
          }
          // If the state types are different (e.g., Initial -> Editing),
          // always rebuild.
          if (prev.runtimeType != current.runtimeType) {
            return true;
          }
          // If both are EditProfileEditing, let Equatable decide.
          // This will correctly rebuild if *any* prop changes
          // (usernameError, currentUsername, isSubmitting, etc.)
          if (current is EditProfileEditing && prev is EditProfileEditing) {
            return prev != current; // Relies on Equatable
          }
          // Default case
          return true;
        },
        builder: (context, state) {
          if (state is EditProfileInitial) {
            // Since we load synchronously now, this should only show for a moment
            return const Center(child: LoadingIndicator());
          }
          if (state is EditProfileEditing) {
            final hasErrors =
                state.usernameError != null || state.bioError != null;
            return AbsorbPointer(
              absorbing: state.isSubmitting,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Tooltip(
                      message: 'Tap to change profile photo',
                      child: Semantics(
                        label: 'Profile photo, tap to change',
                        button: true,
                        child: GestureDetector(
                          onTap: state.isSubmitting ? null : _pickImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor:
                                    theme.colorScheme.surfaceVariant,
                                backgroundImage: state.selectedImage != null
                                    ? FileImage(File(state.selectedImage!.path))
                                    : (state.initialImageUrl != null
                                          ? CachedNetworkImageProvider(
                                              state.initialImageUrl!,
                                            )
                                          : null),
                                child:
                                    state.selectedImage == null &&
                                        state.initialImageUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size: 54,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Semantics(
                                  label: 'Change profile photo',
                                  button: true,
                                  child: Tooltip(
                                    message: 'Change profile photo',
                                    child: Material(
                                      shape: const CircleBorder(),
                                      elevation: 4,
                                      color: theme.colorScheme.surface,
                                      child: InkWell(
                                        onTap: state.isSubmitting
                                            ? null
                                            : _pickImage,
                                        customBorder: const CircleBorder(),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.camera_alt_outlined,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (state.isSubmitting)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          theme.brightness == Brightness.light
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: state.isSubmitting ? null : _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: Text(
                        state.selectedImage != null
                            ? 'Image Selected (Tap to Change/Crop)'
                            : 'Change Profile Photo',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Use controller instead of initialValue
                    TextFormField(
                      controller: _usernameController,
                      decoration: _getInputDecoration(
                        'Username',
                        errorText: state.usernameError,
                      ),
                      maxLength: 30,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) => context.read<EditProfileBloc>().add(
                        ChangeUsernameEvent(value),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Use controller instead of initialValue
                    TextFormField(
                      controller: _bioController,
                      decoration: _getInputDecoration(
                        'Bio',
                        hintText: 'Tell people about yourself (optional)',
                        errorText: state.bioError,
                      ),
                      maxLines: 4,
                      maxLength: 100,
                      keyboardType: TextInputType.multiline,
                      onChanged: (value) => context.read<EditProfileBloc>().add(
                        ChangeBioEvent(value),
                      ),
                    ),
                    if (state.generalError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.generalError!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (state.isSubmitting || hasErrors)
                            ? null
                            : () => context.read<EditProfileBloc>().add(
                                SubmitChangesEvent(),
                              ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          disabledBackgroundColor: theme.colorScheme.onSurface
                              .withOpacity(0.12),
                          disabledForegroundColor: theme.colorScheme.onSurface
                              .withOpacity(0.38),
                        ),
                        child: state.isSubmitting
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is EditProfileError) {
            // Since we load synchronously now, this indicates an Auth error
            return Center(child: Text(state.message));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
