import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api_service.dart';
import '../../../main.dart';
import '../../widgets/app_image.dart';

class GroupCallPage extends ConsumerStatefulWidget {
  final CommunityRoom room;
  final String callType; // 'audio' or 'video'
  final bool isJoiningExisting;

  const GroupCallPage({
    super.key,
    required this.room,
    this.callType = 'audio',
    this.isJoiningExisting = false,
  });

  @override
  ConsumerState<GroupCallPage> createState() => _GroupCallPageState();
}

class _GroupCallPageState extends ConsumerState<GroupCallPage> {
  final ApiService _api = ApiService();
  RtcEngine? _engine;
  String? _channelName;
  int _localUid = 0;

  bool _isConnecting = true;
  String? _errorText;
  bool _muted = false;
  bool _speakerOn = true;
  late bool _videoEnabled;

  final Set<int> _remoteUids = {};
  final Set<int> _speakingUids = {};
  Map<int, Map<String, dynamic>> _participantMeta = {};

  Timer? _durationTimer;
  Timer? _heartbeatTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _videoEnabled = widget.callType == 'video';
    _speakerOn = widget.callType == 'video';
    WakelockPlus.enable();
    _startOrJoinCall();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _heartbeatTimer?.cancel();
    WakelockPlus.disable();
    _cleanupEngineAndLeave();
    super.dispose();
  }

  Future<void> _cleanupEngineAndLeave() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    try {
      await _api.post(ApiConstants.communityGroupCall(widget.room.id), {
        'action': 'leave',
      });
    } catch (_) {}
  }

  Future<void> _startOrJoinCall() async {
    try {
      final permissions = <Permission>[Permission.microphone];
      if (_videoEnabled) permissions.add(Permission.camera);
      final statuses = await permissions.request();

      if (statuses[Permission.microphone]?.isGranted != true) {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _errorText = 'Microphone permission is required for group calls.';
          });
        }
        return;
      }

      final res = await _api.post(
        ApiConstants.communityGroupCall(widget.room.id),
        {
          'action': widget.isJoiningExisting ? 'join' : 'start',
          'call_type': widget.callType,
        },
      );

      if (!res.isSuccess) {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _errorText = res.userFriendlyError;
          });
        }
        return;
      }

      final data = res.data;
      final appId = (data['app_id'] ?? '').toString();
      final token = (data['token'] ?? '').toString();
      final channelName = (data['channel_name'] ?? '').toString();
      final uid = int.tryParse((data['uid'] ?? 0).toString()) ?? 0;

      if (appId.isEmpty || token.isEmpty || channelName.isEmpty) {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _errorText = 'Call server did not return valid Agora credentials.';
          });
        }
        return;
      }

      _channelName = channelName;
      _localUid = uid;
      _syncParticipantMeta(data['call']);

      final engine = createAgoraRtcEngine();
      _engine = engine;

      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted) return;
            setState(() => _isConnecting = false);
            _startTimers();
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() => _remoteUids.add(remoteUid));
            _sendHeartbeat();
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() {
              _remoteUids.remove(remoteUid);
              _speakingUids.remove(remoteUid);
            });
          },
          onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
            if (!mounted) return;
            final active = <int>{};
            for (final s in speakers) {
              if ((s.volume ?? 0) > 15 && s.uid != null) {
                active.add(s.uid == 0 ? _localUid : s.uid!);
              }
            }
            setState(() {
              _speakingUids
                ..clear()
                ..addAll(active);
            });
          },
          onError: (err, msg) {
            debugPrint('Agora error $err: $msg');
          },
        ),
      );

      await engine.enableAudio();
      await engine.enableAudioVolumeIndication(
        interval: 400,
        smooth: 3,
        reportVad: true,
      );
      await engine.setEnableSpeakerphone(_speakerOn);

      if (_videoEnabled) {
        await engine.enableVideo();
        await engine.startPreview();
      }

      await engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: _videoEnabled,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorText = 'Could not connect to call: $e';
        });
      }
    }
  }

  void _syncParticipantMeta(dynamic callJson) {
    if (callJson is! Map) return;
    final list = callJson['participants'];
    if (list is! List) return;
    final map = <int, Map<String, dynamic>>{};
    for (final item in list) {
      if (item is Map) {
        final id = int.tryParse((item['id'] ?? '').toString());
        if (id != null) {
          map[id] = Map<String, dynamic>.from(item);
        }
      }
    }
    if (mounted) {
      setState(() => _participantMeta = map);
    }
  }

  void _startTimers() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) => _sendHeartbeat());
  }

  Future<void> _sendHeartbeat() async {
    try {
      final res = await _api.post(
        ApiConstants.communityGroupCall(widget.room.id),
        {'action': 'heartbeat'},
      );
      if (res.isSuccess) {
        _syncParticipantMeta(res.data['active_call']);
      }
    } catch (_) {}
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    setState(() => _muted = next);
    await _engine?.muteLocalAudioStream(next);
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    setState(() => _speakerOn = next);
    await _engine?.setEnableSpeakerphone(next);
  }

  Future<void> _toggleVideo() async {
    final next = !_videoEnabled;
    if (next) {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) return;
      await _engine?.enableVideo();
      await _engine?.startPreview();
    } else {
      await _engine?.stopPreview();
      await _engine?.disableVideo();
    }
    setState(() => _videoEnabled = next);
    await _engine?.updateChannelMediaOptions(
      ChannelMediaOptions(publishCameraTrack: next),
    );
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> _leaveCall() async {
    if (mounted) Navigator.pop(context);
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authChangeNotifierProvider).user;
    final allUids = <int>[_localUid, ..._remoteUids];

    return Scaffold(
      backgroundColor: const Color(0xFF12100C),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _videoEnabled ? Icons.videocam_rounded : Icons.call_rounded,
                      color: AppColors.primaryGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.room.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _errorText != null
                              ? 'Call Unavailable'
                              : _isConnecting
                                  ? 'Connecting...'
                                  : '${allUids.length} in call • ${_formatElapsed(_elapsedSeconds)}',
                          style: const TextStyle(
                            color: AppColors.goldVariant2,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_videoEnabled && _engine != null)
                    IconButton(
                      tooltip: 'Flip Camera',
                      onPressed: _switchCamera,
                      icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                    ),
                ],
              ),
            ),

            // Participants grid or error
            Expanded(
              child: _errorText != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.call_end_rounded, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _errorText!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: _leaveCall,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGold,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _isConnecting
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppColors.primaryGold),
                              SizedBox(height: 14),
                              Text(
                                'Connecting to group call...',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(14),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: allUids.length <= 1 ? 1 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: allUids.length <= 1 ? 0.85 : 0.85,
                          ),
                          itemCount: allUids.length,
                          itemBuilder: (_, i) {
                            final uid = allUids[i];
                            final isLocal = uid == _localUid;
                            final isSpeaking = _speakingUids.contains(uid);
                            final meta = _participantMeta[uid];
                            final name = isLocal
                                ? '${me?.firstName ?? "You"} (You)'
                                : (meta?['name']?.toString() ?? 'Member');
                            final photo = isLocal
                                ? me?.photoUrl
                                : meta?['photo']?.toString();

                            return _buildParticipantTile(
                              uid: uid,
                              isLocal: isLocal,
                              name: name,
                              photoUrl: photo,
                              isSpeaking: isSpeaking,
                            );
                          },
                        ),
            ),

            // Bottom WhatsApp-style control bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1A12),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlBtn(
                    icon: _speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
                    label: _speakerOn ? 'Speaker' : 'Earpiece',
                    active: _speakerOn,
                    onTap: _toggleSpeaker,
                  ),
                  _controlBtn(
                    icon: _videoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    label: 'Video',
                    active: _videoEnabled,
                    onTap: _toggleVideo,
                  ),
                  _controlBtn(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _muted ? 'Muted' : 'Mute',
                    active: _muted,
                    onTap: _toggleMute,
                  ),
                  GestureDetector(
                    onTap: _leaveCall,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Leave',
                          style: TextStyle(color: Colors.redAccent, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantTile({
    required int uid,
    required bool isLocal,
    required String name,
    String? photoUrl,
    required bool isSpeaking,
  }) {
    final showVideo = isLocal ? _videoEnabled : widget.callType == 'video';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1810),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSpeaking
              ? AppColors.primaryGold
              : Colors.white.withValues(alpha: 0.1),
          width: isSpeaking ? 2.4 : 1,
        ),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.28),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showVideo && _engine != null && _channelName != null)
              AgoraVideoView(
                controller: isLocal
                    ? VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      )
                    : VideoViewController.remote(
                        rtcEngine: _engine!,
                        canvas: VideoCanvas(uid: uid),
                        connection: RtcConnection(channelId: _channelName!),
                      ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                      child: photoUrl != null && photoUrl.isNotEmpty
                          ? ClipOval(
                              child: AppImage(imagePath: photoUrl, width: 72, height: 72),
                            )
                          : Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: AppColors.primaryGold,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSpeaking) ...[
                      const Icon(Icons.graphic_eq_rounded, color: AppColors.primaryGold, size: 14),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primaryGold
                  : Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active ? Colors.black : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? AppColors.primaryGold : Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
