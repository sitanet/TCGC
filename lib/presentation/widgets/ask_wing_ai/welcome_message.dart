import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import 'ai_consent_dialog.dart';

/// Beautiful, attractive welcome page shown when chat history is empty
class WelcomeMessage extends StatelessWidget {
  final Function(String)? onQuestionTap;
  final String? userName;
  final int? dailyRemaining;
  final int? dailyLimit;

  const WelcomeMessage({
    super.key,
    this.onQuestionTap,
    this.userName,
    this.dailyRemaining,
    this.dailyLimit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
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
              const SizedBox(height: 8),

              // ── Glowing Golden Wing AI Emblem ──
              Stack(
                alignment: Alignment.center,
                children: [
                  // Ambient glow
                  Container(
                    width: isTablet ? 100 : 88,
                    height: isTablet ? 100 : 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryGold.withValues(alpha: isDark ? 0.35 : 0.25),
                          AppColors.primaryGold.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Outer ring
                  Container(
                    width: isTablet ? 86 : 74,
                    height: isTablet ? 86 : 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryGold.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Inner Core Emblem
                  Container(
                    width: isTablet ? 74 : 64,
                    height: isTablet ? 74 : 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFE082),
                          Color(0xFFE5A93C),
                          Color(0xFFB8860B),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGold.withValues(alpha: 0.4),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: isTablet ? 38 : 32,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Title & Assistant Badge ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Wing AI',
                    style: TextStyle(
                      fontSize: isTablet ? 26 : 23,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGold.withValues(alpha: 0.2),
                          const Color(0xFFE5A93C).withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryGold.withValues(alpha: 0.5),
                        width: 0.9,
                      ),
                    ),
                    child: const Text(
                      'ASSISTANT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                firstName != null
                    ? 'Welcome, $firstName! How can I guide you today?'
                    : 'Welcome! How can I guide you today?',
                style: TextStyle(
                  fontSize: isTablet ? 15.5 : 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              Text(
                'Explore sermon teachings, scriptural insights, and answers to your spiritual questions.',
                style: TextStyle(
                  fontSize: isTablet ? 13 : 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // ── Unlimited Access Status Pill ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGold.withValues(alpha: isDark ? 0.22 : 0.10),
                      const Color(0xFFE5A93C).withValues(alpha: isDark ? 0.12 : 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: isDark ? 0.45 : 0.3),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: isDark ? 0.12 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Unlimited AI Spiritual Guidance',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFB8860B),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // AI Privacy & Data Disclosure Notice
              GestureDetector(
                onTap: () {
                  AIConsentDialog.showConsentDialog(context, isInformationalOnly: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 13, color: AppColors.primaryGold),
                      const SizedBox(width: 5),
                      Text(
                        'AI Data Privacy Notice',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // ── Suggestion Grid (Responsive & Beautiful) ──
              GridView.count(
                crossAxisCount: isTablet ? 2 : 2,
                childAspectRatio: isTablet ? 2.1 : 1.42,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SuggestionCard(
                    icon: Icons.menu_book_rounded,
                    accentColor: const Color(0xFF7E57C2),
                    category: 'TEACHING',
                    question: 'What is the eternal purpose of God?',
                    isDark: isDark,
                    onTap: onQuestionTap,
                  ),
                  _SuggestionCard(
                    icon: Icons.spa_rounded,
                    accentColor: const Color(0xFF10B981),
                    category: 'GROWTH',
                    question: 'How do I grow into the fullness of Christ?',
                    isDark: isDark,
                    onTap: onQuestionTap,
                  ),
                  _SuggestionCard(
                    icon: Icons.church_rounded,
                    accentColor: const Color(0xFF3B82F6),
                    category: 'CHURCH',
                    question: 'Who are the ministers of The CityGate Church?',
                    isDark: isDark,
                    onTap: onQuestionTap,
                  ),
                  _SuggestionCard(
                    icon: Icons.headphones_rounded,
                    accentColor: const Color(0xFFF59E0B),
                    category: 'SERMONS',
                    question: 'Find messages about faith and victory',
                    isDark: isDark,
                    onTap: onQuestionTap,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Bottom encouragement ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mic_none_rounded,
                    size: 14,
                    color: isDark ? AppColors.primaryGold : primaryColor,
                  ),
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
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Beautiful Suggestion Card with Gradient Tint & Glow ──
class _SuggestionCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String category;
  final String question;
  final bool isDark;
  final Function(String)? onTap;

  const _SuggestionCard({
    required this.icon,
    required this.accentColor,
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
        borderRadius: BorderRadius.circular(18),
        splashColor: accentColor.withValues(alpha: 0.12),
        highlightColor: accentColor.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      accentColor.withValues(alpha: 0.10),
                      AppColors.cardDark,
                    ]
                  : [
                      accentColor.withValues(alpha: 0.05),
                      Colors.white,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? accentColor.withValues(alpha: 0.25)
                  : accentColor.withValues(alpha: 0.20),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(icon, size: 14.5, color: accentColor),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 13,
                    color: accentColor.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.92)
                        : AppColors.textPrimaryLight,
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
