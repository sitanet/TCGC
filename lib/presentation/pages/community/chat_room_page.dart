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
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../widgets/app_image.dart';
import 'listen_together_page.dart';
import '../../../core/providers/listen_together_provider.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/sermon.dart';
import '../audio/audio_player_page.dart';
import '../audio/transcript_list_page.dart';
class ChatRoomPage extends ConsumerStatefulWidget {
  final CommunityRoom room;
  final String? dmUserName;
  final String? dmUserPhoto;
  final int? dmUserId;
  final bool? dmUserOnline;
  final String? dmUserLastSeen;
  final bool autoJoinListenSession;

  const ChatRoomPage({
    super.key,
    required this.room,
    this.dmUserName,
    this.dmUserPhoto,
    this.dmUserId,
    this.dmUserOnline,
    this.dmUserLastSeen,
    this.autoJoinListenSession = false,
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
  Timer? _typingStopTimer;
  DateTime? _lastTypingSentAt;
  bool _isCurrentlyTyping = false;
  int _lastMessageCount = 0;
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
  double _voiceSpeed = 1.0;
  StreamSubscription? _voicePosSub;
  StreamSubscription? _voiceDurSub;
  StreamSubscription? _voiceStateSub;

  // WhatsApp-style in-chat search & scroll-to-bottom FAB
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _chatSearchQuery = '';
  bool _showScrollToBottom = false;

  // Draggable mini-player state
  Offset _miniPlayerOffset = const Offset(12, 8);
  bool _miniPlayerMinimized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final distFromBottom =
          _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
      final shouldShow = distFromBottom > 240;
      if (shouldShow != _showScrollToBottom && mounted) {
        setState(() => _showScrollToBottom = shouldShow);
      }
    });
    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText && mounted) setState(() => _hasText = has);
      _onTypingChanged(has);
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
      if (widget.autoJoinListenSession) {
        _autoJoinIfRequested();
      }
    });
  }

  Future<void> _autoJoinIfRequested() async {
    final listenState = ref.read(listenTogetherProvider);
    if (listenState.isJoined && listenState.currentRoomId == widget.room.id) {
      return;
    }
    final session = await ref
        .read(communityChangeNotifierProvider)
        .pollListenSession(widget.room.id);
    if (!mounted || session == null || !session.isActive) return;

    setState(() => _activeSession = session);
    final me = ref.read(authChangeNotifierProvider).user;
    final myId = int.tryParse(me?.id ?? '0') ?? 0;
    await ref.read(listenTogetherProvider.notifier).joinAsListener(
          roomId: widget.room.id,
          session: session,
          myUserId: myId,
        );
    if (session.hostId != myId) {
      final memberName = (me?.fullName ?? '').trim().isNotEmpty
          ? me!.fullName.trim()
          : 'A member';
      await ref.read(communityChangeNotifierProvider).sendMessage(
            widget.room.id,
            '🎧 $memberName joined to listen',
          );
    }
  }

  void _showGroupMembersSheet() {
    final provider = ref.read(communityChangeNotifierProvider);
    if (provider.allMembers.isEmpty) {
      provider.fetchAllMembers();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meId =
        int.tryParse(ref.read(authChangeNotifierProvider).user?.id ?? '');
    final memberSearchController = TextEditingController();
    String memberQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Consumer(
              builder: (cCtx, sheetRef, _) {
                final p = sheetRef.watch(communityChangeNotifierProvider);
                final members = p.allMembers
                    .where((m) =>
                        memberQuery.isEmpty ||
                        m.name.toLowerCase().contains(memberQuery))
                    .toList()
                  ..sort((a, b) {
                    if (a.isOnline == b.isOnline) {
                      return a.name
                          .toLowerCase()
                          .compareTo(b.name.toLowerCase());
                    }
                    return a.isOnline ? -1 : 1;
                  });
                final onlineCount = members.where((m) => m.isOnline).length;
                final bottomPad = MediaQuery.of(ctx).padding.bottom;

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.82,
                  ),
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPad),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryGold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.forum_rounded,
                                color: AppColors.primaryGold, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.room.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${members.length} members · $onlineCount online',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color:
                                    isDark ? Colors.white60 : Colors.black54),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                      if (widget.room.description != null &&
                          widget.room.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.room.description!.trim(),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: memberSearchController,
                        onChanged: (v) => setSheetState(
                            () => memberQuery = v.trim().toLowerCase()),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search members...',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 19, color: AppColors.primaryGold),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (members.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            p.allMembers.isEmpty
                                ? 'Loading group members...'
                                : 'No members match "$memberQuery"',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: members.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200,
                            ),
                            itemBuilder: (_, i) {
                              final m = members[i];
                              final isSelf = meId != null && m.id == meId;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 21,
                                      backgroundColor: AppColors.primaryGold
                                          .withValues(alpha: 0.16),
                                      child: m.photoUrl != null
                                          ? ClipOval(
                                              child: AppImage(
                                                imagePath: m.photoUrl!,
                                                width: 42,
                                                height: 42,
                                              ),
                                            )
                                          : Text(
                                              m.name.isNotEmpty
                                                  ? m.name[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: AppColors.primaryGold,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 11,
                                        height: 11,
                                        decoration: BoxDecoration(
                                          color: m.isOnline
                                              ? const Color(0xFF22C55E)
                                              : Colors.grey.shade400,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? AppColors.cardDark
                                                : Colors.white,
                                            width: 1.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  isSelf ? '${m.name} (You)' : m.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  m.isOnline
                                      ? 'Online'
                                      : (m.department != null &&
                                              m.department!.isNotEmpty
                                          ? m.department!
                                          : m.statusText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: m.isOnline
                                        ? Colors.green
                                        : (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight),
                                  ),
                                ),
                                trailing: isSelf
                                    ? null
                                    : TextButton(
                                        onPressed: () async {
                                          final ok = await ref
                                              .read(
                                                  communityChangeNotifierProvider)
                                              .toggleFollowMember(m.id);
                                          if (ok == null && mounted) {
                                            final err = ref
                                                    .read(
                                                        communityChangeNotifierProvider)
                                                    .error ??
                                                'Could not update follow status';
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(err),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: m.isFollowing
                                              ? AppColors.primaryGold
                                                  .withValues(alpha: 0.16)
                                              : (isDark
                                                  ? Colors.white10
                                                  : Colors.grey.shade100),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: Text(
                                          m.isFollowing ? 'Following' : 'Follow',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: m.isFollowing
                                                ? AppColors.primaryGold
                                                : (isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                          ),
                                        ),
                                      ),
                                onTap: isSelf
                                    ? null
                                    : () async {
                                        Navigator.pop(sheetCtx);
                                        final room = await ref
                                            .read(
                                                communityChangeNotifierProvider)
                                            .openDm(m.id);
                                        if (!mounted) return;
                                        if (room != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatRoomPage(
                                                room: room,
                                                dmUserName: m.name,
                                                dmUserPhoto: m.photoUrl,
                                                dmUserId: m.id,
                                                dmUserOnline: m.isOnline,
                                                dmUserLastSeen: m.lastSeen,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(memberSearchController.dispose);
  }

  void _shareRoomLink() {
    final url = 'https://tcgc.thecitygatechurch.org/app/community/${widget.room.id}/';
    final listenState = ref.read(listenTogetherProvider);
    final active = (listenState.isJoined && listenState.currentRoomId == widget.room.id)
        ? listenState.session
        : _activeSession;
    final text = (active != null && active.isActive)
        ? '🎧 Listen Together LIVE in "${widget.room.name}"!\nNow playing: ${active.resourceTitle}\n\nTap to join the group & listen live:\n$url'
        : 'Join "${widget.room.name}" on Citygate Mobile:\n$url';
    Share.share(text);
  }

  void _startSessionPolling() {
    _sessionPollTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      final listenState = ref.read(listenTogetherProvider);
      if (listenState.isJoined && listenState.currentRoomId == widget.room.id) {
        return;
      }
      final session = await ref.read(communityChangeNotifierProvider)
          .pollListenSession(widget.room.id);
      if (mounted) setState(() => _activeSession = session);
    });
  }

  void _onTypingChanged(bool hasText) {
    if (!hasText) {
      _stopTyping();
      return;
    }
    final now = DateTime.now();
    if (!_isCurrentlyTyping ||
        _lastTypingSentAt == null ||
        now.difference(_lastTypingSentAt!) >= const Duration(seconds: 3)) {
      _isCurrentlyTyping = true;
      _lastTypingSentAt = now;
      ref.read(communityChangeNotifierProvider).setTyping(widget.room.id, true);
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 4), _stopTyping);
  }

  void _stopTyping() {
    _typingStopTimer?.cancel();
    _typingStopTimer = null;
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      _lastTypingSentAt = null;
      ref.read(communityChangeNotifierProvider).setTyping(widget.room.id, false);
    }
  }

  @override
  void dispose() {
    _stopTyping();
    _sessionPollTimer?.cancel();
    _recordTimer?.cancel();
    _voicePosSub?.cancel();
    _voiceDurSub?.cancel();
    _voiceStateSub?.cancel();
    _recorder.dispose();
    _voicePlayer.dispose();
    try {
      ref.read(communityChangeNotifierProvider).stopPolling();
    } catch (_) {}
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cycleVoiceSpeed() async {
    final next = _voiceSpeed == 1.0
        ? 1.5
        : (_voiceSpeed == 1.5 ? 2.0 : 1.0);
    setState(() => _voiceSpeed = next);
    try {
      await _voicePlayer.setSpeed(next);
    } catch (_) {}
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
    _stopTyping();
    _textController.clear();

    bool ok = false;
    final p = ref.read(communityChangeNotifierProvider);
    try {
      ok = await p.sendMessage(widget.room.id, text, replyToId: replyToId);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
    if (!mounted) return;
    if (ok) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      if (_textController.text.isEmpty) {
        _textController.text = text;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(p.error ?? 'Failed to send message. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
      ref.read(communityChangeNotifierProvider).setTyping(
        widget.room.id,
        true,
        activity: 'recording',
      );
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
        if (_recordSeconds % 3 == 0) {
          ref.read(communityChangeNotifierProvider).setTyping(
            widget.room.id,
            true,
            activity: 'recording',
          );
        }
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
    ref.read(communityChangeNotifierProvider).setTyping(
      widget.room.id,
      false,
      activity: 'recording',
    );
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
    ref.read(communityChangeNotifierProvider).setTyping(
      widget.room.id,
      false,
      activity: 'recording',
    );
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

    // Only auto-scroll to bottom when new messages actually arrive (not on every rebuild)
    final currentCount = p.messages.length;
    if (currentCount != _lastMessageCount) {
      final wasEmpty = _lastMessageCount == 0;
      final hasNewMessages = currentCount > _lastMessageCount;
      _lastMessageCount = currentCount;
      if (hasNewMessages) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          final pos = _scrollController.position;
          if (wasEmpty ||
              (!pos.isScrollingNotifier.value &&
                  pos.pixels >= pos.maxScrollExtent - 200)) {
            _scrollToBottom();
          }
        });
      }
    }

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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _chatSearchQuery = v.trim().toLowerCase()),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
              )
            : widget.dmUserName != null
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
            : GestureDetector(
                onTap: _showGroupMembersSheet,
                behavior: HitTestBehavior.opaque,
                child: Row(
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
                          Text(
                            (widget.room.description != null && widget.room.description!.isNotEmpty)
                                ? widget.room.description!
                                : 'Tap here for group members',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              tooltip: 'Close Search',
              icon: const Icon(Icons.close_rounded, color: AppColors.primaryGold),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _chatSearchQuery = '';
                });
              },
            )
          else
            PopupMenuButton<String>(
              tooltip: 'More options',
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark ? Colors.white : Colors.black87,
              ),
              color: isDark ? AppColors.cardDark : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'search':
                    setState(() => _isSearching = true);
                    break;
                  case 'members':
                    _showGroupMembersSheet();
                    break;
                  case 'listen':
                    _openSermonPickerForListenTogether();
                    break;
                  case 'share':
                    _shareRoomLink();
                    break;
                  case 'refresh':
                    p.fetchMessages(widget.room.id);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 19, color: AppColors.primaryGold),
                      const SizedBox(width: 10),
                      Text('Search Messages',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
                if (widget.dmUserName == null) ...[
                  PopupMenuItem(
                    value: 'members',
                    child: Row(
                      children: [
                        const Icon(Icons.group_rounded, size: 19, color: AppColors.primaryGold),
                        const SizedBox(width: 10),
                        Text('Group Members',
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'listen',
                    child: Row(
                      children: [
                        const Icon(Icons.headphones_rounded, size: 19, color: AppColors.primaryGold),
                        const SizedBox(width: 10),
                        Text('Listen Together',
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        const Icon(Icons.share_rounded, size: 19, color: AppColors.primaryGold),
                        const SizedBox(width: 10),
                        Text('Share Group Link',
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                ],
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh_rounded, size: 19, color: AppColors.primaryGold),
                      const SizedBox(width: 10),
                      Text('Refresh',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPlayerVisible = listenState.isJoined &&
              listenState.session != null &&
              listenState.currentRoomId == widget.room.id;
          final expandedWidth = (constraints.maxWidth - 24).clamp(240.0, 440.0);
          final playerWidth = _miniPlayerMinimized ? 196.0 : expandedWidth;
          final playerHeight = _miniPlayerMinimized ? 46.0 : 88.0;
          final maxX = (constraints.maxWidth - playerWidth - 8).clamp(8.0, 2000.0);
          final maxY = (constraints.maxHeight - playerHeight - 76).clamp(8.0, 2000.0);
          final clampedLeft = _miniPlayerOffset.dx.clamp(8.0, maxX);
          final clampedTop = _miniPlayerOffset.dy.clamp(8.0, maxY);

          return Stack(
            children: [
              Column(
                children: [
                  // Join banner when someone else is hosting and user hasn't joined yet
                  if (!isPlayerVisible && _activeSession != null && _activeSession!.isActive)
                    _buildJoinBanner(_activeSession!, isDark),
                  // Messages
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final displayMessages = _chatSearchQuery.isEmpty
                            ? p.messages
                            : p.messages
                                .where((m) =>
                                    m.text.toLowerCase().contains(_chatSearchQuery) ||
                                    m.senderName.toLowerCase().contains(_chatSearchQuery) ||
                                    (m.fileName ?? '').toLowerCase().contains(_chatSearchQuery))
                                .toList();

                        if (p.isLoading && p.messages.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppColors.primaryGold),
                          );
                        }
                        if (p.messages.isEmpty) {
                          return _buildEmptyState(isDark);
                        }
                        if (displayMessages.isEmpty) {
                          return Center(
                            child: Text(
                              'No messages match "$_chatSearchQuery"',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          );
                        }

                        return Stack(
                          children: [
                            ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.fromLTRB(
                                12,
                                isPlayerVisible && !_miniPlayerMinimized ? 96 : 8,
                                12,
                                8,
                              ),
                              itemCount: displayMessages.length,
                              itemBuilder: (ctx, i) {
                                final msg = displayMessages[i];
                                final isMe = me != null && msg.senderId == int.tryParse(me.id);
                                final showAvatar = i == 0 ||
                                    displayMessages[i - 1].senderId != msg.senderId;
                                final showDate = i == 0 ||
                                    !_isSameDay(displayMessages[i - 1].createdAt, msg.createdAt);
                                return Column(
                                  children: [
                                    if (showDate) _buildDateDivider(msg.createdAt, isDark),
                                    _buildMessageBubble(context, isDark, msg, isMe, showAvatar, me?.id),
                                  ],
                                );
                              },
                            ),
                            if (_showScrollToBottom && _chatSearchQuery.isEmpty)
                              Positioned(
                                right: 14,
                                bottom: 12,
                                child: GestureDetector(
                                  onTap: _scrollToBottom,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.cardDark : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primaryGold.withValues(alpha: 0.5),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.18),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.primaryGold,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Typing & recording indicator
                  _buildTypingIndicator(
                    p.typingUsers,
                    p.recordingUsers,
                    me?.fullName,
                    isDark,
                  ),
                  // Reply preview bar
                  if (_replyingTo != null) _buildReplyPreviewBar(isDark),
                  // Input bar
                  _buildInputBar(isDark),
                ],
              ),
              if (isPlayerVisible)
                Positioned(
                  left: clampedLeft,
                  top: clampedTop,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _miniPlayerOffset = Offset(
                          (_miniPlayerOffset.dx + details.delta.dx).clamp(8.0, maxX),
                          (_miniPlayerOffset.dy + details.delta.dy).clamp(8.0, maxY),
                        );
                      });
                    },
                    child: SizedBox(
                      width: playerWidth,
                      child: _buildDockedPlayer(listenState, isDark),
                    ),
                  ),
                ),
            ],
          );
        },
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
              setState(() => _activeSession = null);
              final notifier = ref.read(listenTogetherProvider.notifier);
              if (ref.read(listenTogetherProvider).isHost) {
                notifier.endSession().then((_) {
                  if (mounted) {
                    ref.read(communityChangeNotifierProvider).refreshHostingRooms();
                  }
                });
              } else {
                notifier.forceEndRoomSession(widget.room.id).then((_) {
                  if (mounted) {
                    ref.read(communityChangeNotifierProvider).refreshHostingRooms();
                  }
                });
              }
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

    if (_miniPlayerMinimized) {
      return Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF282012), const Color(0xFF171410)]
                  : [const Color(0xFFFFFDF7), const Color(0xFFF7EED9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.primaryGold, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: isHost
                    ? () => ref.read(listenTogetherProvider.notifier).togglePlayPause()
                    : null,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryGold, Color(0xFFB58E24)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    listenState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDuration(position),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Expand Mini Player',
                icon: const Icon(Icons.open_in_full_rounded, color: AppColors.primaryGold, size: 17),
                onPressed: () => setState(() => _miniPlayerMinimized = false),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF282012), const Color(0xFF171410)]
                : [const Color(0xFFFFFDF7), const Color(0xFFFBF4E4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.65),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle bar
            Center(
              child: Container(
                width: 34,
                height: 3.5,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: isHost
                      ? () => ref.read(listenTogetherProvider.notifier).togglePlayPause()
                      : null,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isHost
                            ? const [AppColors.primaryGold, Color(0xFFB58E24)]
                            : [
                                AppColors.primaryGold.withValues(alpha: 0.45),
                                AppColors.primaryGold.withValues(alpha: 0.35),
                              ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: isHost
                          ? [
                              BoxShadow(
                                color: AppColors.primaryGold.withValues(alpha: 0.32),
                                blurRadius: 8,
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
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListenTogetherPage(roomId: widget.room.id),
                        ),
                      );
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
                                session.resourceTitle.isNotEmpty
                                    ? session.resourceTitle
                                    : 'Message Audio',
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
                              ? 'Hosting · ${_formatDuration(position)} / ${_formatDuration(duration)}'
                              : '${session.hostName} · ${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryGold,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Share to WhatsApp',
                  icon: const Icon(Icons.share_rounded, color: AppColors.primaryGold, size: 18),
                  onPressed: _shareRoomLink,
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Minimize',
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.primaryGold, size: 20),
                  onPressed: () => setState(() => _miniPlayerMinimized = true),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Fullscreen Player',
                  icon: const Icon(Icons.open_in_full_rounded, color: AppColors.primaryGold, size: 17),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ListenTogetherPage(roomId: widget.room.id),
                      ),
                    );
                  },
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: (isHost ||
                          const [
                            'super_admin',
                            'admin',
                            'admin_operational',
                            'media',
                            'pastorate',
                          ].contains(ref.read(authChangeNotifierProvider).user?.role))
                      ? 'End Session'
                      : 'Leave Session',
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 19),
                  onPressed: () async {
                    final me = ref.read(authChangeNotifierProvider).user;
                    final isPrivileged = const [
                      'super_admin',
                      'admin',
                      'admin_operational',
                      'media',
                      'pastorate',
                    ].contains(me?.role);
                    if (isHost || isPrivileged) {
                      _showEndSessionDialog();
                    } else {
                      final memberName = (me?.fullName ?? '').trim().isNotEmpty
                          ? me!.fullName.trim()
                          : 'A member';
                      await ref.read(listenTogetherProvider.notifier).leaveSession();
                      await ref.read(communityChangeNotifierProvider).sendMessage(
                        widget.room.id,
                        '🎧 $memberName left listening',
                      );
                    }
                  },
                ),
              ],
            ),
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

  Widget _buildTypingIndicator(
    List<String> typingUsers,
    List<String> recordingUsers,
    String? myName,
    bool isDark,
  ) {
    final normalizedMe = (myName ?? '').trim().toLowerCase();
    final otherTyping = typingUsers
        .where((name) => name.trim().toLowerCase() != normalizedMe)
        .toList();
    final otherRecording = recordingUsers
        .where((name) => name.trim().toLowerCase() != normalizedMe)
        .toList();
    if (otherTyping.isEmpty && otherRecording.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isRecordingActivity = otherRecording.isNotEmpty;
    final activeList = isRecordingActivity ? otherRecording : otherTyping;
    final verb = isRecordingActivity ? 'recording audio...' : 'typing...';

    final String label;
    if (activeList.length == 1) {
      label = '${activeList.first} is $verb';
    } else if (activeList.length == 2) {
      label = '${activeList[0]} and ${activeList[1]} are $verb';
    } else {
      label = '${activeList[0]}, ${activeList[1]} and ${activeList.length - 2} others are $verb';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (isRecordingActivity)
            const Icon(Icons.mic_rounded, size: 14, color: Colors.redAccent)
          else
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: AppColors.primaryGold,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: isRecordingActivity
                    ? Colors.redAccent
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
        (msg.text.endsWith(' joined to listen') || msg.text.endsWith(' left listening'))) {
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
    final isTranscript = msg.resourceType == 'transcript';

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
              // Action buttons for audio & transcript resources
              if (isAudio && msg.resourceId != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: () => _openSharedAudio(msg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.22)
                              : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                size: 15,
                                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87)),
                            const SizedBox(width: 4),
                            Text(
                              'Listen',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                ),
              ] else if (isTranscript && msg.resourceId != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openSharedTranscript(msg),
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
                        Icon(Icons.menu_book_rounded,
                            size: 14,
                            color: isMe ? Colors.white : Colors.black87),
                        const SizedBox(width: 6),
                        Text(
                          'Read Transcript',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isMe ? Colors.white : Colors.black87,
                          ),
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
                    Expanded(
                      child: Text(
                        isActive && dur > Duration.zero
                            ? '${_formatDuration(pos)} / ${_formatDuration(dur)}'
                            : 'Voice note',
                        style: TextStyle(fontSize: 11, color: subColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive)
                      GestureDetector(
                        onTap: _cycleVoiceSpeed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.24)
                                : AppColors.primaryGold.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _voiceSpeed == 1.0
                                ? '1x'
                                : (_voiceSpeed == 1.5 ? '1.5x' : '2x'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isMe ? Colors.white : AppColors.primaryGold,
                            ),
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

  Future<void> _openSharedAudio(ChatMessage msg) async {
    if (msg.resourceId == null) return;
    final sermon = await DataService().getMessageById(msg.resourceId.toString());
    if (!mounted) return;
    if (sermon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AudioPlayerPage(sermon: sermon)),
    );
  }

  Future<void> _openSharedTranscript(ChatMessage msg) async {
    if (msg.resourceId == null) return;
    final transcript =
        await DataService().getTranscriptById(msg.resourceId.toString());
    if (!mounted) return;
    if (transcript == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcript not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TranscriptViewPage(transcript: transcript)),
    );
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
    var sermonsFuture = dataService.getMessages(forceRefresh: false);
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
                                      'Select a message to listen with the room',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh Messages',
                                icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryGold),
                                onPressed: () => setSheetState(() {
                                  sermonsFuture = dataService.getMessages(forceRefresh: true);
                                }),
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
            if (msg.text.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppColors.primaryGold),
                title: Text('Copy',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
            if (msg.text.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.forward_rounded, color: AppColors.primaryGold),
                title: Text('Forward to Room',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _showForwardRoomSheet(msg);
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: AppColors.primaryGold),
              title: Text('Share',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                final shareText = msg.text.trim().isNotEmpty
                    ? '${msg.senderName}: ${msg.text}'
                    : (msg.fileUrl ?? _messagePreviewText(msg));
                Share.share(shareText);
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

  void _showForwardRoomSheet(ChatMessage msg) {
    final p = ref.read(communityChangeNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetRooms = p.rooms.where((r) => r.id != widget.room.id).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Forward Message To...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (targetRooms.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No other chat rooms available.',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: targetRooms.length,
                  itemBuilder: (_, i) {
                    final r = targetRooms[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryGold.withValues(alpha: 0.16),
                        child: const Icon(Icons.forum_rounded,
                            color: AppColors.primaryGold, size: 18),
                      ),
                      title: Text(
                        r.name,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final ok = await p.sendMessage(
                          r.id,
                          '↪ Forwarded from ${msg.senderName}:\n${msg.text}',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Forwarded to ${r.name}'
                                  : 'Failed to forward message'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
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
