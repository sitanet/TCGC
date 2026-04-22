import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';

class CallPage extends StatefulWidget {
  final String channelName;
  final String callerName;
  final String? callerPhoto;
  final bool isVideo;
  final bool isIncoming;
  final int remoteUserId; // backend user id for signaling

  const CallPage({
    super.key,
    required this.channelName,
    required this.callerName,
    this.callerPhoto,
    this.isVideo = false,
    this.isIncoming = false,
    required this.remoteUserId,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  RtcEngine? _engine;
  bool _joined = false;
  bool _remoteJoined = false;
  bool _muted = false;
  bool _speakerOn = true;
  bool _videoOff = false;
  int? _remoteUid;
  Duration _callDuration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // Request permissions
    await [Permission.microphone, if (widget.isVideo) Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: ApiConstants.agoraAppId));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        setState(() => _joined = true);
        _startTimer();
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        setState(() {
          _remoteUid = remoteUid;
          _remoteJoined = true;
        });
      },
      onUserOffline: (connection, remoteUid, reason) {
        setState(() {
          _remoteUid = null;
          _remoteJoined = false;
        });
        // End call when remote leaves
        Future.delayed(const Duration(seconds: 1), () => _endCall());
      },
    ));

    if (widget.isVideo) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    }

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.joinChannel(
      token: '',  // Use token server in production
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    await _engine?.leaveChannel();
    await _engine?.release();
    if (mounted) Navigator.pop(context);
  }

  void _toggleMute() async {
    setState(() => _muted = !_muted);
    await _engine?.muteLocalAudioStream(_muted);
  }

  void _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);
    await _engine?.setEnableSpeakerphone(_speakerOn);
  }

  void _toggleVideo() async {
    setState(() => _videoOff = !_videoOff);
    await _engine?.muteLocalVideoStream(_videoOff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0505),
      body: SafeArea(
        child: Stack(
          children: [
            // Video views
            if (widget.isVideo) ...[
              if (_remoteUid != null)
                AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: RtcConnection(channelId: widget.channelName),
                  ),
                ),
              if (!_videoOff)
                Positioned(
                  top: 16, right: 16,
                  child: SizedBox(
                    width: 100, height: 150,
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
            ],

            // Voice call UI
            if (!widget.isVideo || !_remoteJoined)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                      child: Text(
                        widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.bold,
                          color: AppColors.primaryGold),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(widget.callerName,
                        style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                      _joined && _remoteJoined
                          ? _formatDuration(_callDuration)
                          : _remoteJoined ? 'Connected' : 'Calling...',
                      style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),

            // Controls
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlBtn(
                        icon: _muted ? Icons.mic_off : Icons.mic,
                        label: _muted ? 'Unmute' : 'Mute',
                        onTap: _toggleMute,
                        active: _muted,
                      ),
                      _buildControlBtn(
                        icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                        label: 'Speaker',
                        onTap: _toggleSpeaker,
                        active: !_speakerOn,
                      ),
                      if (widget.isVideo)
                        _buildControlBtn(
                          icon: _videoOff ? Icons.videocam_off : Icons.videocam,
                          label: _videoOff ? 'Video Off' : 'Video',
                          onTap: _toggleVideo,
                          active: _videoOff,
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // End call button
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 72, height: 72,
                      decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 32),
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

  Widget _buildControlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
