import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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

  XFile? _pickedImage;
  bool _isSubmitting = false;

  ProfileEntity? _initialProfile;

  @override
  void initState() {
    super.initState();
    // Ensure profile is loaded
    context.read<ProfileBloc>().add(GetProfileDataEvent(widget.userId));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isSubmitting) return; // Prevent picking while submitting

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = picked;
      });
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
    final hasImage = _pickedImage != null;

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
        profileImage: _pickedImage,
      ),
    );
  }

  // Helper for consistent input styling
  InputDecoration _getInputDecoration(String labelText, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileError) {
            setState(() => _isSubmitting = false);
            SnackbarUtils.showError(context, state.message);
          } else if (state is ProfileDataLoaded) {
            // Success handler logic
            if (_isSubmitting) {
              setState(() => _isSubmitting = false);
              SnackbarUtils.showSuccess(
                context,
                'Profile updated successfully!',
              );
              context.pop();
              return;
            }
            // Initial load logic
            if (_initialProfile == null) {
              _initialProfile = state.profile;
              _usernameController.text = state.profile.username;
              _bioController.text = state.profile.bio ?? '';
            }
          }
        },
        builder: (context, state) {
          if (state is ProfileInitial ||
              state is ProfileLoading && _initialProfile == null) {
            return const Center(child: LoadingIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Avatar preview and pick area
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceVariant,
                        backgroundImage: _pickedImage != null
                            ? FileImage(File(_pickedImage!.path))
                                  as ImageProvider
                            : (_initialProfile?.profileImageUrl != null
                                  ? CachedNetworkImageProvider(
                                      _initialProfile!.profileImageUrl!,
                                    )
                                  : null),
                        child:
                            _pickedImage == null &&
                                (_initialProfile?.profileImageUrl == null)
                            ? Icon(
                                Icons.person,
                                size: 54,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                      // Overlay to clearly indicate tap area
                      Positioned.fill(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.black54.withOpacity(
                            _isSubmitting ? 0.6 : 0.0,
                          ), // Darken on submission
                          child: Icon(
                            Icons.camera_alt,
                            size: 32,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: Text(
                    _pickedImage != null
                        ? 'Image Selected (Tap to Change)'
                        : 'Change Profile Photo',
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
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Username cannot be empty';
                          if (v.trim().length < 3) return 'Username too short';
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
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
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
          );
        },
      ),
    );
  }
}
