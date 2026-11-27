import 'package:flutter/material.dart';
import 'dart:io';

/// Global ScaffoldMessenger key to guarantee reliable snackbar operations across the app
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Global error handler that converts technical errors to user-friendly messages
class ErrorHandler {
  static ScaffoldMessengerState? _getMessenger(BuildContext? context) {
    if (context != null && context.mounted) {
      try {
        return ScaffoldMessenger.maybeOf(context) ?? rootScaffoldMessengerKey.currentState;
      } catch (_) {
        return rootScaffoldMessengerKey.currentState;
      }
    }
    return rootScaffoldMessengerKey.currentState;
  }

  /// Convert exception to user-friendly, actionable message
  static String getErrorMessage(dynamic error) {
    if (error == null) {
      return 'Something unexpected happened. Check your internet connection and pull down to refresh.';
    }

    // Network errors
    if (error is SocketException) {
      return 'No internet connection. Turn on Wi-Fi or mobile data, then pull down to refresh.';
    }
    
    if (error is HttpException) {
      return 'Unable to reach our server. Check your internet connection or switch networks and retry.';
    }
    
    if (error is HandshakeException) {
      return 'Secure connection failed. Make sure your device date & time are set to automatic, or switch networks.';
    }
    
    if (error is TimeoutException) {
      return 'The connection timed out. Switch to a stronger network or move to a better signal area, then retry.';
    }
    
    // Format exception (JSON parsing errors)
    if (error is FormatException) {
      return 'Could not read the server response. Pull down to refresh, or update the app if this continues.';
    }
    
    // Get the error message string
    String errorMessage = error.toString().toLowerCase();
    
    // Authentication & JWT token errors
    if (errorMessage.contains('token not valid') ||
        errorMessage.contains('token_not_valid') ||
        errorMessage.contains('authentication credentials') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('401')) {
      return 'Your session has expired. Go to Profile → Sign Out and sign back in to continue.';
    }
    
    if (errorMessage.contains('forbidden') || 
        errorMessage.contains('403')) {
      return 'You don\'t have access to this feature. Make sure you are signed in with the right account or contact Support.';
    }
    
    if (errorMessage.contains('not found') || 
        errorMessage.contains('404')) {
      return 'This item could not be found. Pull down to refresh the list or update the app.';
    }

    if (errorMessage.contains('429') ||
        errorMessage.contains('too many requests') ||
        errorMessage.contains('throttled')) {
      return 'Too many requests too quickly. Wait 1 minute before trying again.';
    }
    
    // Server errors
    if (errorMessage.contains('500') || 
        errorMessage.contains('502') || 
        errorMessage.contains('503')) {
      return 'Our server is temporarily busy. Wait 30 seconds and pull down to refresh.';
    }
    
    // Connection & network errors (including http.ClientException wrapping SocketException)
    if (errorMessage.contains('socketexception') ||
        errorMessage.contains('failed host lookup') ||
        errorMessage.contains('network is unreachable') ||
        errorMessage.contains('no internet') ||
        errorMessage.contains('clientexception') ||
        errorMessage.contains('handshake') ||
        errorMessage.contains('connection refused') ||
        errorMessage.contains('connection reset') ||
        errorMessage.contains('connection closed') ||
        errorMessage.contains('software caused connection abort') ||
        errorMessage.contains('broken pipe') ||
        errorMessage.contains('unable to connect')) {
      return 'No internet connection. Turn on Wi-Fi or mobile data, then pull down to refresh.';
    }

    if (errorMessage.contains('connection') ||
        errorMessage.contains('network')) {
      return 'Connection problem. Switch between Wi-Fi and mobile data, then retry.';
    }

    // Timeout errors
    if (errorMessage.contains('timeout') ||
        errorMessage.contains('timed out')) {
      return 'The connection timed out. Switch to a stronger network or move to a better signal area, then retry.';
    }

    // Login & profile errors (preserve explicit user-friendly auth messages)
    if (errorMessage.contains('invalid email or password') ||
        errorMessage.contains('invalid credentials') ||
        errorMessage.contains('no active account')) {
      return 'Incorrect email or password. Double-check your spelling or tap "Forgot Password" to reset it.';
    }

    if (errorMessage.contains('failed to load profile') ||
        errorMessage.contains('unable to load your profile')) {
      return 'Unable to load your profile. Check your internet connection, or sign out and sign back in.';
    }
    
    // Payment/wallet errors
    if (errorMessage.contains('insufficient')) {
      return 'Insufficient wallet balance. Tap "Add Money" to top up your wallet first.';
    }
    
    if (errorMessage.contains('transaction') && 
        errorMessage.contains('failed')) {
      return 'Transaction could not be completed. Check your balance and internet connection, or contact Support.';
    }
    
    // File/upload errors
    if (errorMessage.contains('file') && 
        (errorMessage.contains('large') || errorMessage.contains('size'))) {
      return 'File is too large. Choose a smaller file (under 10 MB) and upload again.';
    }
    
    if (errorMessage.contains('upload')) {
      return 'Upload failed. Check your internet connection and re-select the file to upload.';
    }
    
    // Audio/media errors
    if (errorMessage.contains('audio') || 
        errorMessage.contains('media') || 
        errorMessage.contains('playback')) {
      return 'Unable to play this audio. Check your internet connection or download the sermon first for offline playback.';
    }
    
    // Email errors
    if (errorMessage.contains('email') && 
        errorMessage.contains('invalid')) {
      return 'Invalid email address. Check for typos or extra spaces and re-enter it.';
    }
    
    if (errorMessage.contains('email') && 
        errorMessage.contains('exists')) {
      return 'This email is already registered. Tap "Sign In" or use "Forgot Password" to recover your account.';
    }
    
    // Password errors
    if (errorMessage.contains('password') && 
        (errorMessage.contains('incorrect') || errorMessage.contains('wrong'))) {
      return 'Incorrect password. Check Caps Lock or tap "Forgot Password" to reset it.';
    }
    
    if (errorMessage.contains('password') && 
        errorMessage.contains('weak')) {
      return 'Password is too weak. Use at least 8 characters with letters and numbers.';
    }
    
    // Wing AI specific errors
    if (errorMessage.contains('wing ai') || 
        errorMessage.contains('ask wing')) {
      if (errorMessage.contains('unavailable') || 
          errorMessage.contains('disabled')) {
        return 'Wing AI is temporarily unavailable. Please check back in a few minutes.';
      }
      if (errorMessage.contains('limit') || 
          errorMessage.contains('quota')) {
        return 'You\'ve reached your daily question limit. Your quota resets tomorrow.';
      }
      return 'Unable to process your question right now. Shorten your question or check your internet connection.';
    }
    
    // Default fallback message
    return 'Something unexpected happened. Check your internet connection, pull down to refresh, or sign out and sign back in if it persists.';
  }
  
  /// Show error snackbar with user-friendly message
  static void showError(BuildContext context, dynamic error, {Duration? duration}) {
    final message = getErrorMessage(error);
    final messenger = _getMessenger(context);
    if (messenger == null) return;
    
    // Clear any previous or queued snackbars so they do not stack up
    messenger.clearSnackBars();
    
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 4),
        dismissDirection: DismissDirection.horizontal,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            // Instantly clear all snackbars without waiting for animations
            messenger.clearSnackBars();
          },
        ),
      ),
    );
  }
  
  /// Show success snackbar
  static void showSuccess(BuildContext context, String message, {Duration? duration}) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
  
  /// Show warning snackbar
  static void showWarning(BuildContext context, String message, {Duration? duration}) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
  
  /// Show info snackbar
  static void showInfo(BuildContext context, String message, {Duration? duration}) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
  
  /// Show error dialog for critical errors
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    final message = getErrorMessage(error);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Text(title ?? 'Error'),
          ],
        ),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Exception with timeout
class TimeoutException implements Exception {
  final String message;
  TimeoutException([this.message = 'Request timeout']);
  
  @override
  String toString() => message;
}
