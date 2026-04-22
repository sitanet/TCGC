import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';

class ListenTogetherPage extends ConsumerStatefulWidget {
  final int roomId;
  final ListenSession initialSession;
  final bool isHost;
  final String? myUserId;

  const ListenTogetherPage({
    super.key,
    required this.roomId,
    required this.initialSession,
    required this.isHost,
    this.myUserId,
  });

  @override
  ConsumerState<ListenTogetherPage> createState() => _ListenTogetherPageState();
}

class _ListenTogetherPageState extends ConsumerState<ListenTogetherPage> {
  final AudioPlayer _player = AudioPlayer();
  ListenSession? _session;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _syncTimer;
  // Prevent feedback loop: ignore remote state briefly after local seek
  DateTime? _lastLocalAction;
  static const _localActionCooldown = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(_session!.audioUrl);
      setState(() => _isLoading = false);

      if (widget.isHost) {
        // Host: push state every 2s
        _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pushState());
        // Listen to player events to push immediately on play/pause
        _player.playingStream.listen((_) => _pushState());
      } else {
        // Listener: poll every 2s and mirror host state
        _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollAndSync());
      }

      // Seek to where host is
      if (_session!.positionSeconds > 0) {
        await _player.seek(Duration(milliseconds: (_session!.positionSeconds * 1000).round()));
      }
      if (_session!.isPlaying) await _player.play();
    } catch (e) {
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _pushState() async {
    if (!mounted || _session == null) return;
    final pos = _player.position.inMilliseconds / 1000.0;
    await ref.read(communityChangeNotifierProvider).pushPlaybackState(
      widget.roomId,
      isPlaying: _player.playing,
      positionSeconds: pos,
      resourceType: _session!.resourceType,
      resourceId: _session!.resourceId,
      resourceTitle: _session!.resourceTitle,
      audioUrl: _session!.audioUrl,
    );
  }

  Future<void> _pollAndSync() async {
    if (!mounted) return;
    // Skip sync briefly after user manually interacted (host only, but guard anyway)
    if (_lastLocalAction != null &&
        DateTime.now().difference(_lastLocalAction!) < _localActionCooldown) return;

    final session = await ref.read(communityChangeNotifierProvider).pollListenSession(widget.roomId);
    if (!mounted || session == null || !session.isActive) return;

    setState(() => _session = session);

    // Sync position if drift > 3 seconds
    final remotePosMs = (session.positionSeconds * 1000).round();
    final localPosMs = _player.position.inMilliseconds;
    if ((remotePosMs - localPosMs).abs() > 3000) {
      await _player.seek(Duration(milliseconds: remotePosMs));
    }

    // Sync play/pause
    if (session.isPlaying && !_player.playing) {
      await _player.play();
    } else if (!session.isPlaying && _player.playing) {
      await _player.pause();
    }
  }

  Future<void> _togglePlayPause() async {
    if (!widget.isHost) return; // only host controls playback
    _lastLocalAction = DateTime.now();
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    await _pushState();
  }

  Future<void> _seekTo(double seconds) async {
    if (!widget.isHost) return;
    _lastLocalAction = DateTime.now();
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
    await _pushState();
  }

  Future<void> _endSession() async {
    _syncTimer?.cancel();
    if (widget.isHost) {
      await ref.read(communityChangeNotifierProvider).endListenSession(widget.roomId);
    }
    await _player.stop();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session ?? widget.initialSession;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
          onPressed: _endSession,
        ),
        title: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              widget.isHost ? 'Listening Together · Host' : 'Listening with ${session.hostName}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : _hasError
              ? _buildError()
              : _buildPlayer(session),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text('Could not load audio', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          TextButton(onPressed: _endSession, child: const Text('Go back')),
        ],
      ),
    );
  }

  Widget _buildPlayer(ListenSession session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Album art placeholder
          Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.headphones, size: 80, color: AppColors.primaryGold),
          ),
          const SizedBox(height: 40),

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
            widget.isHost ? 'You are controlling playback' : '${session.hostName} is controlling playback',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 40),

          // Progress bar
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = _player.duration ?? Duration.zero;
              final progress = duration.inMilliseconds > 0
                  ? position.inMilliseconds / duration.inMilliseconds
                  : 0.0;

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primaryGold,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: widget.isHost ? AppColors.primaryGold : Colors.transparent,
                      thumbShape: widget.isHost
                          ? const RoundSliderThumbShape(enabledThumbRadius: 8)
                          : const RoundSliderThumbShape(enabledThumbRadius: 0),
                      overlayColor: AppColors.primaryGold.withValues(alpha: 0.2),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: widget.isHost
                          ? (v) => _seekTo(v * (duration.inMilliseconds / 1000.0))
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
              );
            },
          ),
          const SizedBox(height: 32),

          // Play/Pause — only host can tap
          StreamBuilder<bool>(
            stream: _player.playingStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              return GestureDetector(
                onTap: widget.isHost ? _togglePlayPause : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: widget.isHost
                        ? AppColors.primaryGold
                        : AppColors.primaryGold.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    boxShadow: widget.isHost
                        ? [BoxShadow(color: AppColors.primaryGold.withValues(alpha: 0.4), blurRadius: 20)]
                        : [],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              );
            },
          ),

          if (!widget.isHost) ...[
            const SizedBox(height: 16),
            const Text(
              'Waiting for host to control playback',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],

          const SizedBox(height: 48),

          // Leave button
          TextButton.icon(
            onPressed: _endSession,
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 18),
            label: Text(
              widget.isHost ? 'End Session' : 'Leave Session',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
