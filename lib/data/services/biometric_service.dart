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
  static const String _keyBiometricTransactionEnabled =
      'biometric_transaction_enabled';
  static const String _keySavedEmail = 'biometric_saved_email';
  static const String _keySavedPassword = 'biometric_saved_password';

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      debugPrint(
        'Biometric check: canCheckBiometrics=$canCheckBiometrics, isDeviceSupported=$isDeviceSupported',
      );
      debugPrint('Available biometrics: $availableBiometrics');

      final canAuthenticate = canCheckBiometrics || isDeviceSupported;
      debugPrint('Final canAuthenticate: $canAuthenticate');

      return canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric availability check failed: $e');
      return false;
    } catch (e) {
      debugPrint('Unexpected error checking biometrics: $e');
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

  Future<bool> authenticate({
    String reason = 'Please authenticate to continue',
  }) async {
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

  /// Returns true if the device has fingerprint sensor enrolled
  bool hasFingerprint(List<BiometricType> types) =>
      types.contains(BiometricType.fingerprint) ||
      types.contains(BiometricType.strong);

  /// Returns true if the device has face recognition enrolled
  bool hasFaceRecognition(List<BiometricType> types) =>
      types.contains(BiometricType.face);

  /// Returns true if the device has iris recognition enrolled
  bool hasIris(List<BiometricType> types) => types.contains(BiometricType.iris);

  /// Human-readable name for the primary biometric type available
  String getBiometricTypeName(List<BiometricType> types) {
    final hasface = hasFaceRecognition(types);
    final hasfinger = hasFingerprint(types);

    if (hasface && hasfinger) return 'Face ID / Fingerprint';
    if (hasface) return 'Face ID';
    if (hasfinger) return 'Fingerprint';
    if (types.contains(BiometricType.iris)) return 'Iris';
    return 'Biometric';
  }

  /// Authenticate using only fingerprint (biometricOnly = true, no face)
  Future<bool> authenticateFingerprint({
    String reason = 'Place your finger to authenticate',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Fingerprint authentication failed: $e');
      return false;
    }
  }

  /// Authenticate using only face recognition
  Future<bool> authenticateFace({
    String reason = 'Look at your camera to authenticate',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      // local_auth uses the OS biometric prompt — on Android it will use face
      // if that's what's enrolled; on iOS it uses Face ID automatically.
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Face authentication failed: $e');
      return false;
    }
  }

  // ── Preference keys for face recognition ──────────────────────────────────
  static const String _keyFaceLoginEnabled = 'face_login_enabled';
  static const String _keyFaceTransactionEnabled = 'face_transaction_enabled';

  Future<bool> isFaceLoginEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFaceLoginEnabled) ?? false;
  }

  Future<void> setFaceLoginEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFaceLoginEnabled, enabled);
    if (!enabled) {
      await prefs.remove(_keySavedEmail);
      await prefs.remove(_keySavedPassword);
    }
  }

  Future<bool> isFaceTransactionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFaceTransactionEnabled) ?? false;
  }

  Future<void> setFaceTransactionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFaceTransactionEnabled, enabled);
  }
}
