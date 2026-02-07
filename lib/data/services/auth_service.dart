import 'dart:io';
import '../../core/constants/api_constants.dart';
import '../../domain/entities/user.dart';
import '../models/contact_message.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<AuthResult> login(String email, String password) async {
    final normalizedEmail = email.toLowerCase();
    final response = await _api.post(ApiConstants.login, {
      'email': normalizedEmail,
      'password': password,
    });

    if (response.isSuccess) {
      final data = response.data;
      await _api.saveTokens(data['access'], data['refresh']);
      return AuthResult(success: true);
    }
    
    String errorMessage = _parseErrorMessage(response);
    
    // Provide user-friendly messages for common status codes
    if (response.statusCode == 401) {
      errorMessage = 'Invalid email or password. Please try again.';
    } else if (response.statusCode == 0) {
      errorMessage = 'Unable to connect to server. Please check your internet connection.';
    }
    
    return AuthResult(success: false, error: errorMessage);
  }

  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    String? middleName,
    String? phoneNumber,
    String? countryCode,
  }) async {
    final normalizedEmail = email.toLowerCase();
    final response = await _api.post(ApiConstants.register, {
      'email': normalizedEmail,
      'username': username,
      'password': password,
      'password_confirm': password,
      'first_name': firstName,
      'last_name': lastName,
      if (middleName != null) 'middle_name': middleName,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (countryCode != null) 'country_code': countryCode,
    });

    if (response.isSuccess) {
      return AuthResult(
        success: true, 
        requiresEmailConfirmation: true,
        message: response.data['message'] ?? 'Please check your email to confirm your account.',
      );
    }
    
    String errorMessage = _parseErrorMessage(response);
    return AuthResult(success: false, error: errorMessage);
  }

  Future<AuthResult> resendConfirmationEmail(String email) async {
    final normalizedEmail = email.toLowerCase();
    final response = await _api.post(ApiConstants.resendConfirmation, {
      'email': normalizedEmail,
    });

    if (response.isSuccess) {
      return AuthResult(success: true, message: 'Confirmation email sent successfully');
    }
    
    String errorMessage = _parseErrorMessage(response);
    return AuthResult(success: false, error: errorMessage);
  }

  String _parseErrorMessage(ApiResponse response) {
    try {
      final data = response.data;
      
      // Handle detail message (common in DRF)
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }
      
      // Handle field-specific errors
      List<String> errors = [];
      data.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          String fieldName = _formatFieldName(key);
          errors.add('$fieldName: ${value.first}');
        } else if (value is String) {
          String fieldName = _formatFieldName(key);
          errors.add('$fieldName: $value');
        }
      });
      if (errors.isNotEmpty) {
        return errors.join('\n');
      }
      
      // Handle non_field_errors
      if (data.containsKey('non_field_errors')) {
        final nonFieldErrors = data['non_field_errors'];
        if (nonFieldErrors is List && nonFieldErrors.isNotEmpty) {
          return nonFieldErrors.first.toString();
        }
      }
      
      return response.errorMessage ?? 'An error occurred. Please try again.';
    } catch (e) {
      return response.errorMessage ?? 'An error occurred. Please try again.';
    }
  }

  String _formatFieldName(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1)}' 
            : '')
        .join(' ');
  }

  Future<void> logout() async {
    await _api.clearTokens();
  }

  Future<AppUser?> getProfile() async {
    final response = await _api.get(ApiConstants.userProfile);
    
    if (response.isSuccess) {
      try {
        final user = AppUser.fromJson(response.data);
        return user;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<AuthResult> updateProfile(Map<String, dynamic> data) async {
    final response = await _api.patch(ApiConstants.userProfile, data);
    
    if (response.isSuccess) {
      return AuthResult(success: true);
    }
    return AuthResult(
      success: false,
      error: _parseErrorMessage(response),
    );
  }

  Future<AuthResult> uploadProfilePhoto(File imageFile) async {
    final response = await _api.uploadFile(
      ApiConstants.userProfile,
      imageFile,
      fieldName: 'photo',
    );
    
    if (response.isSuccess) {
      return AuthResult(success: true);
    }
    return AuthResult(
      success: false,
      error: response.errorMessage ?? 'Failed to upload photo',
    );
  }

  Future<AuthResult> changePassword(String oldPassword, String newPassword) async {
    final response = await _api.put(ApiConstants.changePassword, {
      'old_password': oldPassword,
      'new_password': newPassword,
    });

    if (response.isSuccess) {
      return AuthResult(success: true);
    }
    return AuthResult(
      success: false,
      error: response.errorMessage ?? 'Password change failed',
    );
  }

  Future<AuthResult> forgotPassword(String email) async {
    final normalizedEmail = email.toLowerCase();
    final response = await _api.post(ApiConstants.forgotPassword, {
      'email': normalizedEmail,
    });

    if (response.isSuccess) {
      return AuthResult(success: true, message: response.data['message']);
    }
    return AuthResult(
      success: false,
      error: _parseErrorMessage(response),
    );
  }

  Future<AuthResult> sendContactMessage({
    required String email,
    required String subject,
    required String message,
    String? name,
    String? category,
  }) async {
    final response = await _api.post(ApiConstants.contact, {
      'email': email,
      'subject': subject,
      'message': message,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
    });

    if (response.isSuccess) {
      return AuthResult(success: true, message: response.data['message']);
    }
    return AuthResult(
      success: false,
      error: _parseErrorMessage(response),
    );
  }

  Future<List<ContactMessage>> getMyContactMessages() async {
    final response = await _api.get(ApiConstants.myContactMessages);
    
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => ContactMessage.fromJson(json)).toList();
    }
    return [];
  }

  Future<ContactMessage?> getContactMessageDetail(int id) async {
    final response = await _api.get('${ApiConstants.myContactMessageDetail}$id/');
    
    if (response.isSuccess) {
      return ContactMessage.fromJson(response.data);
    }
    return null;
  }

  bool get isAuthenticated => _api.isAuthenticated;

  Future<void> loadSession() async {
    await _api.loadTokens();
  }
}

class AuthResult {
  final bool success;
  final String? error;
  final String? message;
  final bool requiresEmailConfirmation;

  AuthResult({
    required this.success, 
    this.error, 
    this.message,
    this.requiresEmailConfirmation = false,
  });
}
