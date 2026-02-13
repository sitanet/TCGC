import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _keyBiometricLoginEnabled = 'biometric_login_enabled';
  static const String _keyBiometricTransactionEnabled = 'biometric_transaction_enabled';
  static const String _keySavedEmail = 'biometric_saved_email';
  static const String _keySavedPassword = 'biometric_saved_password';

  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric availability check failed: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Failed to get available biometrics: $e');
      return [];
    }
  }

  Future<bool> authenticate({String reason = 'Please authenticate to continue'}) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Authentication failed: $e');
      return false;
    }
  }

  Future<bool> authenticateForTransaction() async {
    return authenticate(reason: 'Authenticate to confirm transaction');
  }

  Future<bool> authenticateForLogin() async {
    return authenticate(reason: 'Authenticate to sign in');
  }

  // Settings management
  Future<bool> isBiometricLoginEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricLoginEnabled) ?? false;
  }

  Future<void> setBiometricLoginEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricLoginEnabled, enabled);
    if (!enabled) {
      await prefs.remove(_keySavedEmail);
      await prefs.remove(_keySavedPassword);
    }
  }

  Future<bool> isBiometricTransactionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricTransactionEnabled) ?? false;
  }

  Future<void> setBiometricTransactionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricTransactionEnabled, enabled);
  }

  Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedEmail, email);
    await prefs.setString(_keySavedPassword, password);
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keySavedEmail);
    final password = prefs.getString(_keySavedPassword);
    
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  Future<bool> hasSavedCredentials() async {
    final credentials = await getSavedCredentials();
    return credentials != null;
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedEmail);
    await prefs.remove(_keySavedPassword);
  }

  String getBiometricTypeName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    }
    return 'Biometric';
  }
}
