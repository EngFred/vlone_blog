class ErrorMessageMapper {
  /// Maps technical error messages to user-friendly messages
  static String mapToUserMessage(String technicalMessage) {
    final lowerMessage = technicalMessage.toLowerCase();

    // Network-related errors
    if (lowerMessage.contains('socketexception') ||
        lowerMessage.contains('failed host lookup') ||
        lowerMessage.contains('no internet connection') ||
        lowerMessage.contains('network error')) {
      return 'Please check your internet connection and try again.';
    }

    // Authentication errors
    if (lowerMessage.contains('invalid login credentials') ||
        lowerMessage.contains('invalid credentials')) {
      return 'Invalid email or password. Please try again.';
    }

    if (lowerMessage.contains('user already registered') ||
        lowerMessage.contains('email already exists')) {
      return 'This email is already registered. Please use a different email or login.';
    }

    if (lowerMessage.contains('weak password')) {
      return 'Password must be at least 6 characters long.';
    }

    if (lowerMessage.contains('no user logged in') ||
        lowerMessage.contains('not authenticated')) {
      return 'Please log in to continue.';
    }

    // Profile/Update errors
    if (lowerMessage.contains('username') && lowerMessage.contains('taken')) {
      return 'This username is already taken. Please choose another.';
    }

    if (lowerMessage.contains('failed to upload')) {
      return 'Failed to upload image. Please try again.';
    }

    // Database/Server errors
    if (lowerMessage.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (lowerMessage.contains('server error') ||
        lowerMessage.contains('internal error')) {
      return 'Something went wrong on our end. Please try again later.';
    }

    if (lowerMessage.contains('not found')) {
      return 'The requested item could not be found.';
    }

    if (lowerMessage.contains('permission denied') ||
        lowerMessage.contains('unauthorized')) {
      return 'You do not have permission to perform this action.';
    }

    // Generic fallback
    return 'An unexpected error occurred. Please try again.';
  }

  /// Returns a user-friendly message for specific error types
  static String getErrorMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred.';

    final errorString = error.toString();
    return mapToUserMessage(errorString);
  }
}
