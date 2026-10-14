import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/entities/user.dart';
import '../models/contact_message.dart';
import 'api_service.dart';
import 'audio_cache_service.dart';
import 'local_database_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  static const String _pendingVerificationEmailKey = 'pending_verification_email';

  Future<void> savePendingVerificationEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingVerificationEmailKey, email.trim().toLowerCase());
    } catch (e) {
      debugPrint('Failed to save pending verification email: $e');
    }
  }

  Future<String?> getPendingVerificationEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_pendingVerificationEmailKey);
      if (email != null && email.trim().isNotEmpty) {
        return email.trim().toLowerCase();
      }
    } catch (e) {
      debugPrint('Failed to get pending verification email: $e');
    }
    return null;
  }

  Future<void> clearPendingVerificationEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingVerificationEmailKey);
    } catch (e) {
      debugPrint('Failed to clear pending verification email: $e');
    }
  }

  Future<bool> checkEmailVerification(String email) async {
    final normalizedEmail = email.toLowerCase().trim();
    try {
      final response = await _api.postPublic(ApiConstants.checkEmailVerification, {
        'email': normalizedEmail,
      });

      if (response.isSuccess && response.data is Map) {
        final isVerified = response.data['email_verified'] == true;
        if (isVerified) {
          await clearPendingVerificationEmail();
        }
        return isVerified;
      }
    } catch (e) {
      debugPrint('Check email verification error: $e');
    }
    return false;
  }

  Future<AuthResult> login(String email, String password) async {
    final normalizedEmail = email.toLowerCase().trim();
    // Use postPublic to avoid sending expired tokens with login request
    final response = await _api.postPublic(ApiConstants.login, {
      'email': normalizedEmail,
      'password': password,
    });

    // Debug: temporarily enabled to diagnose login issue
    print('Login API response: ${response.statusCode} - ${response.body}');

    if (response.isSuccess) {
      final data = response.data;
      await _api.saveTokens(data['access'], data['refresh']);
      await clearPendingVerificationEmail();
      return AuthResult(success: true, email: normalizedEmail);
    }

    // Check if email is not verified (status 403 or email_not_verified flag)
    if (response.statusCode == 403 ||
        (response.data is Map && response.data['email_not_verified'] == true)) {
      await savePendingVerificationEmail(normalizedEmail);
      final detail = response.data is Map && response.data['detail'] != null
          ? response.data['detail'].toString()
          : 'Please confirm your email address before logging in.';
      return AuthResult(
        success: false,
        requiresEmailConfirmation: true,
        email: normalizedEmail,
        error: detail,
      );
    }

    String errorMessage = _parseErrorMessage(response);

    // Provide user-friendly messages for common status codes
    if (response.statusCode == 401) {
      errorMessage = 'Invalid email or password. Please try again.';
    } else if (response.statusCode == 0) {
      errorMessage =
          'Unable to connect to server. Please check your internet connection.';
    }

    return AuthResult(success: false, error: errorMessage, email: normalizedEmail);
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
    final normalizedEmail = email.toLowerCase().trim();
    print('Register API: Starting registration for $normalizedEmail');

    // Use postPublic for registration (public endpoint)
    final response = await _api.postPublic(ApiConstants.register, {
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

    print('Register API response: ${response.statusCode} - ${response.body}');

    if (response.isSuccess) {
      print(
        'Register API: Success, saving pending email and returning with requiresEmailConfirmation=true',
      );
      await savePendingVerificationEmail(normalizedEmail);
      return AuthResult(
        success: true,
        requiresEmailConfirmation: true,
        email: normalizedEmail,
        message:
            response.data['message'] ??
            'Please check your email to confirm your account.',
      );
    }

    String errorMessage = _parseErrorMessage(response);
    print('Register API: Failed with error: $errorMessage');
    return AuthResult(success: false, error: errorMessage, email: normalizedEmail);
  }

  Future<AuthResult> resendConfirmationEmail(String email) async {
    final normalizedEmail = email.toLowerCase().trim();
    // Use postPublic for public endpoint
    final response = await _api.postPublic(ApiConstants.resendConfirmation, {
      'email': normalizedEmail,
    });

    if (response.isSuccess) {
      return AuthResult(
        success: true,
        email: normalizedEmail,
        message: 'Confirmation email sent successfully',
      );
    }

    String errorMessage = _parseErrorMessage(response);
    if (errorMessage.toLowerCase().contains('already verified')) {
      await clearPendingVerificationEmail();
      return AuthResult(
        success: true,
        email: normalizedEmail,
        message: 'Your email is already verified! You can now log in.',
      );
    }
    return AuthResult(success: false, error: errorMessage, email: normalizedEmail);
  }

  String _parseErrorMessage(ApiResponse response) {
    try {
      // Debug: temporarily enabled to diagnose login issue
      print('Error response: ${response.statusCode} - ${response.body}');
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

      // Use user-friendly error message (includes ErrorHandler conversion)
      return response.userFriendlyError;
    } catch (e) {
      // Fallback to user-friendly error message
      return response.userFriendlyError;
    }
  }

  String _formatFieldName(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  Future<void> logout() async {
    await _api.clearTokens();
    await clearCachedProfile();
    await clearPendingVerificationEmail();
  }

  Future<AuthResult> deleteAccount() async {
    final response = await _api.delete(ApiConstants.deleteAccount);

    if (response.isSuccess) {
      await _api.clearTokens();
      await clearCachedProfile();
      await clearPendingVerificationEmail();
      try {
        await AudioCacheService().clearAllCache();
        await LocalDatabaseService().clearAllData();
      } catch (e) {
        debugPrint('Cache clear on account deletion error: $e');
      }
      return AuthResult(success: true, message: 'Account deleted successfully');
    }

    String errorMessage = _parseErrorMessage(response);
    return AuthResult(success: false, error: errorMessage);
  }

  static const String _cachedProfileKey = 'cached_user_profile';

  Future<AppUser?> getProfile() async {
    final response = await _api.get(ApiConstants.userProfile);

    if (response.isSuccess) {
      try {
        final user = AppUser.fromJson(response.data);
        // Cache the profile locally for offline login
        await _cacheProfile(response.data);
        return user;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Load user profile from local cache (no network needed)
  Future<AppUser?> getCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_cachedProfileKey);
      if (profileJson != null) {
        final data = jsonDecode(profileJson) as Map<String, dynamic>;
        return AppUser.fromJson(data);
      }
    } catch (e) {
      debugPrint('Failed to load cached profile: $e');
    }
    return null;
  }

  /// Save user profile to local storage
  Future<void> _cacheProfile(Map<String, dynamic> profileData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedProfileKey, jsonEncode(profileData));
    } catch (e) {
      debugPrint('Failed to cache profile: $e');
    }
  }

  /// Clear cached profile (call on logout)
  Future<void> clearCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedProfileKey);
    } catch (e) {
      debugPrint('Failed to clear cached profile: $e');
    }
  }

  Future<AuthResult> updateProfile(Map<String, dynamic> data) async {
    final response = await _api.patch(ApiConstants.userProfile, data);

    if (response.isSuccess) {
      return AuthResult(success: true);
    }
    return AuthResult(success: false, error: _parseErrorMessage(response));
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

  Future<AuthResult> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
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

  Future<AuthResult> verifyPassword(String password) async {
    final response = await _api.post(ApiConstants.verifyPassword, {
      'password': password,
    });

    if (response.isSuccess) {
      return AuthResult(success: true);
    }
    return AuthResult(
      success: false,
      error: response.errorMessage ?? 'Invalid password',
    );
  }

  Future<AuthResult> forgotPassword(String email) async {
    final normalizedEmail = email.toLowerCase();
    // Use postPublic for public endpoint
    final response = await _api.postPublic(ApiConstants.forgotPassword, {
      'email': normalizedEmail,
    });

    if (response.isSuccess) {
      return AuthResult(success: true, message: response.data['message']);
    }
    return AuthResult(success: false, error: _parseErrorMessage(response));
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
    return AuthResult(success: false, error: _parseErrorMessage(response));
  }

  Future<List<ContactMessage>> getMyContactMessages() async {
    final response = await _api.get(ApiConstants.myContactMessages);

    if (response.isSuccess) {
      final data = response.data;
      // Handle both paginated and non-paginated responses
      final List<dynamic> results = data is List
          ? data
          : (data['results'] ?? data);
      return results.map((json) => ContactMessage.fromJson(json)).toList();
    }
    return [];
  }

  Future<ContactMessage?> getContactMessageDetail(int id) async {
    final response = await _api.get(
      '${ApiConstants.myContactMessageDetail}$id/',
    );

    if (response.isSuccess) {
      return ContactMessage.fromJson(response.data);
    }
    return null;
  }

  Future<bool> replyToContactMessage(int id, String message) async {
    final response = await _api.post(
      '${ApiConstants.myContactMessageDetail}$id/reply/',
      {'message': message},
    );

    return response.isSuccess;
  }

  bool get isAuthenticated => _api.isAuthenticated;

  Future<void> loadSession() async {
    await _api.loadTokens();
  }

  // KYC Verification Methods
  Future<KycResult> verifyNin(
    String nin, {
    String? phoneNumber,
    String? address,
    String? dateOfBirth,
    bool updateProfile = false,
  }) async {
    // Use secure endpoint for new two-step flow
    final response = await _api.post(ApiConstants.secureVerifyNin, {
      'nin': nin,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (address != null) 'address': address,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
    });

    debugPrint('[AUTH] verifyNin response status: ${response.statusCode}');
    debugPrint('[AUTH] verifyNin response isSuccess: ${response.isSuccess}');
    debugPrint('[AUTH] verifyNin response data: ${response.data}');

    if (response.isSuccess) {
      return KycResult(
        success: true,
        message: response.data['message'],
        confirmationToken: response.data['confirmation_token'],
        maskedIdentity: response.data['masked_identity'],
        status: response.data['status'],
      );
    }
    return KycResult(
      success: false,
      error: response.data?['error'] ?? _parseErrorMessage(response),
      errorCode: response.data?['error_code'],
      mismatches: List<String>.from(response.data?['mismatches'] ?? []),
      verifiedData: response.data?['data'],
    );
  }

  Future<KycResult> confirmIdentity({
    required String confirmationToken,
    bool confirmed = true,
  }) async {
    final response = await _api.post(ApiConstants.confirmIdentity, {
      'confirmation_token': confirmationToken,
      'confirmed': confirmed,
    });

    if (response.isSuccess) {
      return KycResult(
        success: true,
        message: response.data['message'],
        walletData: response.data['wallet'],
      );
    }
    return KycResult(
      success: false,
      error: response.data?['error'] ?? _parseErrorMessage(response),
      errorCode: response.data?['error_code'],
    );
  }

  Future<KycResult> verifyBvn(String bvn, {bool updateProfile = false}) async {
    final response = await _api.post(ApiConstants.verifyBvn, {
      'bvn': bvn,
      'update_profile': updateProfile,
    });

    if (response.isSuccess) {
      return KycResult(
        success: true,
        message: response.data['message'],
        verifiedData: response.data['data'],
      );
    }
    return KycResult(
      success: false,
      error: response.data?['error'] ?? _parseErrorMessage(response),
    );
  }

  Future<KycResult> validateIdentity({String? nin, String? bvn}) async {
    final response = await _api.post(ApiConstants.validateIdentity, {
      if (nin != null) 'nin': nin,
      if (bvn != null) 'bvn': bvn,
    });

    if (response.isSuccess) {
      return KycResult(
        success: true,
        message: response.data['message'],
        ninVerified: response.data['nin_verified'] ?? false,
        bvnVerified: response.data['bvn_verified'] ?? false,
        mismatches: List<String>.from(response.data['mismatches'] ?? []),
      );
    }
    return KycResult(
      success: false,
      error: response.data?['error'] ?? _parseErrorMessage(response),
      ninError: response.data?['nin_error'],
      bvnError: response.data?['bvn_error'],
    );
  }
}

class AuthResult {
  final bool success;
  final String? error;
  final String? message;
  final bool requiresEmailConfirmation;
  final String? email;

  AuthResult({
    required this.success,
    this.error,
    this.message,
    this.requiresEmailConfirmation = false,
    this.email,
  });
}

class KycResult {
  final bool success;
  final String? error;
  final String? errorCode;
  final String? message;
  final Map<String, dynamic>? verifiedData;
  final Map<String, dynamic>? walletData;
  final bool ninVerified;
  final bool bvnVerified;
  final List<String> mismatches;
  final String? ninError;
  final String? bvnError;
  // New fields for secure two-step flow
  final String? confirmationToken;
  final Map<String, dynamic>? maskedIdentity;
  final String? status;

  KycResult({
    required this.success,
    this.error,
    this.errorCode,
    this.message,
    this.verifiedData,
    this.walletData,
    this.ninVerified = false,
    this.bvnVerified = false,
    this.mismatches = const [],
    this.ninError,
    this.bvnError,
    this.confirmationToken,
    this.maskedIdentity,
    this.status,
  });
}
