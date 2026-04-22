import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../widgets/app_image.dart';
import 'call_page.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = ref.read(communityChangeNotifierProvider);
      p.fetchMessages(widget.room.id);
      p.startPolling(widget.room.id);
    });
  }

  @override
  void dispose() {
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

  Future<void> _startCall({required bool isVideo}) async {
    if (widget.dmUserId == null) return;
    final p = ref.read(communityChangeNotifierProvider);
    final channelName = await p.callUser(widget.dmUserId!, isVideo: isVideo);
    if (!mounted) return;
    if (channelName != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallPage(
          channelName: channelName,
          callerName: widget.dmUserName ?? 'User',
          callerPhoto: widget.dmUserPhoto,
          isVideo: isVideo,
          isIncoming: false,
          remoteUserId: widget.dmUserId!,
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start call'), backgroundColor: Colors.red));
    }
  }

  Future<void> _sendMessage() async {    final text = _textController.text.trim();
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
                    Text(widget.dmUserName!,
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87)),
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
          if (widget.dmUserId != null) ...[
            IconButton(
              icon: const Icon(Icons.call, color: AppColors.primaryGold),
              onPressed: () => _startCall(isVideo: false),
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: AppColors.primaryGold),
              onPressed: () => _startCall(isVideo: true),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGold),
            onPressed: () => p.fetchMessages(widget.room.id),
          ),
        ],
      ),
      body: Column(
        children: [
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
                    child: Text(
                      _formatTime(msg.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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

  Widget _buildResourceCard(bool isDark, ChatMessage msg, bool isMe) {
    final iconMap = {'audio': Icons.headphones, 'event': Icons.event, 'transcript': Icons.article};
    final icon = iconMap[msg.resourceType] ?? Icons.link;
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: isMe ? Colors.white : AppColors.primaryGold),
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
        ),
      ],
    );
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
