import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../main.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../data/services/playback_position_service.dart';
import '../../domain/entities/sermon.dart';
import '../pages/audio/audio_player_page.dart';

/// Beautiful TCGC popup modal bottom sheet for resuming previous sermon playback
/// or starting over from the beginning.
class ResumePlaybackSheet extends StatelessWidget {
  final Sermon sermon;
  final PlaybackPosition position;
  final VoidCallback onContinue;
  final VoidCallback onStartOver;
  final VoidCallback onClose;

  const ResumePlaybackSheet({
    super.key,
    required this.sermon,
    required this.position,
    required this.onContinue,
    required this.onStartOver,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final speakerName = sermon.speaker != null && sermon.speaker!.trim().isNotEmpty
        ? sermon.speaker!.trim()
        : 'The CityGate Church';

    final percentNum = (position.progress * 100).clamp(0, 100).toInt();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
          border: Border.all(
            color: isDark
                ? AppColors.primaryGold.withValues(alpha: 0.2)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header row with badge and close button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        size: 14,
                        color: AppColors.primaryGold,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'CONTINUE LISTENING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.primaryGold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onClose,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Message Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Poster Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: sermon.imageUrl != null && sermon.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: sermon.imageUrl!,
                              cacheManager: CustomImageCacheManager.instance,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _buildPlaceholder(isDark),
                              errorWidget: (_, __, ___) => _buildPlaceholder(isDark),
                            )
                          : _buildPlaceholder(isDark),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title & Speaker
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sermon.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.mic_none_rounded,
                              size: 13,
                              color: AppColors.primaryGold,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                speakerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Progress Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bookmark_added_rounded,
                            size: 15,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Stopped at ${position.formattedPosition}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$percentNum% played',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: position.progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        position.formattedPosition,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGold,
                        ),
                      ),
                      Text(
                        position.formattedDuration,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // PRIMARY BUTTON: Continue where stopped
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onContinue();
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE5A93C),
                      Color(0xFFC6B36A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continue Where You Stopped (${position.formattedPosition})',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // SECONDARY BUTTON: Start Over
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onStartOver();
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.grey.shade300,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.replay_rounded,
                      size: 19,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Start Over (Play from Beginning)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.cardDark : AppColors.dividerLight,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 28,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

/// Helper class to handle tapping messages across the entire app
class ResumePlaybackHelper {
  /// When tapping any message, checks if it was played before.
  /// If it has saved playback progress, shows the beautiful popup.
  /// Otherwise, immediately links to the player and starts playback.
  static Future<void> handleMessageTap({
    required BuildContext context,
    required WidgetRef ref,
    required Sermon sermon,
    List<Sermon>? queue,
    int? queueIndex,
    bool isLocked = false,
    VoidCallback? onLockedTap,
  }) async {
    if (isLocked) {
      if (onLockedTap != null) onLockedTap();
      return;
    }

    final audioProvider = ref.read(audioPlayerChangeNotifierProvider);

    // If this sermon is already currently playing/loading in the audio player,
    // link straight to the player without prompting
    if (audioProvider.currentSermon?.id == sermon.id &&
        (audioProvider.isPlaying || audioProvider.isLoading)) {
      if (queue != null && queueIndex != null) {
        audioProvider.setQueue(queue, queueIndex);
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AudioPlayerPage(sermon: sermon),
        ),
      );
      return;
    }

    final savedPosition = audioProvider.getSavedPosition(sermon.id);

    // If message was played before and has significant progress:
    if (savedPosition != null && savedPosition.isSignificant) {
      showResumeSheet(
        context: context,
        sermon: sermon,
        position: savedPosition,
        onContinue: () {
          if (queue != null && queueIndex != null) {
            audioProvider.setQueue(queue, queueIndex);
          }
          audioProvider.playSermonFromPosition(sermon, savedPosition.position);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AudioPlayerPage(
                sermon: sermon,
                initialPosition: savedPosition.position,
              ),
            ),
          );
        },
        onStartOver: () {
          if (queue != null && queueIndex != null) {
            audioProvider.setQueue(queue, queueIndex);
          }
          audioProvider.clearSavedPosition(sermon.id);
          audioProvider.playSermon(sermon);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AudioPlayerPage(
                sermon: sermon,
                startFromBeginning: true,
                initialPosition: Duration.zero,
              ),
            ),
          );
        },
      );
    } else {
      // Normal playback
      if (queue != null && queueIndex != null) {
        audioProvider.setQueue(queue, queueIndex);
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AudioPlayerPage(sermon: sermon),
        ),
      );
    }
  }

  /// Displays the modal bottom sheet popup
  static Future<void> showResumeSheet({
    required BuildContext context,
    required Sermon sermon,
    required PlaybackPosition position,
    required VoidCallback onContinue,
    required VoidCallback onStartOver,
    VoidCallback? onDismiss,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (sheetContext) => ResumePlaybackSheet(
        sermon: sermon,
        position: position,
        onContinue: () {
          Navigator.pop(sheetContext);
          onContinue();
        },
        onStartOver: () {
          Navigator.pop(sheetContext);
          onStartOver();
        },
        onClose: () {
          Navigator.pop(sheetContext);
          if (onDismiss != null) onDismiss();
        },
      ),
    );
  }
}
