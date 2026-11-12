import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

/// Clean, elegant Wing AI dashboard
class WelcomeMessage extends StatelessWidget {
  final Function(String)? onQuestionTap;
  final String? userName;
  final int? dailyRemaining;
  final int? dailyLimit;
  final bool hasPreviousChat;
  final String? lastQuestion;
  final int messageCount;
  final VoidCallback? onContinuePreviousChat;
  final VoidCallback? onPrepareSermonTap;
  final VoidCallback? onMessageReviewTap;

  const WelcomeMessage({
    super.key,
    this.onQuestionTap,
    this.userName,
    this.dailyRemaining,
    this.dailyLimit,
    this.hasPreviousChat = false,
    this.lastQuestion,
    this.messageCount = 0,
    this.onContinuePreviousChat,
    this.onPrepareSermonTap,
    this.onMessageReviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = Responsive.isTablet(context);

    final firstName = userName != null && userName!.trim().isNotEmpty
        ? userName!.trim().split(' ').first
        : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 28 : 18,
            vertical: isTablet ? 20 : 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),

              // ── Wing AI Glowing Emblem ──
              Container(
                width: 64,
                height: 64,
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
                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Welcome Title ──
              Text(
                firstName != null ? 'Welcome, $firstName' : 'Welcome to Wing AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              Text(
                'Spiritual guidance, scriptural insights & church teachings',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // ── Unlimited Guidance Pill ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryGold.withValues(alpha: 0.15)
                      : AppColors.primaryGold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Unlimited Spiritual Guidance',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFB8860B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Option to Continue Previous Question ──
              if (hasPreviousChat) ...[
                _buildContinuePreviousCard(isDark),
                const SizedBox(height: 12),
              ],

              // ── Compact 2-Column Tool Row: Prepare Message & Message Review ──
              if (onPrepareSermonTap != null || onMessageReviewTap != null) ...[
                _buildAiToolsRow(isDark),
                const SizedBox(height: 12),
              ],

              // ── Clean Suggestion Grid (2x2) ──
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: isTablet ? 2.2 : 1.55,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
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
                    question: 'How do I grow spiritually in Christ?',
                    isDark: isDark,
                    onTap: onQuestionTap,
                  ),
                  _SuggestionCard(
                    icon: Icons.church_rounded,
                    accentColor: const Color(0xFF3B82F6),
                    category: 'CHURCH',
                    question: 'Who are the ministers of TCGC?',
                    isDark: isDark,
                    onTap: onQuestionTap,
                  ),
                  _SuggestionCard(
                    icon: Icons.headphones_rounded,
                    accentColor: const Color(0xFFF59E0B),
                    category: 'SERMONS',
                    question: 'Find messages on faith and victory',
                    isDark: isDark,
                    onTap: onQuestionTap,
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

  Widget _buildContinuePreviousCard(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onContinuePreviousChat,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF221E14) : const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: isDark ? 0.45 : 0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGold,
                ),
                child: const Icon(Icons.forum_rounded, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Previous Chat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFB8860B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      lastQuestion != null && lastQuestion!.trim().isNotEmpty
                          ? '"${lastQuestion!.trim()}"'
                          : 'Resume your discussion',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Resume',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_rounded, size: 11, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiToolsRow(bool isDark) {
    return Column(
      children: [
        if (onPrepareSermonTap != null)
          _CompactToolCard(
            icon: Icons.edit_note_rounded,
            accentColor: AppColors.primaryGold,
            title: 'Prepare Message or Sermon',
            subtitle: 'Draft sermons, Bible studies & teaching outlines from transcripts',
            isDark: isDark,
            onTap: onPrepareSermonTap!,
          ),
        if (onPrepareSermonTap != null && onMessageReviewTap != null)
          const SizedBox(height: 8),
        if (onMessageReviewTap != null)
          _CompactToolCard(
            icon: Icons.auto_stories_rounded,
            accentColor: AppColors.primaryGold,
            title: 'Message Review',
            subtitle: 'Break down minister teachings into simple, easy understanding',
            isDark: isDark,
            onTap: onMessageReviewTap!,
          ),
      ],
    );
  }
}

class _CompactToolCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _CompactToolCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222A) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.35 : 0.28),
              width: 0.9,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact Suggestion Card ──
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
        onTap: onTap != null ? () => onTap!(question) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222A) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: accentColor),
                  const SizedBox(width: 5),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimaryLight,
                  ),
                  maxLines: 2,
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
