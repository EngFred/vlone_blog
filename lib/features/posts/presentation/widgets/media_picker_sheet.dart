import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaPickerSheet extends StatelessWidget {
  final Function(ImageSource source, bool isImage) onPick;

  const MediaPickerSheet({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tileShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          runSpacing: 10,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0, top: 4.0),
              child: Text(
                'Add Media',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),

            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              shape: tileShape,
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.camera, true);
              },
            ),

            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Record Video'),
              shape: tileShape,
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.camera, false);
              },
            ),

            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Pick Image from Gallery'),
              shape: tileShape,
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.gallery, true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Pick Video from Gallery'),
              shape: tileShape,
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.gallery, false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
