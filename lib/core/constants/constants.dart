import 'package:flutter/material.dart';

class Constants {
  static const String appName = 'Vlone Blog';
  static const String supabaseUrl = 'https://vviomlivjkhlwturqnoz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2aW9tbGl2amtobHd0dXJxbm96Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2MzUzMTIsImV4cCI6MjA3NjIxMTMxMn0.BTMh9nSsI1TWFCvauxpteW15eVlOVATlyEnMq2vgaOw';

  // Colors
  static const Color primaryColor = Colors.blue;
  static const Color accentColor = Colors.blueAccent;
  static const Color backgroundColor = Colors.white;
  static const Color errorColor = Colors.red;

  // Strings
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  static const String feedRoute = '/feed';
  static const String reelsRoute = '/reels';
  static const String profileRoute = '/profile';
  static const String favoritesRoute = '/favorites';
  static const String followersRoute = '/followers';
  static const String followingRoute = '/following';
  static const String createPostRoute = '/create-post/:userId';
  static const String postDetailsRoute = '/post';
  static const String usersRoute = '/users';
  static const String notificationsRoute = '/notifications';

  // Other
  static const int maxVideoDurationSeconds = 600; // 10 minutes
}
