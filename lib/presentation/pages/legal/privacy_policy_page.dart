import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Privacy & Data Policy', showBackButton: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, isDark),
              const SizedBox(height: 24),
              _buildSection(
                context,
                isDark,
                'Information We Collect',
                'We collect information you provide directly to us, including:\n\n'
                    '• Personal information (name, email, phone number)\n'
                    '• Church membership information\n'
                    '• Financial information for transactions\n'
                    '• Device information and usage data',
              ),
              _buildSection(
                context,
                isDark,
                'How We Use Your Information',
                'We use the information we collect to:\n\n'
                    '• Provide and improve our services\n'
                    '• Process your transactions\n'
                    '• Send you updates and notifications\n'
                    '• Personalize your experience\n'
                    '• Ensure security and prevent fraud',
              ),
              _buildSection(
                context,
                isDark,
                'Data Security',
                'We implement appropriate security measures to protect your personal information. '
                    'Your data is encrypted and stored securely. We use industry-standard protocols '
                    'to ensure the safety of your information during transmission.',
              ),
              _buildSection(
                context,
                isDark,
                'Data Sharing',
                'We do not sell your personal information. We may share your information with:\n\n'
                    '• Service providers who assist in our operations\n'
                    '• Payment processors for financial transactions\n'
                    '• Legal authorities when required by law',
              ),
              _buildSection(
                context,
                isDark,
                'Your Rights',
                'You have the right to:\n\n'
                    '• Access your personal data\n'
                    '• Request correction of inaccurate data\n'
                    '• Request deletion of your data\n'
                    '• Opt-out of marketing communications\n'
                    '• Export your data',
              ),
              _buildSection(
                context,
                isDark,
                'Cookies and Tracking',
                'We use cookies and similar technologies to enhance your experience, '
                    'analyze usage patterns, and deliver personalized content. You can manage '
                    'your cookie preferences through your device settings.',
              ),
              _buildSection(
                context,
                isDark,
                'Children\'s Privacy',
                'Our services are not intended for children under 13. We do not knowingly '
                    'collect personal information from children under 13. If you believe we have '
                    'collected such information, please contact us.',
              ),
              _buildSection(
                context,
                isDark,
                'Changes to This Policy',
                'We may update this privacy policy from time to time. We will notify you of '
                    'any changes by posting the new policy on this page and updating the '
                    '"Last Updated" date.',
              ),
              _buildSection(
                context,
                isDark,
                'Contact Us',
                'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                    'Email: privacy@tcgc.org\n'
                    'Phone: +234 800 000 0000',
              ),
              const SizedBox(height: 16),
              _buildLastUpdated(context, isDark),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.primaryGold.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.privacy_tip_outlined,
              color: AppColors.primaryGold,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Privacy Matters',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Learn how we collect, use, and protect your data',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    bool isDark,
    String title,
    String content,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.update,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Last Updated: December 2025',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
          ),
        ],
      ),
    );
  }
}
