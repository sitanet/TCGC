import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../widgets/app_image.dart';
import 'listen_together_page.dart';
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

  @override
  void initState() {
    super.initState();
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
              children: [
                _attachOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
                ),
                _attachOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: Colors.blue,
                  onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
                ),
                _attachOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Document',
                  color: Colors.orange,
                  onTap: () { Navigator.pop(ctx); _pickDocument(); },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
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
          Text(label, style: TextStyle(
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
    
    setState(() => _isSending = true);
    
    try {
      final p = ref.read(communityChangeNotifierProvider);
      final success = await p.sendFileMessage(widget.room.id, file, fileType);
      
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

    setState(() => _isSending = true);
    _textController.clear();

    final p = ref.read(communityChangeNotifierProvider);
    await p.sendMessage(widget.room.id, text);

    setState(() => _isSending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = ref.watch(communityChangeNotifierProvider);
    final me = ref.read(authChangeNotifierProvider).user;

    // Scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        elevation: 0,
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.room.name,
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                  if (widget.room.description != null)
                    Text(widget.room.description!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGold),
            onPressed: () => p.fetchMessages(widget.room.id),
          ),
        ],
      ),
      body: Column(
        children: [
          // Active listen-together session banner
          if (_activeSession != null && _activeSession!.isActive)
            _buildSessionBanner(),
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
          // Input bar
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildSessionBanner() {
    final session = _activeSession!;
    final me = ref.read(authChangeNotifierProvider).user;
    final isHost = me != null && session.hostId.toString() == me.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ListenTogetherPage(
            roomId: widget.room.id,
            initialSession: session,
            isHost: isHost,
            myUserId: me?.id,
          ),
        ));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryGold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.headphones_rounded, color: AppColors.primaryGold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHost ? 'Your listen session is live' : '${session.hostName} started a listen session',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87),
                  ),
                  Text(
                    session.resourceTitle.isNotEmpty ? session.resourceTitle : 'Tap to join',
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryGold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isHost ? 'Open' : 'Join',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64, color: AppColors.primaryGold.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No messages yet',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          Text('Be the first to say something!',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: isDark ? AppColors.dividerDark : AppColors.dividerLight)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
        ),
        Expanded(child: Divider(color: isDark ? AppColors.dividerDark : AppColors.dividerLight)),
      ]),
    );
  }

  Widget _buildMessageBubble(BuildContext context, bool isDark, ChatMessage msg,
      bool isMe, bool showAvatar, String? myId) {
    return GestureDetector(
      onLongPress: isMe && !msg.isDeleted
          ? () => _showDeleteDialog(context, msg)
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
                      color: isMe
                          ? AppColors.primaryGold
                          : (isDark ? AppColors.cardDark : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: msg.hasResource
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
        if (isImage && msg.fileUrl != null)
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
    final p = ref.read(communityChangeNotifierProvider);

    final session = await p.startListenSession(
      widget.room.id,
      resourceType: msg.resourceType!,
      resourceId: msg.resourceId!,
      resourceTitle: msg.resourceTitle ?? '',
      audioUrl: audioUrl,
    );

    if (!mounted) return;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start session'), backgroundColor: Colors.red));
      return;
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ListenTogetherPage(
        roomId: widget.room.id,
        initialSession: session,
        isHost: true,
        myUserId: me?.id,
      ),
    ));
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
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
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _isSending
                    ? AppColors.primaryGold.withValues(alpha: 0.5)
                    : AppColors.primaryGold,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ChatMessage msg) {
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
