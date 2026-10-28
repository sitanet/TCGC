import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import 'ai_consent_dialog.dart';

/// Beautiful welcome page shown when chat history is empty
class WelcomeMessage extends StatelessWidget {
  final Function(String)? onQuestionTap;
  final String? userName;
  final int? dailyRemaining;
  final int? dailyLimit;

  const WelcomeMessage({
    Key? key,
    this.onQuestionTap,
    this.userName,
    this.dailyRemaining,
    this.dailyLimit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final remaining = dailyRemaining ?? 15;
    final limit = dailyLimit ?? 15;
    final isTablet = Responsive.isTablet(context);

    final firstName = userName != null && userName!.trim().isNotEmpty
        ? userName!.trim().split(' ').first
        : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 20,
            vertical: isTablet ? 28 : 16,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // ── Golden Wing AI Emblem ──
              Container(
                width: isTablet ? 96 : 84,
                height: isTablet ? 96 : 84,
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
                      color: AppColors.primaryGold.withValues(alpha: 0.38),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/wing_ai_eagle.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF1E232F),
                      child: const Center(
                        child: Icon(Icons.auto_awesome_rounded, color: AppColors.primaryGold, size: 36),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Title & Greeting ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Wing AI',
                    style: TextStyle(
                      fontSize: isTablet ? 26 : 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5), width: 0.8),
                    ),
                    child: const Text(
                      'ASSISTANT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Text(
                firstName != null ? 'Welcome, $firstName! How can I guide you today?' : 'Welcome! How can I guide you today?',
                style: TextStyle(
                  fontSize: isTablet ? 15 : 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              Text(
                'Explore sermon teachings, scriptural insights, and answers to your spiritual questions.',
                style: TextStyle(
                  fontSize: isTablet ? 13 : 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // ── Prompt Counter Chip ──
              _buildPromptChip(remaining, limit, isDark),
              const SizedBox(height: 10),

              // AI Privacy & Data Disclosure Notice
              GestureDetector(
                onTap: () {
                  AIConsentDialog.showConsentDialog(context, isInformationalOnly: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 14, color: AppColors.primaryGold),
                      const SizedBox(width: 6),
                      Text(
                        'Powered by OpenAI • Data Privacy Notice',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Suggestion Grid (Responsive) ──
              GridView.count(
                crossAxisCount: isTablet ? 2 : 2,
                childAspectRatio: isTablet ? 2.0 : 1.45,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SuggestionCard(
                    icon: Icons.menu_book_rounded,
                    iconColor: const Color(0xFF7E57C2),
                    category: 'TEACHING',
                    question: 'What is the eternal purpose of God?',
                    isDark: isDark,
                    onTap: onQuestionTap,
                  ),
                  _SuggestionCard(
                    icon: Icons.spa_rounded,
                    iconColor: const Color(0xFF26A69A),
                    category: 'GROWTH',
                    question: 'How do I grow into the fullness of Christ?',
                    isDark: isDark,
                    onTap: onQuestionTap,
                  ),
                  _SuggestionCard(
                    icon: Icons.church_rounded,
                    iconColor: const Color(0xFF3F51B5),
                    category: 'CHURCH',
                    question: 'Who are the ministers of The CityGate Church?',
                    isDark: isDark,
                    onTap: onQuestionTap,
                  ),
                  _SuggestionCard(
                    icon: Icons.search_rounded,
                    iconColor: const Color(0xFFE5A93C),
                    category: 'SERMONS',
                    question: 'Find messages about faith and victory',
                    isDark: isDark,
                    onTap: onQuestionTap,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Bottom encouragement ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_none_rounded, size: 14, color: isDark ? AppColors.primaryGold : primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'Tap a topic above or speak your question below',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptChip(int remaining, int limit, bool isDark) {
    Color chipColor;
    if (remaining == 0) {
      chipColor = const Color(0xFFE53935);
    } else if (remaining <= 5) {
      chipColor = const Color(0xFFFB8C00);
    } else {
      chipColor = AppColors.primaryGold;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.35),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 14, color: chipColor),
          const SizedBox(width: 5),
          Text(
            '$remaining of $limit daily questions available',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: chipColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion Card ──
class _SuggestionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String category;
  final String question;
  final bool isDark;
  final Function(String)? onTap;

  const _SuggestionCard({
    required this.icon,
    required this.iconColor,
    required this.category,
    required this.question,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap?.call(question),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimaryLight,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
