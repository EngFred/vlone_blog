import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
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

    // Avoid sending unchanged values (optional)
    final usernameChanged =
        _initialProfile == null || newUsername != _initialProfile!.username;
    final bioChanged =
        _initialProfile == null || newBio != _initialProfile!.bio;
    final hasImage = _pickedImage != null;

    if (!usernameChanged && !bioChanged && !hasImage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No changes to save')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoading) {
            // show progress via local flag already set when submitting
            AppLogger.info('ProfileBloc: loading');
          } else if (state is ProfileError) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is ProfileDataLoaded) {
            // If we were submitting, this is the update success; pop and show success.
            if (_isSubmitting) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Profile updated')));
              context.pop(); // return to profile screen
              return;
            }
            // initial load: populate fields
            _initialProfile ??= state.profile;
            _usernameController.text = state.profile.username;
            _bioController.text = state.profile.bio ?? '';
          }
        },
        builder: (context, state) {
          if (state is ProfileInitial ||
              state is ProfileLoading && _initialProfile == null) {
            return const Center(child: LoadingIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Avatar preview and pick
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant,
                    backgroundImage: _pickedImage != null
                        ? FileImage(File(_pickedImage!.path)) as ImageProvider
                        : (_initialProfile?.profileImageUrl != null
                              ? CachedNetworkImageProvider(
                                  _initialProfile!.profileImageUrl!,
                                )
                              : null),
                    child:
                        _pickedImage == null &&
                            (_initialProfile?.profileImageUrl == null)
                        ? const Icon(Icons.person, size: 48)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo),
                  label: const Text('Change profile photo'),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
                        maxLength: 30,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Username cannot be empty';
                          if (v.trim().length < 3) return 'Username too short';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bioController,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          hintText: 'Tell people about yourself',
                        ),
                        maxLines: 4,
                        maxLength: 160,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save'),
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
