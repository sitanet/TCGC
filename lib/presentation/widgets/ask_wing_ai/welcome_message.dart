import 'package:flutter/material.dart';

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
    final remaining = dailyRemaining ?? 20;
    final limit = dailyLimit ?? 20;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),

            // ── Golden Wing Emblem ──
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE5A93C),
                    primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                    blurRadius: 22,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFE5A93C),
                  width: 2.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.flutter_dash,
                  size: 52,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ──
            Text(
              'Wing AI',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 0.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // ── Greeting ──
            Text(
              userName != null && userName!.isNotEmpty
                  ? 'Hello, $userName! 👋'
                  : 'Hello! 👋',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // ── Tagline ──
            Text(
              'Your Spiritual Companion & Study Guide',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // ── Prompt Counter Chip ──
            _buildPromptChip(remaining, limit, isDark),
            const SizedBox(height: 24),

            // ── Suggestion Grid ──
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _SuggestionCard(
                  icon: Icons.menu_book_outlined,
                  iconColor: Colors.deepPurple,
                  title: 'Apostolic Teachings',
                  question: 'What is the eternal purpose of God?',
                  isDark: isDark,
                  onTap: onQuestionTap,
                ),
                _SuggestionCard(
                  icon: Icons.spa_outlined,
                  iconColor: Colors.teal,
                  title: 'Spiritual Growth',
                  question: 'How do I grow into the fullness of Christ?',
                  isDark: isDark,
                  onTap: onQuestionTap,
                ),
                _SuggestionCard(
                  icon: Icons.church_outlined,
                  iconColor: Colors.indigo,
                  title: 'Church & Pastors',
                  question: 'Who are the pastors of The CityGate Church?',
                  isDark: isDark,
                  onTap: onQuestionTap,
                ),
                _SuggestionCard(
                  icon: Icons.celebration_outlined,
                  iconColor: Colors.orange,
                  title: 'Conferences & Events',
                  question: 'What conferences does TCGC host?',
                  isDark: isDark,
                  onTap: onQuestionTap,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Bottom encouragement ──
            Text(
              'Tap any topic or type your own question below 🙏',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: primaryColor,
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
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
      chipColor = const Color(0xFFD48B00);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Text(
            '$remaining of $limit prompts available today',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
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
  final String title;
  final String question;
  final bool isDark;
  final Function(String)? onTap;

  const _SuggestionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              // Question preview
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.3,
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
