import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/credential_storage_service.dart';

class CredentialsManagerDialog extends StatefulWidget {
  const CredentialsManagerDialog({super.key});

  @override
  State<CredentialsManagerDialog> createState() => _CredentialsManagerDialogState();
}

class _CredentialsManagerDialogState extends State<CredentialsManagerDialog> {
  final CredentialStorageService _credentialService = CredentialStorageService();
  List<EmailSuggestion> _emailSuggestions = [];
  bool _isLoading = true;
  bool _rememberCredentialsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final suggestions = await _credentialService.getEmailSuggestions();
      final enabled = await _credentialService.isRememberCredentialsEnabled();
      
      if (mounted) {
        setState(() {
          _emailSuggestions = suggestions;
          _rememberCredentialsEnabled = enabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearAllCredentials() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Credentials'),
        content: const Text('Are you sure you want to remove all saved login details? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _credentialService.clearAllCredentials();
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All saved credentials cleared'),
            backgroundColor: AppColors.primaryGold,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Saved Credentials'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Remember Credentials Toggle
                  SwitchListTile(
                    title: const Text('Remember Login Details'),
                    subtitle: const Text('Save usernames and passwords for quick access'),
                    value: _rememberCredentialsEnabled,
                    activeColor: AppColors.primaryGold,
                    onChanged: (value) async {
                      await _credentialService.setRememberCredentialsEnabled(value);
                      setState(() {
                        _rememberCredentialsEnabled = value;
                      });
                      if (!value) {
                        setState(() {
                          _emailSuggestions.clear();
                        });
                      }
                    },
                  ),
                  
                  const Divider(),
                  
                  // Saved Emails Section
                  if (_rememberCredentialsEnabled) ...[
                    const Text(
                      'Saved Accounts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    if (_emailSuggestions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'No saved credentials yet.\nLogin successfully to save your details.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _emailSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _emailSuggestions[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.person_outline,
                                  size: 20,
                                ),
                                title: Text(
                                  suggestion.email,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (suggestion.hasStoredPassword)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGold.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.key,
                                              size: 12,
                                              color: AppColors.primaryGold,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Password saved',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.primaryGold,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                    if (_emailSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: _clearAllCredentials,
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text(
                            'Clear All Saved Credentials',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ] else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Enable "Remember Login Details" to save your credentials.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}