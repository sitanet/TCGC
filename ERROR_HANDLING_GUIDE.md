# Error Handling Guide

## Overview
This app uses a centralized error handling system that converts technical errors into user-friendly messages at multiple levels:
1. **API Level** - ApiResponse automatically converts status codes
2. **UI Level** - ErrorHandler provides display methods
3. **Exception Level** - Automatic exception translation

## Automatic API Error Handling

**Every API response now includes user-friendly error messages automatically!**

### Using ApiResponse.userFriendlyError

```dart
final response = await _apiService.get('/endpoint');

if (!response.isSuccess) {
  // Automatically get user-friendly message
  ErrorHandler.showError(context, response.userFriendlyError);
  return;
}

// Success - use the data
final data = response.data;
```

### Status Code Translation (Automatic)

The ApiResponse class automatically converts:
- `0` → "No internet connection. Please check your network and try again."
- `401` → "Session expired. Please login again."
- `403` → "You don't have permission to access this."
- `404` → "The requested content was not found."
- `500+` → "Server is experiencing issues. Please try again later."

## Import
```dart
import '../../../core/utils/error_handler.dart';
```

## Usage Examples

### 1. API Call with User-Friendly Errors (Recommended Pattern)
```dart
Future<void> _fetchData() async {
  setState(() => _isLoading = true);
  
  try {
    final response = await _apiService.get('/data');
    
    if (!response.isSuccess) {
      // Automatically shows user-friendly error message
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(context, response.userFriendlyError);
      }
      return;
    }
    
    // Success
    final data = response.data;
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  } catch (e) {
    // Catch network/exception errors
    if (mounted) {
      setState(() => _isLoading = false);
      ErrorHandler.showError(context, e);
    }
  }
}
```

### 2. Basic Error Handling with Snackbar
```dart
try {
  // Your code that might throw an error
  await someApiCall();
} catch (e) {
  // Show user-friendly error message
  ErrorHandler.showError(context, e);
}
```

### 2. Error Handling with Custom Duration
```dart
try {
  await someOperation();
} catch (e) {
  ErrorHandler.showError(
    context, 
    e,
    duration: const Duration(seconds: 5),
  );
}
```

### 3. Show Success Message
```dart
try {
  await saveData();
  // Show success message
  ErrorHandler.showSuccess(context, 'Data saved successfully!');
} catch (e) {
  ErrorHandler.showError(context, e);
}
```

### 4. Show Warning Message
```dart
if (balance < amount) {
  ErrorHandler.showWarning(
    context,
    'Insufficient balance. Please add money to continue.',
  );
  return;
}
```

### 5. Show Info Message
```dart
ErrorHandler.showInfo(
  context,
  'This feature is coming soon!',
);
```

### 6. Critical Errors with Dialog and Retry
```dart
try {
  await criticalOperation();
} catch (e) {
  await ErrorHandler.showErrorDialog(
    context,
    e,
    title: 'Payment Failed',
    onRetry: () {
      // Retry the operation
      _processPayment();
    },
  );
}
```

### 7. Get Error Message Without Showing UI
```dart
try {
  await operation();
} catch (e) {
  String friendlyMessage = ErrorHandler.getErrorMessage(e);
  // Use the message however you want
  print(friendlyMessage);
}
```

## Error Types Handled

### Network Errors
- `SocketException` → "No internet connection. Please check your network and try again."
- `HttpException` → "Unable to connect to server. Please try again later."
- `TimeoutException` → "Connection timeout. Please check your internet and try again."

### HTTP Status Codes
- `401 Unauthorized` → "Session expired. Please login again."
- `403 Forbidden` → "You don't have permission to access this."
- `404 Not Found` → "The requested content was not found."
- `500/502/503` → "Server is experiencing issues. Please try again later."

### Payment/Wallet Errors
- `insufficient` → "Insufficient balance. Please add money to your wallet."
- `transaction failed` → "Transaction failed. Please try again or contact support."

### File/Upload Errors
- `file too large` → "File is too large. Please choose a smaller file."
- `upload failed` → "Upload failed. Please check your connection and try again."

### Authentication Errors
- `invalid email` → "Invalid email address. Please check and try again."
- `email exists` → "This email is already registered. Please login or use another email."
- `incorrect password` → "Incorrect password. Please try again."

### Media Errors
- `audio/media/playback` → "Unable to play media. Please try again."

## Best Practices

### ❌ DON'T Do This
```dart
try {
  await apiCall();
} catch (e) {
  // Bad: Showing technical error to user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

### ✅ DO This
```dart
try {
  await apiCall();
} catch (e) {
  // Good: Using error handler
  ErrorHandler.showError(context, e);
}
```

### ✅ Success + Error Pattern
```dart
Future<void> _submitForm() async {
  setState(() => _isLoading = true);
  
  try {
    await _apiService.submitData(data);
    
    if (mounted) {
      setState(() => _isLoading = false);
      ErrorHandler.showSuccess(context, 'Form submitted successfully!');
      Navigator.pop(context);
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      ErrorHandler.showError(context, e);
    }
  }
}
```

### ✅ Validation + API Call
```dart
Future<void> _makePayment() async {
  // Validate first
  if (_amount <= 0) {
    ErrorHandler.showWarning(context, 'Please enter a valid amount');
    return;
  }
  
  if (_wallet.balance < _amount) {
    ErrorHandler.showWarning(
      context,
      'Insufficient balance. Please add money to your wallet.',
    );
    return;
  }
  
  // Then make API call
  try {
    setState(() => _isProcessing = true);
    await _paymentService.processPayment(_amount);
    
    if (mounted) {
      setState(() => _isProcessing = false);
      ErrorHandler.showSuccess(context, 'Payment successful!');
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isProcessing = false);
      ErrorHandler.showError(context, e);
    }
  }
}
```

## Customization

### Adding New Error Patterns
Edit `lib/core/utils/error_handler.dart` and add to `getErrorMessage()`:

```dart
// Custom app-specific error
if (errorMessage.contains('your_custom_error')) {
  return 'Your user-friendly message here';
}
```

### Custom Error Messages
For specific operations, you can override with custom messages:

```dart
try {
  await specificOperation();
  ErrorHandler.showSuccess(context, 'Operation completed!');
} catch (e) {
  // Custom message for this specific case
  if (e.toString().contains('specific_condition')) {
    ErrorHandler.showError(context, 'Custom message for this case');
  } else {
    // Fall back to automatic handling
    ErrorHandler.showError(context, e);
  }
}
```

## Migration Checklist

To migrate existing error handling:

1. ✅ Import `ErrorHandler`
2. ✅ Replace `ScaffoldMessenger.of(context).showSnackBar(...)` with `ErrorHandler.showError/showSuccess/showWarning/showInfo`
3. ✅ Remove manual error message formatting
4. ✅ Test error scenarios

## Notes

- Always use `if (mounted)` before showing errors in async functions
- Use `showError` for errors
- Use `showSuccess` for success messages
- Use `showWarning` for validation failures
- Use `showInfo` for informational messages
- Use `showErrorDialog` for critical errors that need user attention
