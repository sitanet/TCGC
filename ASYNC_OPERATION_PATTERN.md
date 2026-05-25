# Async Operation Pattern - Best Practice Guide

## Overview
This document outlines the correct pattern for handling async operations in Flutter to prevent UI freezing and ensure proper error handling.

## The Problem

### ❌ WRONG - Missing Try-Catch
```dart
Future<void> _performAsyncOperation() async {
    setState(() => _isLoading = true);
    
    // ❌ No exception handling!
    final result = await someAsyncCall();
    
    setState(() => _isLoading = false);
    
    if (result.success) {
        // Handle success
    } else {
        // Handle error
    }
}

// If someAsyncCall() throws an exception:
// - setState(() => _isLoading = false) is NEVER called
// - Loading spinner stays visible forever
// - UI appears frozen
```

### ❌ WRONG - Early Returns Without Loading State Reset
```dart
Future<void> _verifyNin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;  // ❌ No loading state set yet
    
    if (_phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(...);
        return;  // ❌ Returns without resetting _isVerifying
    }
    
    setState(() => _isVerifying = true);  // Only set AFTER validations
    
    final result = await authProvider.verifyNin(...);
    
    setState(() => _isVerifying = false);
}
```

## The Solution

### ✅ CORRECT - Proper Try-Catch Pattern
```dart
Future<void> _performAsyncOperation() async {
    // 1. Set loading state
    setState(() => _isLoading = true);
    
    try {
        // 2. Perform async operation
        final result = await someAsyncCall();
        
        // 3. Reset loading state immediately after operation
        setState(() => _isLoading = false);
        
        // 4. Handle result
        if (result.success) {
            // Success handling
            _showSuccessMessage();
        } else {
            // Error handling
            _showErrorMessage(result.error);
        }
    } catch (e) {
        // 5. ✅ CRITICAL: Reset loading state in catch block
        setState(() => _isLoading = false);
        
        // 6. Show error to user
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('An error occurred: ${e.toString()}'),
                    backgroundColor: AppColors.error,
                    duration: const Duration(seconds: 4),
                ),
            );
        }
    }
}
```

## Real-World Examples

### Example 1: NIN Verification (From nin_verification_page.dart)

```dart
Future<void> _verifyNin() async {
    // Validate form first
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    // Validate required fields
    if (_phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Phone number is required'),
                backgroundColor: AppColors.error,
            ),
        );
        return;
    }
    
    // Set loading state
    setState(() => _isVerifying = true);
    
    try {
        // Perform verification
        final authProvider = ref.read(authChangeNotifierProvider);
        final result = await authProvider.verifyNin(
            _ninController.text,
            phoneNumber: _phoneController.text,
            address: _addressController.text,
            dateOfBirth: _selectedDateOfBirth!.toIso8601String().split('T').first,
            updateProfile: true,
        );
        
        // Reset loading state
        setState(() => _isVerifying = false);
        
        if (!mounted) return;
        
        // Handle success
        if (result.success) {
            final walletProvider = ref.read(walletChangeNotifierProvider);
            await walletProvider.fetchWallet();
            
            // Show success dialog
            await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                    // ... success dialog content
                ),
            );
            
            // Navigate to next page
            if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const GivePage()),
                    (route) => route.isFirst,
                );
            }
        } else {
            // Handle error
            final errorCode = result.errorCode ?? '';
            final mismatches = result.mismatches;
            
            if (errorCode == 'NIN_MISMATCH' && mismatches.isNotEmpty) {
                // Show mismatch dialog
                await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                        // ... mismatch dialog content
                    ),
                );
            } else {
                // Show generic error
                if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                result.error ?? 'NIN verification failed. Please try again.',
                            ),
                            backgroundColor: AppColors.error,
                            duration: const Duration(seconds: 4),
                        ),
                    );
                }
            }
        }
    } catch (e) {
        // ✅ Ensure loading state is reset even if an exception occurs
        setState(() => _isVerifying = false);
        
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('An error occurred: ${e.toString()}'),
                    backgroundColor: AppColors.error,
                    duration: const Duration(seconds: 4),
                ),
            );
        }
    }
}
```

### Example 2: PIN Reset (From reset_pin_page.dart)

