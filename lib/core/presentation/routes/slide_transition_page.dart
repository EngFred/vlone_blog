import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A custom page transition that implements a horizontal slide animation.
///
/// This transition is typically used for navigation to detail screens, sliding the new page in from the right
/// to provide a consistent and modern navigation feel. It wraps the standard GoRouter [CustomTransitionPage].
class SlideTransitionPage extends CustomTransitionPage<void> {
  SlideTransitionPage({required LocalKey super.key, required super.child})
    : super(
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0); // Starts off-screen to the right.
          const end = Offset.zero; // Slides to its final position (center).
          const curve = Curves.easeInOutCubic;
          // Chaining the offset tween with the curve to define the animation behavior.
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          final offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      );
}
