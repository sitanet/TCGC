import 'package:shared_preferences/shared_preferences.dart';

class CredentialStorageService {
  static final CredentialStorageService _instance = CredentialStorageService._internal();
  factory CredentialStorageService() => _instance;
  CredentialStorageService._internal();

  static const String _keyRememberCredentials = 'remember_credentials';
  static const String _keyStoredEmail = 'stored_email';
  static const String _keyStoredPassword = 'stored_password';
  static const String _keyLastEmailsList = 'last_emails_list';
  static const int _maxStoredEmails = 5; // Maximum number of emails to store

  /// Check if user has enabled remember credentials feature
  Future<bool> isRememberCredentialsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberCredentials) ?? false;
  }

  /// Enable/disable remember credentials feature
  Future<void> setRememberCredentialsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberCredentials, enabled);
    
    if (!enabled) {
      // Clear all stored credentials when disabled
      await clearAllCredentials();
    }
  }

  /// Save credentials after successful login
  Future<void> saveCredentials(String email, String password) async {
    final isEnabled = await isRememberCredentialsEnabled();
    if (!isEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStoredEmail, email.toLowerCase());
    await prefs.setString(_keyStoredPassword, password);
    
    // Also add to email history
    await _addToEmailHistory(email.toLowerCase());
  }

  /// Get saved credentials (last used email and password)
  Future<Map<String, String>?> getSavedCredentials() async {
    final isEnabled = await isRememberCredentialsEnabled();
    if (!isEnabled) return null;

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyStoredEmail);
    final password = prefs.getString(_keyStoredPassword);

    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  /// Get list of previously used email addresses
  Future<List<String>> getEmailHistory() async {
    final isEnabled = await isRememberCredentialsEnabled();
    if (!isEnabled) return [];

    final prefs = await SharedPreferences.getInstance();
    final emailsJson = prefs.getStringList(_keyLastEmailsList) ?? [];
    return emailsJson;
  }

  /// Get password for specific email (if available)
  Future<String?> getPasswordForEmail(String email) async {
    final credentials = await getSavedCredentials();
    if (credentials != null && credentials['email'] == email.toLowerCase()) {
      return credentials['password'];
    }
    return null;
  }

  /// Add email to history (called after successful login)
  Future<void> _addToEmailHistory(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final emails = prefs.getStringList(_keyLastEmailsList) ?? [];
    
    // Remove email if it already exists
    emails.remove(email);
    
    // Add to beginning of list
    emails.insert(0, email);
    
    // Keep only the most recent emails
    if (emails.length > _maxStoredEmails) {
      emails.removeRange(_maxStoredEmails, emails.length);
    }
    
    await prefs.setStringList(_keyLastEmailsList, emails);
  }

  /// Clear all stored credentials
  Future<void> clearAllCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStoredEmail);
    await prefs.remove(_keyStoredPassword);
    await prefs.remove(_keyLastEmailsList);
  }

  /// Check if we have any saved credentials
  Future<bool> hasSavedCredentials() async {
    final credentials = await getSavedCredentials();
    return credentials != null;
  }

  /// Get email suggestions for autofill dropdown
  Future<List<EmailSuggestion>> getEmailSuggestions() async {
    final emails = await getEmailHistory();
    final suggestions = <EmailSuggestion>[];
    
    for (final email in emails) {
      final hasPassword = await getPasswordForEmail(email) != null;
      suggestions.add(EmailSuggestion(
        email: email,
        hasStoredPassword: hasPassword,
      ));
    }
    
    return suggestions;
  }
}

class EmailSuggestion {
  final String email;
  final bool hasStoredPassword;

  EmailSuggestion({
    required this.email,
    required this.hasStoredPassword,
  });
}