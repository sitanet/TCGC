import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/listen_together_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';

class ListenTogetherPage extends ConsumerWidget {
  final int roomId;

  const ListenTogetherPage({
    super.key,
    required this.roomId,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) {
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  void _confirmEndSession(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('End Listen Session?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will stop playback and end the session for all members in this room.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(listenTogetherProvider.notifier).endSession();
              Navigator.pop(context);
            },
            child: const Text('End for All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveSession(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Leave Listen Session?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'You will stop listening, but the session will remain active for others.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final me = ref.read(authChangeNotifierProvider).user;
              final memberName = (me?.fullName ?? '').trim().isNotEmpty
                  ? me!.fullName.trim()
                  : 'A member';
              await ref.read(listenTogetherProvider.notifier).leaveSession();
              await ref.read(communityChangeNotifierProvider).sendMessage(
                roomId,
                '🎧 $memberName left listening',
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(listenTogetherProvider);
    final session = state.session;

    if (!state.isJoined || session == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.headphones_outlined, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              const Text('Session has ended', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
                onPressed: () => Navigator.pop(context),
                child: const Text('Return to Chat', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final isHost = state.isHost;
    final position = state.position;
    final duration = state.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Minimize to Chat',
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context), // Pops back to chat room without stopping audio!
        ),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isHost ? 'Listening Together · Host' : 'Listening with ${session.hostName}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chat Room',
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primaryGold, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : state.hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      const Text('Could not load audio', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go back')),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Album art placeholder
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35), width: 2),
                        ),
                        child: const Icon(Icons.headphones_rounded, size: 80, color: AppColors.primaryGold),
                      ),
                      const SizedBox(height: 36),

                      // Title
                      Text(
                        session.resourceTitle.isNotEmpty ? session.resourceTitle : 'Audio Message',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isHost ? 'You are controlling playback for the room' : '${session.hostName} is controlling playback',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 32),

                      // Progress bar
                      Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.primaryGold,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: isHost ? AppColors.primaryGold : Colors.transparent,
                              thumbShape: isHost
                                  ? const RoundSliderThumbShape(enabledThumbRadius: 8)
                                  : const RoundSliderThumbShape(enabledThumbRadius: 0),
                              overlayColor: AppColors.primaryGold.withValues(alpha: 0.2),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: progress,
                              onChanged: isHost
                                  ? (v) {
                                      final targetMs = (v * duration.inMilliseconds).round();
                                      ref.read(listenTogetherProvider.notifier).seek(Duration(milliseconds: targetMs));
                                    }
                                  : null,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position),
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                Text(_formatDuration(duration),
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Play/Pause button
                      GestureDetector(
                        onTap: isHost
                            ? () => ref.read(listenTogetherProvider.notifier).togglePlayPause()
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: isHost
                                ? AppColors.primaryGold
                                : AppColors.primaryGold.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                            boxShadow: isHost
                                ? [BoxShadow(color: AppColors.primaryGold.withValues(alpha: 0.4), blurRadius: 20)]
                                : [],
                          ),
                          child: Icon(
                            state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 38,
                          ),
                        ),
                      ),

                      if (!isHost) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Synced with host playback · Swipe down to return to chat',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Swipe down to return to chat (playback stays live)',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],

                      const SizedBox(height: 36),

                      // Leave / End button
                      TextButton.icon(
                        onPressed: () {
                          if (isHost) {
                            _confirmEndSession(context, ref);
                          } else {
                            _confirmLeaveSession(context, ref);
                          }
                        },
                        icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 18),
                        label: Text(
                          isHost ? 'End Session for Everyone' : 'Leave Session',
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
