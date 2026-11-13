import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../widgets/app_image.dart';
import 'listen_together_page.dart';
import '../../../core/providers/listen_together_provider.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/sermon.dart';
class ChatRoomPage extends ConsumerStatefulWidget {
  final CommunityRoom room;
  final String? dmUserName;
  final String? dmUserPhoto;
  final int? dmUserId;
  final bool? dmUserOnline;
  final String? dmUserLastSeen;

  const ChatRoomPage({
    super.key,
    required this.room,
    this.dmUserName,
    this.dmUserPhoto,
    this.dmUserId,
    this.dmUserOnline,
    this.dmUserLastSeen,
  });

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  ListenSession? _activeSession;
  Timer? _sessionPollTimer;
  ChatMessage? _replyingTo;

  // Voice note recording & playback
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordingPath;
  bool _hasText = false;

  final AudioPlayer _voicePlayer = AudioPlayer();
  int? _playingVoiceMsgId;
  bool _voicePlaying = false;
  Duration _voicePos = Duration.zero;
  Duration _voiceDur = Duration.zero;
  StreamSubscription? _voicePosSub;
  StreamSubscription? _voiceDurSub;
  StreamSubscription? _voiceStateSub;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText && mounted) setState(() => _hasText = has);
    });
    _voicePosSub = _voicePlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _voicePos = pos);
    });
    _voiceDurSub = _voicePlayer.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _voiceDur = dur);
    });
    _voiceStateSub = _voicePlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _voicePlaying = false;
          _voicePos = Duration.zero;
          _playingVoiceMsgId = null;
        });
      } else {
        setState(() => _voicePlaying = state.playing);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = ref.read(communityChangeNotifierProvider);
      p.fetchMessages(widget.room.id);
      p.startPolling(widget.room.id);
      _startSessionPolling();
    });
  }

  void _startSessionPolling() {
    _sessionPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final session = await ref.read(communityChangeNotifierProvider)
          .pollListenSession(widget.room.id);
      if (mounted) setState(() => _activeSession = session);
    });
  }

  @override
  void dispose() {
    _sessionPollTimer?.cancel();
    _recordTimer?.cancel();
    _voicePosSub?.cancel();
    _voiceDurSub?.cancel();
    _voiceStateSub?.cancel();
    _recorder.dispose();
    _voicePlayer.dispose();
    ref.read(communityChangeNotifierProvider).stopPolling();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showAttachmentOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _attachOption(
                      icon: Icons.headphones_rounded,
                      label: 'Listen\nTogether',
                      color: AppColors.primaryGold,
                      onTap: () { Navigator.pop(ctx); _openSermonPickerForListenTogether(); },
                    ),
                  ),
                  Expanded(
                    child: _attachOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: Colors.purple,
                      onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
                    ),
                  ),
                  Expanded(
                    child: _attachOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: Colors.blue,
                      onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
                    ),
                  ),
                  Expanded(
                    child: _attachOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document',
                      color: Colors.orange,
                      onTap: () { Navigator.pop(ctx); _pickDocument(); },
                    ),
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

  Widget _attachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              )),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      debugPrint('=== PICKING IMAGE ===');
      debugPrint('Source: $source');
      
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      
      if (picked == null) {
        debugPrint('Image picker cancelled by user');
        return;
      }
      
      debugPrint('Image picked: ${picked.path}');
      final file = File(picked.path);
      
      if (!file.existsSync()) {
        debugPrint('ERROR: File does not exist at path: ${picked.path}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File not found'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      debugPrint('File exists, size: ${file.lengthSync()} bytes');
      await _sendFile(file, 'image');
    } catch (e, stackTrace) {
      debugPrint('ERROR picking image: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      debugPrint('=== PICKING DOCUMENT ===');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
      );
      
      if (result == null || result.files.single.path == null) {
        debugPrint('Document picker cancelled by user');
        return;
      }
      
      debugPrint('Document picked: ${result.files.single.path}');
      final file = File(result.files.single.path!);
      
      if (!file.existsSync()) {
        debugPrint('ERROR: File does not exist at path: ${result.files.single.path}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File not found'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      debugPrint('File exists, size: ${file.lengthSync()} bytes');
      await _sendFile(file, 'document');
    } catch (e, stackTrace) {
      debugPrint('ERROR picking document: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick document: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendFile(File file, String fileType) async {
    debugPrint('=== SENDING FILE ===');
    debugPrint('File path: ${file.path}');
    debugPrint('File type: $fileType');
    debugPrint('Room ID: ${widget.room.id}');
    
    final replyToId = _replyingTo?.id;
    setState(() {
      _isSending = true;
      _replyingTo = null;
    });
    
    try {
      final p = ref.read(communityChangeNotifierProvider);
      final success = await p.sendFileMessage(widget.room.id, file, fileType, replyToId: replyToId);
      
      debugPrint('Send file result: $success');
      
      if (mounted) {
        setState(() => _isSending = false);
        if (!success) {
          final error = p.error ?? 'Failed to send file';
          debugPrint('Send file error: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        } else {
          debugPrint('File sent successfully');
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR sending file: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final replyToId = _replyingTo?.id;
    setState(() {
      _isSending = true;
      _replyingTo = null;
    });
    _textController.clear();

    final p = ref.read(communityChangeNotifierProvider);
    await p.sendMessage(widget.room.id, text, replyToId: replyToId);

    setState(() => _isSending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _startRecording() async {
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required to record voice notes.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (_voicePlaying) {
        await _voicePlayer.pause();
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: path,
      );

      _recordTimer?.cancel();
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _recordingPath = path;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      debugPrint('_startRecording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (_recordingPath != null) {
      try {
        final f = File(_recordingPath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
        _recordingPath = null;
      });
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      debugPrint('_stopAndSendRecording stop error: $e');
    }
    final durationSecs = _recordSeconds;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
        _recordingPath = null;
      });
    }
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync() || durationSecs < 1) {
      if (file.existsSync()) {
        try { file.deleteSync(); } catch (_) {}
      }
      if (mounted && durationSecs < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hold or record for at least 1 second.'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }
    await _sendFile(file, 'voice');
  }

  Future<void> _toggleVoiceNote(ChatMessage msg) async {
    if (msg.fileUrl == null || msg.fileUrl!.isEmpty) return;
    try {
      final isAudioMessagePlaying = ref.read(listenTogetherProvider).isPlaying ||
          ref.read(audioPlayerChangeNotifierProvider).isPlaying;

      if (_playingVoiceMsgId == msg.id && _voicePlaying) {
        await _voicePlayer.pause();
        return;
      }

      if (isAudioMessagePlaying) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Stop the playing audio message first before playing a voice note.'),
              backgroundColor: Colors.orange[800],
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (_playingVoiceMsgId == msg.id) {
        await _voicePlayer.play();
        return;
      }
      setState(() {
        _playingVoiceMsgId = msg.id;
        _voicePos = Duration.zero;
        _voiceDur = Duration.zero;
      });
      await _voicePlayer.setUrl(msg.fileUrl!);
      await _voicePlayer.play();
    } catch (e) {
      debugPrint('_toggleVoiceNote error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play voice note.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = ref.watch(communityChangeNotifierProvider);
    final me = ref.read(authChangeNotifierProvider).user;
    final listenState = ref.watch(listenTogetherProvider);

    // Audio message has priority over voice notes: pause any playing voice note if audio message starts
    ref.listen<ListenTogetherNotifier>(listenTogetherProvider, (_, next) {
      if (next.isPlaying && _voicePlaying) {
        _voicePlayer.pause();
      }
    });
    ref.listen(audioPlayerChangeNotifierProvider, (_, next) {
      if (next.isPlaying && _voicePlaying) {
        _voicePlayer.pause();
      }
    });

    // Scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F6F0),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.primaryGold.withValues(alpha: 0.16),
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: widget.dmUserName != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (widget.dmUserPhoto != null) ...[
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                        child: ClipOval(child: AppImage(imagePath: widget.dmUserPhoto!, width: 32, height: 32)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(widget.dmUserName!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87)),
                    ),
                  ]),
                  Text(
                    widget.dmUserOnline == true
                        ? 'Online'
                        : formatLastSeen(widget.dmUserLastSeen),
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.dmUserOnline == true
                          ? Colors.green
                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.forum_rounded, color: AppColors.primaryGold, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.room.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87)),
                        if (widget.room.description != null && widget.room.description!.isNotEmpty)
                          Text(widget.room.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          if (widget.dmUserName == null)
            IconButton(
              tooltip: 'Listen Together',
              icon: const Icon(Icons.headphones_rounded, color: AppColors.primaryGold),
              onPressed: _openSermonPickerForListenTogether,
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.primaryGold),
            onPressed: () => p.fetchMessages(widget.room.id),
          ),
        ],
      ),
      body: Column(
        children: [
          // Active listen-together session docked player or join banner
          if (listenState.isJoined &&
              listenState.session != null &&
              listenState.currentRoomId == widget.room.id)
            _buildDockedPlayer(listenState, isDark)
          else if (_activeSession != null && _activeSession!.isActive)
            _buildJoinBanner(_activeSession!, isDark),
          // Messages
          Expanded(
            child: p.isLoading && p.messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
                : p.messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: p.messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = p.messages[i];
                          final isMe = me != null && msg.senderId == int.tryParse(me.id);
                          final showAvatar = i == 0 ||
                              p.messages[i - 1].senderId != msg.senderId;
                          final showDate = i == 0 ||
                              !_isSameDay(p.messages[i - 1].createdAt, msg.createdAt);
                          return Column(
                            children: [
                              if (showDate) _buildDateDivider(msg.createdAt, isDark),
                              _buildMessageBubble(context, isDark, msg, isMe, showAvatar, me?.id),
                            ],
                          );
                        },
                      ),
          ),
          // Reply preview bar
          if (_replyingTo != null) _buildReplyPreviewBar(isDark),
          // Input bar
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  void _showEndSessionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('End Session for All?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will stop playback and end the listening session for everyone in the room.',
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
            },
            child: const Text('End for All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDockedPlayer(ListenTogetherNotifier listenState, bool isDark) {
    final session = listenState.session;
    if (session == null) return const SizedBox.shrink();

    final isHost = listenState.isHost;
    final position = listenState.position;
    final duration = listenState.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Play/Pause button (host controls playback for everyone)
              GestureDetector(
                onTap: listenState.isHost
                    ? () => ref.read(listenTogetherProvider.notifier).togglePlayPause()
                    : null,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: listenState.isHost
                        ? AppColors.primaryGold
                        : AppColors.primaryGold.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    boxShadow: listenState.isHost
                        ? [
                            BoxShadow(
                              color: AppColors.primaryGold.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    listenState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Titles and host info
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ListenTogetherPage(roomId: widget.room.id),
                    ));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              session.resourceTitle.isNotEmpty ? session.resourceTitle : 'Sermon Audio',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isHost
                            ? 'You are hosting · ${_formatDuration(position)} / ${_formatDuration(duration)}'
                            : '${session.hostName} hosting · ${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.primaryGold, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // Fullscreen/Expand button
              IconButton(
                tooltip: 'Fullscreen Player',
                icon: const Icon(Icons.open_in_full_rounded, color: AppColors.primaryGold, size: 19),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ListenTogetherPage(roomId: widget.room.id),
                  ));
                },
              ),
              // Leave / End button
              IconButton(
                tooltip: isHost ? 'End Session' : 'Leave Session',
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                onPressed: () {
                  if (isHost) {
                    _showEndSessionDialog();
                  } else {
                    ref.read(listenTogetherProvider.notifier).leaveSession();
                  }
                },
              ),
            ],
          ),
          // Mini progress bar
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
                minHeight: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinBanner(ListenSession session, bool isDark) {
    final me = ref.read(authChangeNotifierProvider).user;
    final isHost = me != null && session.hostId.toString() == me.id;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.headphones_rounded, color: AppColors.primaryGold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHost ? 'Your listen session is live' : '${session.hostName} started a listen session',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  session.resourceTitle.isNotEmpty ? session.resourceTitle : 'Listen Together',
                  style: const TextStyle(fontSize: 11, color: AppColors.primaryGold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(
              isHost ? 'Open' : 'Join',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              await ref.read(listenTogetherProvider.notifier).joinAsListener(
                roomId: widget.room.id,
                session: session,
                myUserId: int.tryParse(me?.id ?? '0') ?? 0,
              );
              if (!isHost) {
                final memberName = (me?.fullName ?? '').trim().isNotEmpty
                    ? me!.fullName.trim()
                    : 'A member';
                await ref.read(communityChangeNotifierProvider).sendMessage(
                  widget.room.id,
                  '🎧 $memberName joined to listen',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryGold.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 36, color: AppColors.primaryGold),
            ),
            const SizedBox(height: 18),
            Text('No messages yet',
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 6),
            Text(
              'Start the conversation or tap the headphones icon to listen to a sermon together.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
            if (widget.dmUserName == null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGold,
                  side: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: _openSermonPickerForListenTogether,
                icon: const Icon(Icons.headphones_rounded, size: 18),
                label: const Text('Host a Sermon', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateDivider(DateTime date, bool isDark) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : AppColors.primaryGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  String _messagePreviewText(ChatMessage msg) {
    if (msg.isDeleted) return '🚫 Message deleted';
    if (msg.fileType == 'voice') return '🎤 Voice note';
    if (msg.fileType == 'image') return '📷 Photo';
    if (msg.hasFile) return '📎 ${msg.fileName ?? "File"}';
    if (msg.hasResource) return '🎧 ${msg.resourceTitle ?? "Shared resource"}';
    return msg.text;
  }

  Widget _buildReplyPreviewBar(bool isDark) {
    final target = _replyingTo;
    if (target == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${target.senderName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _messagePreviewText(target),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: isDark ? AppColors.textSecondaryDark : Colors.black54,
            ),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, bool isDark, ChatMessage msg,
      bool isMe, bool showAvatar, String? myId) {
    if (!msg.isDeleted &&
        msg.text.startsWith('🎧 ') &&
        msg.text.endsWith(' joined to listen')) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryGold.withValues(alpha: isDark ? 0.16 : 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            msg.text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.primaryGold : const Color(0xFF7A5610),
            ),
          ),
        ),
      );
    }
    return Dismissible(
      key: ValueKey('msg_${msg.id}'),
      direction: msg.isDeleted ? DismissDirection.none : DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        setState(() => _replyingTo = msg);
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.reply_rounded, color: AppColors.primaryGold, size: 22),
      ),
      child: GestureDetector(
        onDoubleTap: !msg.isDeleted
            ? () => ref.read(communityChangeNotifierProvider).toggleReaction(msg.id, '❤️')
            : null,
        onLongPress: !msg.isDeleted
            ? () => _showMessageOptions(context, msg, isMe)
            : null,
        child: Padding(
        padding: EdgeInsets.only(
          bottom: 4,
          left: isMe ? 48 : 0,
          right: isMe ? 0 : 48,
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar (other users only)
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: showAvatar
                    ? CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                        child: msg.senderPhoto != null
                            ? ClipOval(child: AppImage(imagePath: msg.senderPhoto!, width: 32, height: 32))
                            : Text(
                                msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppColors.primaryGold,
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                      )
                    : const SizedBox(width: 32),
              ),

            // Bubble
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3, left: 4),
                      child: Text(msg.senderName,
                          style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.primaryGold)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [AppColors.primaryGold, Color(0xFFB8941F)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isMe
                          ? null
                          : (isDark ? AppColors.cardDark : Colors.white),
                      border: isMe
                          ? null
                          : Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isMe
                              ? AppColors.primaryGold.withValues(alpha: 0.22)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.replyToId != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.black.withValues(alpha: 0.14)
                                  : AppColors.primaryGold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border(
                                left: BorderSide(
                                  color: isMe ? Colors.white : AppColors.primaryGold,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.reply_rounded,
                                      size: 13,
                                      color: isMe ? Colors.white : AppColors.primaryGold,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        msg.replyToSender ?? 'Member',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isMe ? Colors.white : AppColors.primaryGold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  msg.replyToText ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : (isDark ? Colors.white70 : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        msg.hasResource
                            ? _buildResourceCard(isDark, msg, isMe)
                            : msg.hasFile
                                ? _buildFileCard(isDark, msg, isMe)
                                : Text(
                                    msg.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isMe
                                          ? Colors.white
                                          : (isDark ? Colors.white : Colors.black87),
                                      fontStyle: msg.isDeleted ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                      ],
                    ),
                  ),
                  if (msg.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
                        children: msg.reactions.map((r) {
                          return GestureDetector(
                            onTap: () => ref
                                .read(communityChangeNotifierProvider)
                                .toggleReaction(msg.id, r.emoji),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: r.reacted
                                    ? AppColors.primaryGold.withValues(alpha: 0.22)
                                    : (isDark ? AppColors.cardDark : Colors.white),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: r.reacted
                                      ? AppColors.primaryGold
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.08)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(r.emoji, style: const TextStyle(fontSize: 13)),
                                  if (r.count > 1) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '${r.count}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: r.reacted
                                            ? AppColors.primaryGold
                                            : (isDark ? Colors.white70 : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        Text(
                          _formatTime(msg.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        ),
                        if (isMe && !msg.isDeleted) ...[
                          const SizedBox(width: 4),
                          _buildReceiptIcon(msg),
                        ],
                      ],
                    ),
                  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✓ sent  ✓✓ delivered (grey)  ✓✓ seen (blue/gold)
  Widget _buildReceiptIcon(ChatMessage msg) {
    if (msg.isRead) {
      // Double tick — gold = seen
      return const Icon(Icons.done_all_rounded, size: 14, color: AppColors.primaryGold);
    } else if (msg.isDelivered) {
      // Double tick — grey = delivered
      return Icon(Icons.done_all_rounded, size: 14,
          color: Colors.grey.withValues(alpha: 0.7));
    } else {
      // Single tick — sent
      return Icon(Icons.done_rounded, size: 14,
          color: Colors.grey.withValues(alpha: 0.7));
    }
  }

  Widget _buildResourceCard(bool isDark, ChatMessage msg, bool isMe) {
    final iconMap = {'audio': Icons.headphones, 'event': Icons.event, 'transcript': Icons.article};
    final icon = iconMap[msg.resourceType] ?? Icons.link;
    final isAudio = msg.resourceType == 'audio';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (msg.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(msg.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87))),
          ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.2)
                : AppColors.primaryGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: isMe ? Colors.white : AppColors.primaryGold),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      msg.resourceTitle ?? msg.resourceType ?? 'Shared resource',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: isMe ? Colors.white : AppColors.primaryGold),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Listen Together button — only for audio resources
              if (isAudio && msg.resourceId != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _startListenTogether(msg),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppColors.primaryGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.headphones_rounded,
                            size: 14,
                            color: isMe ? Colors.white : Colors.black87),
                        const SizedBox(width: 6),
                        Text(
                          'Listen Together',
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: isMe ? Colors.white : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(bool isDark, ChatMessage msg, bool isMe) {
    final isImage = msg.fileType == 'image';
    final isVoice = msg.fileType == 'voice';
    final textColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final subColor = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Optional caption text
        if (msg.text.isNotEmpty) ...[
          Text(msg.text, style: TextStyle(fontSize: 14, color: textColor)),
          const SizedBox(height: 8),
        ],
        if (isVoice && msg.fileUrl != null)
          _buildVoiceNoteCard(isDark, msg, isMe, textColor, subColor)
        else if (isImage && msg.fileUrl != null)
          // Image preview
          GestureDetector(
            onTap: () => _showFullImage(msg.fileUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                msg.fileUrl!,
                width: 220,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        width: 220, height: 140,
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.15)
                              : AppColors.primaryGold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primaryGold, strokeWidth: 2),
                        ),
                      ),
                errorBuilder: (_, __, ___) => Container(
                  width: 220, height: 80,
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppColors.primaryGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined, color: subColor, size: 28),
                      const SizedBox(height: 4),
                      Text('Could not load image',
                          style: TextStyle(fontSize: 11, color: subColor)),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          // Document row
          GestureDetector(
            onTap: () => _openFile(msg.fileUrl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppColors.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _docIcon(msg.fileName),
                    color: isMe ? Colors.white : AppColors.primaryGold,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.fileName ?? 'Document',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text('Tap to open',
                            style: TextStyle(fontSize: 11, color: subColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVoiceNoteCard(bool isDark, ChatMessage msg, bool isMe, Color textColor, Color subColor) {
    final isActive = _playingVoiceMsgId == msg.id;
    final isPlaying = isActive && _voicePlaying;
    final pos = isActive ? _voicePos : Duration.zero;
    final dur = isActive ? _voiceDur : Duration.zero;
    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleVoiceNote(msg),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isMe ? Colors.white : AppColors.primaryGold,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isMe ? AppColors.primaryGold : Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: isMe
                        ? Colors.white.withValues(alpha: 0.3)
                        : AppColors.primaryGold.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMe ? Colors.white : AppColors.primaryGold,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.mic_rounded, size: 12, color: subColor),
                    const SizedBox(width: 4),
                    Text(
                      isActive && dur > Duration.zero
                          ? '${_formatDuration(pos)} / ${_formatDuration(dur)}'
                          : 'Voice note',
                      style: TextStyle(fontSize: 11, color: subColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _docIcon(String? fileName) {
    final ext = (fileName ?? '').split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx': return Icons.description_rounded;
      case 'xls':
      case 'xlsx': return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx': return Icons.slideshow_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  void _openFile(String? url) async {
    if (url == null) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open this file')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  Future<void> _startListenTogether(ChatMessage msg) async {
    if (msg.resourceId == null) return;

    final audioUrl = msg.resourceAudioUrl ?? '';
    if (audioUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio URL not available for this message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final me = ref.read(authChangeNotifierProvider).user;

    await ref.read(listenTogetherProvider.notifier).startAsHost(
      roomId: widget.room.id,
      resourceType: msg.resourceType!,
      resourceId: msg.resourceId!,
      resourceTitle: msg.resourceTitle ?? 'Audio Sermon',
      audioUrl: audioUrl,
      hostId: int.tryParse(me?.id ?? '0') ?? 0,
      hostName: me?.fullName ?? 'Host',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hosting "${msg.resourceTitle ?? 'Audio'}" live! Room members can now join.'),
        backgroundColor: AppColors.primaryGold,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openSermonPickerForListenTogether() async {
    final listenState = ref.read(listenTogetherProvider);
    final meId = int.tryParse(ref.read(authChangeNotifierProvider).user?.id ?? '');
    final active = (listenState.isJoined && listenState.currentRoomId == widget.room.id)
        ? listenState.session
        : _activeSession;

    if (active != null && active.isActive && active.hostId != meId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${active.hostName} is currently hosting in this room. You can host once they stop.'),
          backgroundColor: Colors.orange[800],
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dataService = DataService();
    final sermonsFuture = dataService.getMessages(forceRefresh: true);
    final searchController = TextEditingController();
    String searchQuery = '';
    String selectedCategory = 'All';
    String selectedSpeaker = 'All';
    bool sortNewestFirst = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.94,
              builder: (ctx, scrollCtrl) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(top: 10, bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.headphones_rounded, color: AppColors.primaryGold, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Start Listen Session',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Select a church sermon to listen with the room',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(sheetCtx),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: TextField(
                            controller: searchController,
                            onChanged: (val) => setSheetState(() => searchQuery = val.trim().toLowerCase()),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search sermons, speakers, or categories...',
                              hintStyle: TextStyle(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold, size: 20),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        searchController.clear();
                                        setSheetState(() => searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: FutureBuilder<List<Sermon>>(
                            future: sermonsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold));
                              }
                              final allSermons = (snapshot.data ?? [])
                                  .where((s) => s.audioUrl != null && s.audioUrl!.isNotEmpty)
                                  .toList();

                              final categories = <String>[
                                'All',
                                ...{
                                  for (final s in allSermons)
                                    if (s.categoryName.trim().isNotEmpty) s.categoryName.trim(),
                                }.toList()
                                  ..sort(),
                              ];
                              final speakers = <String>[
                                'All',
                                ...{
                                  for (final s in allSermons)
                                    if ((s.speaker ?? '').trim().isNotEmpty) s.speaker!.trim(),
                                }.toList()
                                  ..sort(),
                              ];

                              final sermons = allSermons.where((s) {
                                if (selectedCategory != 'All' &&
                                    s.categoryName.trim() != selectedCategory) {
                                  return false;
                                }
                                if (selectedSpeaker != 'All' &&
                                    (s.speaker ?? '').trim() != selectedSpeaker) {
                                  return false;
                                }
                                if (searchQuery.isEmpty) return true;
                                final title = s.title.toLowerCase();
                                final speaker = (s.speaker ?? '').toLowerCase();
                                final cat = s.categoryName.toLowerCase();
                                return title.contains(searchQuery) ||
                                    speaker.contains(searchQuery) ||
                                    cat.contains(searchQuery);
                              }).toList()
                                ..sort((a, b) => sortNewestFirst
                                    ? b.date.compareTo(a.date)
                                    : a.date.compareTo(b.date));

                              final hasActiveFilter = selectedCategory != 'All' ||
                                  selectedSpeaker != 'All' ||
                                  searchQuery.isNotEmpty;

                              return Column(
                                children: [
                                  if (categories.length > 1)
                                    SizedBox(
                                      height: 44,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                        itemCount: categories.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                                        itemBuilder: (_, idx) {
                                          final cat = categories[idx];
                                          final isSelected = selectedCategory == cat;
                                          return ChoiceChip(
                                            label: Text(
                                              cat,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                color: isSelected
                                                    ? Colors.black
                                                    : (isDark ? Colors.white70 : Colors.black87),
                                              ),
                                            ),
                                            selected: isSelected,
                                            selectedColor: AppColors.primaryGold,
                                            backgroundColor: isDark
                                                ? AppColors.backgroundDark
                                                : const Color(0xFFF2F2F2),
                                            side: BorderSide.none,
                                            visualDensity: VisualDensity.compact,
                                            onSelected: (_) => setSheetState(() => selectedCategory = cat),
                                          );
                                        },
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${sermons.length} ${sermons.length == 1 ? 'message' : 'messages'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (speakers.length > 2)
                                          PopupMenuButton<String>(
                                            initialValue: selectedSpeaker,
                                            onSelected: (val) => setSheetState(() => selectedSpeaker = val),
                                            itemBuilder: (_) => speakers
                                                .map((sp) => PopupMenuItem<String>(
                                                      value: sp,
                                                      child: Text(sp == 'All' ? 'All Speakers' : sp),
                                                    ))
                                                .toList(),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: selectedSpeaker != 'All'
                                                    ? AppColors.primaryGold.withValues(alpha: 0.18)
                                                    : (isDark ? AppColors.backgroundDark : const Color(0xFFF2F2F2)),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.person_outline,
                                                    size: 14,
                                                    color: selectedSpeaker != 'All'
                                                        ? AppColors.primaryGold
                                                        : (isDark ? Colors.white70 : Colors.black54),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  ConstrainedBox(
                                                    constraints: const BoxConstraints(maxWidth: 110),
                                                    child: Text(
                                                      selectedSpeaker == 'All' ? 'Speaker' : selectedSpeaker,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: selectedSpeaker != 'All'
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
                                                        color: selectedSpeaker != 'All'
                                                            ? AppColors.primaryGold
                                                            : (isDark ? Colors.white70 : Colors.black87),
                                                      ),
                                                    ),
                                                  ),
                                                  const Icon(Icons.arrow_drop_down, size: 16),
                                                ],
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () => setSheetState(() => sortNewestFirst = !sortNewestFirst),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: isDark ? AppColors.backgroundDark : const Color(0xFFF2F2F2),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.sort, size: 14, color: AppColors.primaryGold),
                                                const SizedBox(width: 4),
                                                Text(
                                                  sortNewestFirst ? 'Newest' : 'Oldest',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white70 : Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (hasActiveFilter) ...[
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () {
                                              searchController.clear();
                                              setSheetState(() {
                                                searchQuery = '';
                                                selectedCategory = 'All';
                                                selectedSpeaker = 'All';
                                              });
                                            },
                                            child: const Text(
                                              'Reset',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primaryGold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: sermons.isEmpty
                                        ? Center(
                                            child: Text(
                                              hasActiveFilter
                                                  ? 'No matching sermons found'
                                                  : 'No sermons available to play',
                                              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                                            ),
                                          )
                                        : ListView.separated(
                                            controller: scrollCtrl,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            itemCount: sermons.length,
                                            separatorBuilder: (_, __) => Divider(
                                              height: 1,
                                              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                                            ),
                                            itemBuilder: (context, idx) {
                                              final sermon = sermons[idx];
                                              return ListTile(
                                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                                leading: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    width: 44,
                                                    height: 44,
                                                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                                                    child: const Icon(Icons.music_note, color: AppColors.primaryGold),
                                                  ),
                                                ),
                                                title: Text(
                                                  sermon.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white : Colors.black87,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  [
                                                    if (sermon.speaker != null && sermon.speaker!.isNotEmpty)
                                                      sermon.speaker!,
                                                    if (sermon.categoryName.isNotEmpty) sermon.categoryName,
                                                  ].join(' • '),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGold,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Text(
                                        'Host',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    onTap: () async {
                                      Navigator.pop(sheetCtx);
                                      final me = ref.read(authChangeNotifierProvider).user;

                                      final ok = await ref.read(listenTogetherProvider.notifier).startAsHost(
                                        roomId: widget.room.id,
                                        resourceType: 'audio',
                                        resourceId: int.tryParse(sermon.id) ?? 0,
                                        resourceTitle: sermon.title,
                                        audioUrl: sermon.audioUrl!,
                                        hostId: int.tryParse(me?.id ?? '0') ?? 0,
                                        hostName: me?.fullName ?? 'Host',
                                      );

                                      if (!mounted) return;
                                      final errMsg = ref.read(listenTogetherProvider).errorMessage;
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ok
                                                ? 'Hosting "${sermon.title}" live! Room members can now join.'
                                                : (errMsg ?? 'Could not start hosting.'),
                                          ),
                                          backgroundColor: ok ? AppColors.primaryGold : Colors.red,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(searchController.dispose);
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.primaryGold.withValues(alpha: 0.14),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: _isRecording
              ? Row(
                  children: [
                    GestureDetector(
                      onTap: _cancelRecording,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recording voice note · ${_formatDuration(Duration(seconds: _recordSeconds))}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _stopAndSendRecording,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryGold, Color(0xFFB8941F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Attach button
                    GestureDetector(
                      onTap: _showAttachmentOptions,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.backgroundDark : const Color(0xFFF0F0F0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.attach_file_rounded,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _textController,
                          maxLines: 4,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isSending
                          ? null
                          : (_hasText ? _sendMessage : _startRecording),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: _isSending
                              ? null
                              : const LinearGradient(
                                  colors: [AppColors.primaryGold, Color(0xFFB8941F)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _isSending
                              ? AppColors.primaryGold.withValues(alpha: 0.5)
                              : null,
                          shape: BoxShape.circle,
                        ),
                        child: _isSending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Icon(
                                _hasText ? Icons.send_rounded : Icons.mic_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '🙏', '🔥', '😂', '👏'].map((emoji) {
                  final isReacted = msg.reactions.any((r) => r.emoji == emoji && r.reacted);
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(communityChangeNotifierProvider).toggleReaction(msg.id, emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isReacted
                            ? AppColors.primaryGold.withValues(alpha: 0.22)
                            : (isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5)),
                        shape: BoxShape.circle,
                        border: isReacted
                            ? Border.all(color: AppColors.primaryGold, width: 1.5)
                            : null,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.primaryGold),
              title: Text('Reply',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = msg);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete message',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(communityChangeNotifierProvider).deleteMessage(msg.id);
                },
              ),
            ListTile(
              leading: Icon(Icons.close,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              title: Text('Cancel',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}
