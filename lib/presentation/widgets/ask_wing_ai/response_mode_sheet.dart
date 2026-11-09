import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Enum representing the three Wing AI response modes
enum WingAIResponseMode {
  simple(
    'simple',
    'Simple Response',
    'Explain like to a child with plain words',
    Color(0xFF0D9488),
    Icons.child_care_rounded,
  ),
  short(
    'short',
    'Short Response',
    'Quick summary of key takeaways',
    Color(0xFFF59E0B),
    Icons.bolt_rounded,
  ),
  advanced(
    'advanced',
    'Advanced Response',
    'Deep scriptural exposition & sermon citations',
    Color(0xFF7C3AED),
    Icons.menu_book_rounded,
  );

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

/// A clean, perfectly aligned modal bottom sheet for selecting response depth.
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD54F), AppColors.primaryGold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Response Style',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 1),
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
            const SizedBox(height: 16),

            // ── Option 1: Simple Response ──
            _buildOptionCard(
              mode: WingAIResponseMode.simple,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            // ── Option 2: Short Response ──
            _buildOptionCard(
              mode: WingAIResponseMode.short,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            // ── Option 3: Advanced Response ──
            _buildOptionCard(
              mode: WingAIResponseMode.advanced,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required WingAIResponseMode mode,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onModeSelected(mode),
        borderRadius: BorderRadius.circular(16),
        splashColor: mode.color.withValues(alpha: 0.15),
        highlightColor: mode.color.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? mode.color.withValues(alpha: 0.10)
                : mode.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: mode.color.withValues(alpha: isDark ? 0.35 : 0.28),
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              // Colored Icon badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mode.color.withValues(alpha: 0.18),
                ),
                child: Center(
                  child: Icon(mode.icon, color: mode.color, size: 20),
                ),
              ),
              const SizedBox(width: 12),

              // Title and subtitle in clean vertical column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: mode.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: mode.color.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
