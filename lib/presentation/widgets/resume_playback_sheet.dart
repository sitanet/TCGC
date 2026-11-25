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
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF211B11), Color(0xFF13100B)]
                : const [Color(0xFFFFFDF8), Color(0xFFF6EDD9)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppColors.primaryGold.withValues(alpha: isDark ? 0.45 : 0.35),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.16),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Hero artwork + title + close button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.5),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.5),
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: sermon.imageUrl != null &&
                              sermon.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: sermon.imageUrl!,
                              cacheManager: CustomImageCacheManager.instance,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _buildPlaceholder(isDark),
                              errorWidget: (_, __, ___) =>
                                  _buildPlaceholder(isDark),
                            )
                          : _buildPlaceholder(isDark),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 12,
                                  color: AppColors.primaryGold,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'RESUME PLAYBACK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppColors.primaryGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: onClose,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sermon.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        speakerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Sleek inline progress bar
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: position.progress.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGold),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bookmark_rounded,
                          size: 14,
                          color: AppColors.primaryGold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stopped at ${position.formattedPosition}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$percentNum% of ${position.formattedDuration}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // PRIMARY BUTTON: Continue from saved position
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onContinue();
                },
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF3C65F),
                        AppColors.primaryGold,
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
                      const Icon(
                        Icons.play_arrow_rounded,
                        size: 24,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Continue from ${position.formattedPosition}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // SECONDARY BUTTON: Start Over
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onStartOver();
                },
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.replay_rounded,
                        size: 18,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Start Over from Beginning',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