```dart
Future<void> _resetPin() async {
    // Validate form
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    // Set loading state
    setState(() => _isLoading = true);
    
    try {
        // Perform PIN reset
        final walletProvider = ref.read(walletChangeNotifierProvider);
        final success = await walletProvider.resetTransactionPin(
            _passwordController.text,
            _newPinController.text,
            _confirmPinController.text,
        );
        
        if (!mounted) return;
        
        // Reset loading state
        setState(() => _isLoading = false);
        
        // Handle result
        if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Transaction PIN reset successfully'),
                    backgroundColor: Colors.green,
                ),
            );
            Navigator.pop(context, true);
        } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(walletProvider.error ?? 'Failed to reset PIN'),
                    backgroundColor: Colors.red,
                ),
            );
        }
    } catch (e) {
        // ✅ Reset loading state on exception
        setState(() => _isLoading = false);
        
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('An error occurred: ${e.toString()}'),
                    backgroundColor: Colors.red,
                ),
            );
        }
    }
}
```

### Example 3: PIN Change (From change_pin_page.dart)

```dart
void _changePin() async {
    // Validate form
    if (_formKey.currentState!.validate()) {
        // Set loading state
        setState(() => _isLoading = true);
        
        try {
            // Perform PIN change
            final walletProvider = ref.read(walletChangeNotifierProvider);
            final success = await walletProvider.changeTransactionPin(
                _currentPinController.text,
                _newPinController.text,
                _confirmPinController.text,
            );
            
            if (!mounted) return;
            
            // Reset loading state
            setState(() => _isLoading = false);
            
            // Handle result
            if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Transaction PIN changed successfully'),
                        backgroundColor: Colors.green,
                    ),
                );
                Navigator.pop(context);
            } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(walletProvider.error ?? 'Failed to change PIN'),
                        backgroundColor: Colors.red,
                    ),
                );
            }
        } catch (e) {
            // ✅ Reset loading state on exception
            setState(() => _isLoading = false);
            
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('An error occurred: ${e.toString()}'),
                        backgroundColor: Colors.red,
                    ),
                );
            }
        }
    }
}
```

## Key Points

### 1. Always Use Try-Catch
```dart
try {
    final result = await asyncOperation();
    // Handle success
} catch (e) {
    // Handle error
}
```

### 2. Reset Loading State in Both Paths
```dart
try {
    setState(() => _isLoading = false);  // Success path
} catch (e) {
    setState(() => _isLoading = false);  // Error path
}
```

### 3. Check Mounted Before UI Operations
```dart
if (!mounted) return;

setState(() => _isLoading = false);
ScaffoldMessenger.of(context).showSnackBar(...);
```

### 4. Provide User Feedback
```dart
catch (e) {
    setState(() => _isLoading = false);
    
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('An error occurred: ${e.toString()}'),
                backgroundColor: AppColors.error,
            ),
        );
    }
}
```

## Common Mistakes to Avoid

### ❌ Mistake 1: Forgetting Try-Catch
```dart
// DON'T DO THIS
setState(() => _isLoading = true);
final result = await asyncCall();  // No exception handling
setState(() => _isLoading = false);
```

### ❌ Mistake 2: Not Resetting in Catch Block
```dart
// DON'T DO THIS
try {
    final result = await asyncCall();
    setState(() => _isLoading = false);
} catch (e) {
    // ❌ Forgot to reset _isLoading!
    print(e);
}
```

### ❌ Mistake 3: Not Checking Mounted
```dart
// DON'T DO THIS
catch (e) {
    setState(() => _isLoading = false);  // ❌ Might crash if widget disposed
    ScaffoldMessenger.of(context).showSnackBar(...);
}
```

### ❌ Mistake 4: Early Returns Without Cleanup
```dart
// DON'T DO THIS
Future<void> _operation() async {
    if (!isValid) return;  // ❌ Returns before setting loading state
    
    setState(() => _isLoading = true);
    // ...
}
```

## Checklist for Async Operations

- [ ] Set loading state before async call
- [ ] Wrap async call in try-catch
- [ ] Reset loading state in try block (after operation)
- [ ] Reset loading state in catch block
- [ ] Check `mounted` before UI operations
- [ ] Provide user feedback on error
- [ ] Handle both success and error cases
- [ ] Test with network errors
- [ ] Test with invalid inputs
- [ ] Test with timeout scenarios

## Summary

**The Golden Rule**: 
> For every `setState(() => _isLoading = true)`, there must be a corresponding `setState(() => _isLoading = false)` in BOTH the success path AND the error path.

This ensures the UI never gets stuck in a loading state.
