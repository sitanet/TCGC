/// ConsentService — handles NDPR data protection API calls.
/// Records user consent, handles data export and erasure requests.
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';

class ConsentService {
  final ApiService _api = ApiService();

  /// Record consent to privacy policy on registration or first login.
  Future<bool> recordPrivacyPolicyConsent() async {
    try {
      final response = await _api.post(ApiConstants.recordConsent, {
        'consent_type': 'privacy_policy',
        'version': '1.0',
        'granted': true,
      });
      return response.isSuccess;
    } catch (e) {
      debugPrint('[CONSENT] Failed to record privacy policy consent: $e');
      return false;
    }
  }

  /// Record consent to terms of service.
  Future<bool> recordTermsConsent() async {
    try {
      final response = await _api.post(ApiConstants.recordConsent, {
        'consent_type': 'terms_of_service',
        'version': '1.0',
        'granted': true,
      });
      return response.isSuccess;
    } catch (e) {
      debugPrint('[CONSENT] Failed to record terms consent: $e');
      return false;
    }
  }

  /// Withdraw marketing consent.
  Future<bool> withdrawMarketingConsent() async {
    try {
      final response = await _api.post(ApiConstants.withdrawConsent, {
        'consent_type': 'marketing',
      });
      return response.isSuccess;
    } catch (e) {
      debugPrint('[CONSENT] Failed to withdraw marketing consent: $e');
      return false;
    }
  }

  /// Get current consent status for all types.
  Future<Map<String, dynamic>?> getConsentStatus() async {
    try {
      final response = await _api.get(ApiConstants.consentStatus);
      if (response.isSuccess) return response.data;
      return null;
    } catch (e) {
      debugPrint('[CONSENT] Failed to get consent status: $e');
      return null;
    }
  }

  /// Request data export (right to access).
  Future<Map<String, dynamic>?> exportData() async {
    try {
      final response = await _api.get(ApiConstants.dataExport);
      if (response.isSuccess) return response.data;
      return null;
    } catch (e) {
      debugPrint('[CONSENT] Failed to export data: $e');
      return null;
    }
  }

  /// Request data erasure (right to erasure) — requires password confirmation.
  Future<bool> eraseData(String password) async {
    try {
      final response = await _api.post(ApiConstants.dataErase, {
        'password': password,
      });
      return response.isSuccess;
    } catch (e) {
      debugPrint('[CONSENT] Failed to erase data: $e');
      return false;
    }
  }

  /// Fetch the privacy policy from the backend.
  Future<Map<String, dynamic>?> getPrivacyPolicy() async {
    try {
      final response = await _api.get(ApiConstants.privacyPolicy);
      if (response.isSuccess) return response.data;
      return null;
    } catch (e) {
      debugPrint('[CONSENT] Failed to fetch privacy policy: $e');
      return null;
    }
  }
}
