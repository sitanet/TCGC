import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/services/auth_service.dart';
import '../../domain/entities/user.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  String? _message;
  bool _isInitialized = false;
  bool _requiresEmailConfirmation = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get message => _message;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;
  bool get requiresEmailConfirmation => _requiresEmailConfirmation;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();
    
    await _authService.loadSession();
    
    if (_authService.isAuthenticated) {
      _user = await _authService.getProfile();
    }
    
    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.login(email, password);
    
    if (result.success) {
      _user = await _authService.getProfile();
      _isLoading = false;
      
      if (_user == null) {
        _error = 'Failed to load profile. Please try again.';
        notifyListeners();
        return false;
      }
      
      notifyListeners();
      return true;
    }
    
    _error = result.error;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    String? middleName,
    String? phoneNumber,
    String? countryCode,
  }) async {
    _isLoading = true;
    _error = null;
    _message = null;
    _requiresEmailConfirmation = false;
    notifyListeners();

    final result = await _authService.register(
      email: email,
      username: username,
      password: password,
      firstName: firstName,
      lastName: lastName,
      middleName: middleName,
      phoneNumber: phoneNumber,
      countryCode: countryCode,
    );
    
    if (result.success) {
      _requiresEmailConfirmation = result.requiresEmailConfirmation;
      _message = result.message;
      _isLoading = false;
      notifyListeners();
      return true;
    }
    
    _error = result.error;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> resendConfirmationEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.resendConfirmationEmail(email);
    
    _isLoading = false;
    if (result.success) {
      _message = result.message;
    } else {
      _error = result.error;
    }
    notifyListeners();
    return result.success;
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.updateProfile(data);
    
    if (result.success) {
      _user = await _authService.getProfile();
      _isLoading = false;
      notifyListeners();
      return true;
    }
    
    _error = result.error;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> uploadProfilePhoto(File imageFile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.uploadProfilePhoto(imageFile);
    
    if (result.success) {
      _user = await _authService.getProfile();
      _isLoading = false;
      notifyListeners();
      return true;
    }
    
    _error = result.error;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.changePassword(oldPassword, newPassword);
    
    _isLoading = false;
    if (!result.success) {
      _error = result.error;
    }
    notifyListeners();
    return result.success;
  }

  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _error = null;
    _message = null;
    notifyListeners();

    final result = await _authService.forgotPassword(email);
    
    _isLoading = false;
    if (result.success) {
      _message = result.message;
    } else {
      _error = result.error;
    }
    notifyListeners();
    return result.success;
  }

  Future<bool> sendContactMessage({
    required String email,
    required String subject,
    required String message,
    String? name,
    String? category,
  }) async {
    _isLoading = true;
    _error = null;
    _message = null;
    notifyListeners();

    final result = await _authService.sendContactMessage(
      email: email,
      subject: subject,
      message: message,
      name: name,
      category: category,
    );
    
    _isLoading = false;
    if (result.success) {
      _message = result.message;
    } else {
      _error = result.error;
    }
    notifyListeners();
    return result.success;
  }

  // Get user's contact messages
  Future<List<dynamic>> getMyContactMessages() async {
    return await _authService.getMyContactMessages();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
