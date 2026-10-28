import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../pages/legal/privacy_policy_page.dart';

/// Modal dialog providing explicit disclosure and requesting user permission
/// before sharing user queries with OpenAI, fully compliant with global
/// data protection laws and privacy regulations.
class AIConsentDialog extends StatelessWidget {
  final bool isInformationalOnly;

  static const String consentKey = 'user_ai_consent_accepted_v1';

  const AIConsentDialog({
    super.key,
    this.isInformationalOnly = false,
  });

  /// Check whether the user has already granted consent
  static Future<bool> hasConsented() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(consentKey) ?? false;
  }

  /// Store the user's consent decision
  static Future<void> setConsented(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(consentKey, consented);
  }

  /// Show the AI consent dialog and return true if consented
  static Future<bool> showConsentDialog(
    BuildContext context, {
    bool isInformationalOnly = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: isInformationalOnly,
      builder: (ctx) => AIConsentDialog(
        isInformationalOnly: isInformationalOnly,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E222A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Golden Icon
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFD54F),
                        AppColors.primaryGold,
                        Color(0xFFB8860B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Center(
                child: Text(
                  'AI Privacy & Data Consent',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Ask Wing AI Assistant',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Explanatory Note
              Text(
                'Before you use Ask Wing AI, please review how your data is handled in accordance with data protection policy and privacy regulations:',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 14),

              // Disclosure 1: What data is sent
              _buildDisclosureItem(
                context,
                isDark,
                icon: Icons.chat_bubble_outline_rounded,
                title: 'What data is sent',
                description:
                    'Only the questions, message prompts, and biblical search queries you enter into the Ask Wing AI chat are transmitted.',
              ),
              const SizedBox(height: 10),

              // Disclosure 2: Who it is sent to
              _buildDisclosureItem(
                context,
                isDark,
                icon: Icons.hub_outlined,
                title: 'Who the data is sent to',
                description:
                    'Your queries are securely transmitted to OpenAI, LLC (third-party AI service provider) and our secure cloud server to search church sermon transcripts and generate spiritual guidance.',
              ),
              const SizedBox(height: 10),

              // Disclosure 3: What is NOT shared
              _buildDisclosureItem(
                context,
                isDark,
                icon: Icons.shield_outlined,
                title: 'Data Protection & Security',
                description:
                    'We never share your personal account details, email, contact list, or payment data. OpenAI API inputs are not used to train AI models.',
              ),
              const SizedBox(height: 10),

              // Disclosure 4: User control
              _buildDisclosureItem(
                context,
                isDark,
                icon: Icons.delete_sweep_outlined,
                title: 'Your Control',
                description:
                    'You may clear your entire chat history at any time from the chat menu. You may decline this notice if you choose not to use the AI assistant.',
              ),
              const SizedBox(height: 16),

              // Link to Privacy Policy
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.privacy_tip_outlined, size: 16, color: AppColors.primaryGold),
                  label: const Text(
                    'Read our Full Privacy Policy',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons
              if (isInformationalOnly)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.grey[400] : Colors.grey[700],
                          side: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          await setConsented(true);
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                        ),
                        child: const Text(
                          'I Agree & Continue',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclosureItem(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.primaryGold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
