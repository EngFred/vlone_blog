import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaPickerSheet extends StatelessWidget {
  final Function(ImageSource source, bool isImage) onPick;

  const MediaPickerSheet({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Pick Image from Gallery'),
            onTap: () {
              Navigator.pop(context);
              onPick(ImageSource.gallery, true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('Pick Video from Gallery'),
            onTap: () {
              Navigator.pop(context);
              onPick(ImageSource.gallery, false);
            },
          ),
        ],
      ),
    );
  }
}
