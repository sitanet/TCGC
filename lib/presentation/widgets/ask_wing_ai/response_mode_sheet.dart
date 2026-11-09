import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Enum representing the three Wing AI response modes
enum WingAIResponseMode {
  simple('simple', 'Simple Response', 'Explain like to a child', Color(0xFF0D9488), Icons.child_care_rounded),
  short('short', 'Short Response', 'Quick Summary', Color(0xFFF59E0B), Icons.flash_on_rounded),
  advanced('advanced', 'Advanced Response', 'Deep & Scriptural', Color(0xFF7C3AED), Icons.auto_stories_rounded);

  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const WingAIResponseMode(this.id, this.title, this.subtitle, this.color, this.icon);

  static WingAIResponseMode fromId(String? id) {
    switch (id) {
      case 'short':
        return WingAIResponseMode.short;
      case 'advance':
      case 'advanced':
        return WingAIResponseMode.advanced;
      case 'simple':
      default:
        return WingAIResponseMode.simple;
    }
  }
}

/// A modal popup bottom sheet presented when the user asks a question,
/// letting them select Simple, Short, or Advanced response depth.
class ResponseModeSheet extends StatelessWidget {
  final String question;
  final Function(WingAIResponseMode mode) onModeSelected;

  const ResponseModeSheet({
    super.key,
    required this.question,
    required this.onModeSelected,
  });

  static Future<WingAIResponseMode?> show(BuildContext context, {required String question}) {
    return showModalBottomSheet<WingAIResponseMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ResponseModeSheet(
        question: question,
        onModeSelected: (mode) {
          Navigator.of(ctx).pop(mode);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCardColor = isDark ? const Color(0xFF1B1E26) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgCardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD54F), AppColors.primaryGold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Response Style',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'How would you like Wing AI to answer?',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Question preview card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote_rounded, size: 18, color: AppColors.primaryGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.trim(),
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Option 1: Simple Response ──
            _buildOptionCard(
              context: context,
              mode: WingAIResponseMode.simple,
              description: 'Explains like to a child with plain, everyday words and cheerful, easy-to-grasp examples.',
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // ── Option 2: Short Response ──
            _buildOptionCard(
              context: context,
              mode: WingAIResponseMode.short,
              description: 'Quick bulleted summary giving the key takeaways straight to the point.',
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // ── Option 3: Advanced Response ──
            _buildOptionCard(
              context: context,
              mode: WingAIResponseMode.advanced,
              description: 'In-depth theological exposition with extensive Bible verses and church message references.',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required WingAIResponseMode mode,
    required String description,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onModeSelected(mode),
        borderRadius: BorderRadius.circular(18),
        splashColor: mode.color.withValues(alpha: 0.15),
        highlightColor: mode.color.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      mode.color.withValues(alpha: 0.14),
                      mode.color.withValues(alpha: 0.04),
                    ]
                  : [
                      mode.color.withValues(alpha: 0.08),
                      Colors.white,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: mode.color.withValues(alpha: isDark ? 0.35 : 0.28),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: mode.color.withValues(alpha: isDark ? 0.10 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Colored Icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mode.color.withValues(alpha: 0.18),
                  border: Border.all(color: mode.color.withValues(alpha: 0.4), width: 1),
                ),
                child: Center(
                  child: Icon(mode.icon, color: mode.color, size: 22),
                ),
              ),
              const SizedBox(width: 14),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          mode.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: mode.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: mode.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            mode.subtitle,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: mode.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: mode.color.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
