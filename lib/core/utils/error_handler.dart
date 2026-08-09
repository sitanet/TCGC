import 'package:flutter/material.dart';
import 'dart:io';

/// Global error handler that converts technical errors to user-friendly messages
class ErrorHandler {
  /// Convert exception to user-friendly message
  static String getErrorMessage(dynamic error) {
    if (error == null) return 'Something went wrong. Please try again.';

    // Network errors
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }
    
    if (error is HttpException) {
      return 'Unable to connect to server. Please try again later.';
    }
    
    if (error is HandshakeException) {
      return 'Secure connection failed. Please check your internet connection.';
    }
    
    if (error is TimeoutException) {
      return 'Connection timeout. Please check your internet and try again.';
    }
    
    // Format exception (JSON parsing errors)
    if (error is FormatException) {
      return 'Unable to process data. Please try again.';
    }
    
    // Get the error message string
    String errorMessage = error.toString().toLowerCase();
    
    // Authentication errors
    if (errorMessage.contains('unauthorized') || 
        errorMessage.contains('401')) {
      return 'Session expired. Please login again.';
    }
    
    if (errorMessage.contains('forbidden') || 
        errorMessage.contains('403')) {
      return 'You don\'t have permission to access this.';
    }
    
    if (errorMessage.contains('not found') || 
        errorMessage.contains('404')) {
      return 'The requested content was not found.';
    }
    
    // Server errors
    if (errorMessage.contains('500') || 
        errorMessage.contains('502') || 
        errorMessage.contains('503')) {
      return 'Server is experiencing issues. Please try again later.';
    }
    
    // Connection errors
    if (errorMessage.contains('connection') || 
        errorMessage.contains('network')) {
      return 'Connection problem. Please check your internet and try again.';
    }
    
    // Timeout errors
    if (errorMessage.contains('timeout') || 
        errorMessage.contains('timed out')) {
      return 'Request took too long. Please try again.';
    }
    
    // Payment/wallet errors
    if (errorMessage.contains('insufficient')) {
      return 'Insufficient balance. Please add money to your wallet.';
    }
    
    if (errorMessage.contains('transaction') && 
        errorMessage.contains('failed')) {
      return 'Transaction failed. Please try again or contact support.';
    }
    
    // File/upload errors
    if (errorMessage.contains('file') && 
        (errorMessage.contains('large') || errorMessage.contains('size'))) {
      return 'File is too large. Please choose a smaller file.';
    }
    
    if (errorMessage.contains('upload')) {
      return 'Upload failed. Please check your connection and try again.';
    }
    
    // Audio/media errors
    if (errorMessage.contains('audio') || 
        errorMessage.contains('media') || 
        errorMessage.contains('playback')) {
      return 'Unable to play media. Please try again.';
    }
    
    // Email errors
    if (errorMessage.contains('email') && 
        errorMessage.contains('invalid')) {
      return 'Invalid email address. Please check and try again.';
    }
    
    if (errorMessage.contains('email') && 
        errorMessage.contains('exists')) {
      return 'This email is already registered. Please login or use another email.';
    }
    
    // Password errors
    if (errorMessage.contains('password') && 
        (errorMessage.contains('incorrect') || errorMessage.contains('wrong'))) {
      return 'Incorrect password. Please try again.';
    }
    
    if (errorMessage.contains('password') && 
        errorMessage.contains('weak')) {
      return 'Password is too weak. Please use a stronger password.';
    }
    
    // Wing AI specific errors
    if (errorMessage.contains('wing ai') || 
        errorMessage.contains('ask wing')) {
      if (errorMessage.contains('unavailable') || 
          errorMessage.contains('disabled')) {
        return 'Wing AI is currently unavailable. Please try again later.';
      }
      if (errorMessage.contains('limit') || 
          errorMessage.contains('quota')) {
        return 'You\'ve reached your daily question limit. Please try again tomorrow.';
      }
      return 'Unable to process your question right now. Please try again.';
    }
    
    // Default fallback message
    return 'Something went wrong. Please try again.';
  }
  
  /// Show error snackbar with user-friendly message
  static void showError(BuildContext context, dynamic error, {Duration? duration}) {
    final message = getErrorMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Show success snackbar
  static void showSuccess(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
  
  /// Show warning snackbar
  static void showWarning(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
  
  /// Show info snackbar
  static void showInfo(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
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
