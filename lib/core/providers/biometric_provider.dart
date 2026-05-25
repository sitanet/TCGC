import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../../data/services/biometric_service.dart';

class BiometricProvider extends ChangeNotifier {
  final BiometricService _biometricService = BiometricService();

  bool _isAvailable = false;
  bool _hasFace = false;
  bool _hasFingerprint = false;

  // Login toggles
  bool _biometricLoginEnabled = false; // fingerprint login
  bool _faceLoginEnabled = false; // face login

  // Transaction toggles
  bool _biometricTransactionEnabled = false; // fingerprint transactions
  bool _faceTransactionEnabled = false; // face transactions

  bool _hasSavedCredentials = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isLoading = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isAvailable => _isAvailable;
  bool get hasFace => _hasFace;
  bool get hasFingerprint => _hasFingerprint;

  bool get biometricLoginEnabled => _biometricLoginEnabled;
  bool get faceLoginEnabled => _faceLoginEnabled;

  bool get biometricTransactionEnabled => _biometricTransactionEnabled;
  bool get faceTransactionEnabled => _faceTransactionEnabled;

  bool get hasSavedCredentials => _hasSavedCredentials;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  bool get isLoading => _isLoading;

  String get biometricTypeName =>
      _biometricService.getBiometricTypeName(_availableBiometrics);

  // ── Initialize ─────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isAvailable = await _biometricService.isBiometricAvailable();
    if (_isAvailable) {
      _availableBiometrics = await _biometricService.getAvailableBiometrics();
      _hasFace = _biometricService.hasFaceRecognition(_availableBiometrics);
      _hasFingerprint = _biometricService.hasFingerprint(_availableBiometrics);
    }

    _biometricLoginEnabled = await _biometricService.isBiometricLoginEnabled();
    _faceLoginEnabled = await _biometricService.isFaceLoginEnabled();
    _biometricTransactionEnabled = await _biometricService
        .isBiometricTransactionEnabled();
    _faceTransactionEnabled = await _biometricService
        .isFaceTransactionEnabled();
    _hasSavedCredentials = await _biometricService.hasSavedCredentials();

    _isLoading = false;
    notifyListeners();
  }

  // ── Generic authenticate (used by wallet page) ─────────────────────────────
  Future<bool> authenticate({String? reason}) async {
    if (!_isAvailable) return false;
    return await _biometricService.authenticate(
      reason: reason ?? 'Please authenticate',
    );
  }

  // ── Transaction auth — tries face first if enabled, then fingerprint ───────
  Future<bool> authenticateForTransaction() async {
    if (!_isAvailable) return false;

    if (_faceTransactionEnabled && _hasFace) {
      final ok = await _biometricService.authenticateFace(
        reason: 'Look at your camera to confirm transaction',
      );
      if (ok) return true;
    }

    if (_biometricTransactionEnabled && _hasFingerprint) {
      return await _biometricService.authenticateFingerprint(
        reason: 'Place your finger to confirm transaction',
      );
    }

    // Fallback: any available biometric
    if (_faceTransactionEnabled || _biometricTransactionEnabled) {
      return await _biometricService.authenticateForTransaction();
    }

    return false;
  }

  // ── Login auth ─────────────────────────────────────────────────────────────
  Future<bool> authenticateForLogin() async {
    if (!_isAvailable) return false;

    if (_faceLoginEnabled && _hasFace) {
      final ok = await _biometricService.authenticateFace(
        reason: 'Look at your camera to sign in',
      );
      if (ok) return true;
    }

    if (_biometricLoginEnabled && _hasFingerprint) {
      return await _biometricService.authenticateFingerprint(
        reason: 'Place your finger to sign in',
      );
    }

    if (_faceLoginEnabled || _biometricLoginEnabled) {
      return await _biometricService.authenticateForLogin();
    }

    return false;
  }

  // ── Fingerprint login toggle ───────────────────────────────────────────────
  Future<void> setBiometricLoginEnabled(
    bool enabled, {
    String? email,
    String? password,
  }) async {
    debugPrint(
      'setBiometricLoginEnabled: enabled=$enabled, isAvailable=$_isAvailable',
    );

    if (enabled && !_isAvailable) return;

    if (enabled) {
      final authenticated = await _biometricService.authenticateFingerprint(
        reason: 'Authenticate to enable fingerprint login',
      );
      if (!authenticated) return;

      if (email != null && password != null) {
        await _biometricService.saveCredentials(email, password);
        _hasSavedCredentials = true;
      }
    } else {
      // Only clear credentials if face login is also disabled
      if (!_faceLoginEnabled) {
        await _biometricService.clearCredentials();
        _hasSavedCredentials = false;
      }
    }

    await _biometricService.setBiometricLoginEnabled(enabled);
    _biometricLoginEnabled = enabled;
    notifyListeners();
  }

  // ── Face login toggle ──────────────────────────────────────────────────────
  Future<void> setFaceLoginEnabled(
    bool enabled, {
    String? email,
    String? password,
  }) async {
    if (enabled && (!_isAvailable || !_hasFace)) return;

    if (enabled) {
      final authenticated = await _biometricService.authenticateFace(
        reason: 'Look at your camera to enable Face ID login',
      );
      if (!authenticated) return;

      if (email != null && password != null) {
        await _biometricService.saveCredentials(email, password);
        _hasSavedCredentials = true;
      }
    } else {
      if (!_biometricLoginEnabled) {
        await _biometricService.clearCredentials();
        _hasSavedCredentials = false;
      }
    }

    await _biometricService.setFaceLoginEnabled(enabled);
    _faceLoginEnabled = enabled;
    notifyListeners();
  }

  // ── Fingerprint transaction toggle ─────────────────────────────────────────
  Future<void> setBiometricTransactionEnabled(bool enabled) async {
    if (enabled && !_isAvailable) return;

    if (enabled) {
      final authenticated = await _biometricService.authenticateFingerprint(
        reason: 'Authenticate to enable fingerprint for transactions',
      );
      if (!authenticated) return;
    }

    await _biometricService.setBiometricTransactionEnabled(enabled);
    _biometricTransactionEnabled = enabled;
    notifyListeners();
  }

  // ── Face transaction toggle ────────────────────────────────────────────────
  Future<void> setFaceTransactionEnabled(bool enabled) async {
    if (enabled && (!_isAvailable || !_hasFace)) return;

    if (enabled) {
      final authenticated = await _biometricService.authenticateFace(
        reason: 'Look at your camera to enable Face ID for transactions',
      );
      if (!authenticated) return;
    }

    await _biometricService.setFaceTransactionEnabled(enabled);
    _faceTransactionEnabled = enabled;
    notifyListeners();
  }

  // ── Credentials helpers ────────────────────────────────────────────────────
  Future<Map<String, String>?> getSavedCredentials() async {
    return await _biometricService.getSavedCredentials();
  }

  Future<void> saveCredentials(String email, String password) async {
    await _biometricService.saveCredentials(email, password);
    _hasSavedCredentials = true;
    notifyListeners();
  }

  Future<void> clearOnLogout() async {
    _hasSavedCredentials = await _biometricService.hasSavedCredentials();
    notifyListeners();
  }
}
