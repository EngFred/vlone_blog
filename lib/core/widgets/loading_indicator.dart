import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  // 1. Add a final field for the size
  final double? size;

  // 2. Add the size to the const constructor, setting a default value of 40.0
  // Note: Since 'size' is nullable, we provide the default value inside the build method
  // or use a non-nullable field with a required constructor parameter.
  // For simplicity and flexibility, let's keep 'size' nullable and apply it below.
  const LoadingIndicator({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    // Define a default size if none is provided
    const double defaultSize = 40.0;

    return Center(
      // 3. Use a SizedBox to enforce a size on the CircularProgressIndicator
      child: SizedBox(
        width: size ?? defaultSize,
        height: size ?? defaultSize,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}
