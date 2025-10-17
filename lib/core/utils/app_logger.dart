import 'dart:developer' as developer;

class AppLogger {
  static void info(String message) {
    developer.log(message, level: 800, name: 'vlone_blog_app');
  }

  static void warning(String message) {
    developer.log(message, level: 900, name: 'vlone_blog_app');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      level: 1200,
      name: 'vlone_blog_app',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
