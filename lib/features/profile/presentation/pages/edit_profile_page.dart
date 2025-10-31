// lib/features/profile/presentation/pages/edit_profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/core/utils/crop_utils.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/domain/entities/profile_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfilePage extends StatefulWidget {
  final String userId;
  const EditProfilePage({super.key, required this.userId});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  // Changed from XFile? to File? to hold the post-crop file.
  File? _profileImageFile;
  bool _isSubmitting = false;

  ProfileEntity? _initialProfile;
  bool _hasInitializedControllers = false;

  @override
  void initState() {
    super.initState();
    // Initialize from current state if already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = context.read<ProfileBloc>().state;
      if (currentState is ProfileDataLoaded && !_hasInitializedControllers) {
        _initializeFromProfile(currentState.profile);
      }
    });
  }

  void _initializeFromProfile(ProfileEntity profile) {
    if (_hasInitializedControllers) return;

    setState(() {
      _initialProfile = profile;
      _usernameController.text = profile.username;
      _bioController.text = profile.bio ?? '';
      _hasInitializedControllers = true;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isSubmitting) return;

    try {
      final picker = ImagePicker();
      final pickedXFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedXFile != null) {
        final imageFile = File(pickedXFile.path);

        // Use the centralized cropping utility
        final croppedFile = await cropImageFile(
          context,
          imageFile,
          lockSquare: true,
        );

        if (croppedFile != null) {
          // If cropping was successful, update the state with the File
          setState(() {
            _profileImageFile = croppedFile;
          });
        }
      }
    } catch (e) {
      SnackbarUtils.showError(context, 'Failed to pick or load image.');
      debugPrint('Error picking or loading image: $e');
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final newUsername = _usernameController.text.trim();
    final newBio = _bioController.text.trim().isEmpty
        ? null
        : _bioController.text.trim();

    // Check for actual changes
    final usernameChanged =
        _initialProfile == null || newUsername != _initialProfile!.username;
    final bioChanged =
        _initialProfile == null || newBio != _initialProfile!.bio;

    // Check for image change using the new File field
    final hasImage = _profileImageFile != null;

    if (!usernameChanged && !bioChanged && !hasImage) {
      SnackbarUtils.showInfo(context, 'No changes detected.');
      return;
    }

    // Dispatch update
    setState(() => _isSubmitting = true);
    context.read<ProfileBloc>().add(
      UpdateProfileEvent(
        userId: widget.userId,
        username: usernameChanged ? newUsername : null,
        bio: bioChanged ? newBio : null,
        // Pass the File object to the BLoC by converting it back to XFile
        // (assuming the BLoC still expects XFile for profileImage).
        profileImage: hasImage ? XFile(_profileImageFile!.path) : null,
      ),
    );
  }

  // Helper for consistent input styling
  InputDecoration _getInputDecoration(String labelText, {String? hintText}) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Lighter fill so inputs look airy in both light and dark modes.
    final borderColor = isLight
        ? theme.colorScheme.onSurface.withOpacity(0.08)
        : theme.colorScheme.outline.withOpacity(0.6);

    final fillColor = isLight
        ? theme.colorScheme.surfaceVariant.withOpacity(0.04)
        : theme.colorScheme.surfaceVariant.withOpacity(0.06);

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
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
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileError) {
            setState(() => _isSubmitting = false);
            SnackbarUtils.showError(context, state.message);
          } else if (state is ProfileDataLoaded) {
            // Success handler - just pop and show success
            // NO manual refetch needed - real-time stream will update the profile!
            if (_isSubmitting) {
              setState(() => _isSubmitting = false);
              SnackbarUtils.showSuccess(
                context,
                'Profile updated successfully!',
              );
              // Just pop - the ProfilePage's real-time stream will receive the update
              context.pop();
              return;
            }
            // Initial load logic
            if (!_hasInitializedControllers) {
              _initializeFromProfile(state.profile);
            }
          }
        },
        builder: (context, state) {
          if (state is ProfileInitial ||
              (state is ProfileLoading && !_hasInitializedControllers)) {
            return const Center(child: LoadingIndicator());
          }

          // Use AbsorbPointer + Opacity to prevent interactions while submitting.
          return AbsorbPointer(
            absorbing: _isSubmitting,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Avatar preview and pick area
                  Tooltip(
                    message: 'Tap to change profile photo',
                    child: Semantics(
                      label: 'Profile photo, tap to change',
                      button: true,
                      child: GestureDetector(
                        onTap: _isSubmitting ? null : _pickImage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              backgroundImage: _profileImageFile != null
                                  ? FileImage(_profileImageFile!)
                                        as ImageProvider
                                  : (_initialProfile?.profileImageUrl != null
                                        ? CachedNetworkImageProvider(
                                            _initialProfile!.profileImageUrl!,
                                          )
                                        : null),
                              child:
                                  _profileImageFile == null &&
                                      (_initialProfile?.profileImageUrl == null)
                                  ? Icon(
                                      Icons.person,
                                      size: 54,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    )
                                  : null,
                            ),

                            // Small edit badge at bottom-right instead of full overlay.
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
                                      onTap: _isSubmitting ? null : _pickImage,
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

                            // Semi-transparent overlay shown only when submitting so user sees the disabled state
                            if (_isSubmitting)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.brightness == Brightness.light
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
                    onPressed: _isSubmitting ? null : _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: Text(
                      _profileImageFile != null
                          ? 'Image Selected (Tap to Change/Crop)'
                          : 'Change Profile Photo',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Section
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          decoration: _getInputDecoration('Username'),
                          maxLength: 30,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Username cannot be empty';
                            if (v.trim().length < 3)
                              return 'Username too short';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _bioController,
                          decoration: _getInputDecoration(
                            'Bio',
                            hintText: 'Tell people about yourself (optional)',
                          ),
                          maxLines: 4,
                          maxLength: 160,
                          keyboardType: TextInputType.multiline,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              // explicit disabled look to improve clarity
                              disabledBackgroundColor: theme
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.12),
                              disabledForegroundColor: theme
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.38),
                            ),
                            child: _isSubmitting
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
