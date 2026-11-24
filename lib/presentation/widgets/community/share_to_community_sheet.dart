import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/community_provider.dart';
import '../../../main.dart';
import '../../pages/auth/auth_flow_page.dart';
import '../../pages/community/chat_room_page.dart';

/// Bottom sheet that lets users share an audio message or transcript
/// (along with an optional takeaway/note) directly into a Community Chat Room.
class ShareToCommunitySheet extends ConsumerStatefulWidget {
  final String resourceType; // 'audio' or 'transcript'
  final int? resourceId;
  final String resourceTitle;
  final String? fallbackUrl;

  const ShareToCommunitySheet({
    super.key,
    required this.resourceType,
    required this.resourceId,
    required this.resourceTitle,
    this.fallbackUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String resourceType,
    required int? resourceId,
    required String resourceTitle,
    String? fallbackUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareToCommunitySheet(
        resourceType: resourceType,
        resourceId: resourceId,
        resourceTitle: resourceTitle,
        fallbackUrl: fallbackUrl,
      ),
    );
  }

  @override
  ConsumerState<ShareToCommunitySheet> createState() =>
      _ShareToCommunitySheetState();
}

class _ShareToCommunitySheetState extends ConsumerState<ShareToCommunitySheet> {
  final TextEditingController _noteController = TextEditingController();
  CommunityRoom? _selectedRoom;
  bool _sending = false;
  bool _loadingRooms = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRoomsLoaded());
  }

  Future<void> _ensureRoomsLoaded() async {
    final auth = ref.read(authChangeNotifierProvider);
    if (!auth.isAuthenticated) return;
    final community = ref.read(communityChangeNotifierProvider);
    if (community.rooms.isEmpty) {
      setState(() => _loadingRooms = true);
      await community.fetchRooms();
      if (mounted) {
        setState(() {
          _loadingRooms = false;
          if (community.rooms.isNotEmpty) {
            _selectedRoom ??= community.rooms.first;
          }
        });
      }
    } else {
      setState(() => _selectedRoom ??= community.rooms.first);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final room = _selectedRoom;
    if (room == null || _sending) return;

    setState(() => _sending = true);
    final note = _noteController.text.trim();
    final defaultText = widget.resourceType == 'transcript'
        ? 'Sharing this transcript for discussion'
        : 'Sharing this message for discussion';
    final textToSend = note.isNotEmpty
        ? note
        : (widget.resourceId == null && widget.fallbackUrl != null
            ? '$defaultText\n${widget.resourceTitle}\n${widget.fallbackUrl}'
            : defaultText);

    final ok = await ref.read(communityChangeNotifierProvider).sendMessage(
          room.id,
          textToSend,
          resourceType: widget.resourceId != null ? widget.resourceType : null,
          resourceId: widget.resourceId,
          resourceTitle:
              widget.resourceId != null ? widget.resourceTitle : null,
        );

    if (!mounted) return;
    setState(() => _sending = false);

    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Shared to ${room.name}'),
          backgroundColor: AppColors.primaryGold,
          action: SnackBarAction(
            label: 'Open Room',
            textColor: Colors.black,
            onPressed: () {
              navigator.push(
                MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
              );
            },
          ),
        ),
      );
    } else {
      final err = ref.read(communityChangeNotifierProvider).error ??
          'Could not share to room';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authChangeNotifierProvider);
    final community = ref.watch(communityChangeNotifierProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isTranscript = widget.resourceType == 'transcript';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset + bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.forum_rounded,
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
                      'Discuss in Community',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Share this ${isTranscript ? 'transcript' : 'message'} with a fellowship room',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Attached resource preview card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isTranscript ? Icons.article_rounded : Icons.headphones_rounded,
                  color: AppColors.primaryGold,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.resourceTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!auth.isAuthenticated) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    'Sign in to share messages and discuss with fellowship members.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        AuthFlowPage.open(context);
                      },
                      icon: const Icon(Icons.login_rounded,
                          size: 18, color: Colors.black),
                      label: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            TextField(
              controller: _noteController,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Add your takeaway, quote, or question (optional)...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Choose a Chat Room',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingRooms)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primaryGold),
                ),
              )
            else if (community.rooms.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  community.hasAccess
                      ? 'No chat rooms available right now.'
                      : 'Community rooms are available to verified members.',
                  style: TextStyle(
                    fontSize: 13,
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
                  itemCount: community.rooms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final room = community.rooms[i];
                    final selected = _selectedRoom?.id == room.id;
                    return InkWell(
                      onTap: () => setState(() => _selectedRoom = room),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryGold
                                  .withValues(alpha: isDark ? 0.18 : 0.12)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryGold
                                : (isDark
                                    ? Colors.white12
                                    : Colors.grey.shade200),
                            width: selected ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              room.icon.isNotEmpty ? room.icon : '💬',
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  if (room.categoryName != null &&
                                      room.categoryName!.isNotEmpty)
                                    Text(
                                      room.categoryName!,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: selected
                                  ? AppColors.primaryGold
                                  : (isDark
                                      ? Colors.white24
                                      : Colors.grey.shade400),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (_selectedRoom == null || _sending) ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        size: 18, color: Colors.black),
                label: Text(
                  _sending
                      ? 'Sharing...'
                      : (_selectedRoom != null
                          ? 'Share to ${_selectedRoom!.name}'
                          : 'Share to Community'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  disabledBackgroundColor:
                      AppColors.primaryGold.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
