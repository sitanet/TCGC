import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/app_image.dart';
import 'chat_room_page.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = ref.read(communityChangeNotifierProvider);
      p.fetchRooms();
      p.fetchAllMembers();
      p.startHeartbeat();
    });
  }

  @override
  void dispose() {
    ref.read(communityChangeNotifierProvider).stopHeartbeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = ref.watch(communityChangeNotifierProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: CustomAppBar(
        title: 'Community',
        showBackButton: false,
        lightBackground: !isDark,
      ),
      body: !p.hasAccess
          ? _buildNoAccessScreen(isDark)
          : RefreshIndicator(
        color: AppColors.primaryGold,
        onRefresh: () async {
          await p.fetchRooms();
          await p.fetchAllMembers();
        },
        child: CustomScrollView(
          slivers: [
            // Search bar
            SliverToBoxAdapter(child: _buildSearchBar(isDark)),
            // Members Strip (all members with online/offline)
            SliverToBoxAdapter(child: _buildMembersStrip(context, isDark, p)),
            // Section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text('Chat Rooms',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    )),
              ),
            ),
            // Rooms list
            p.isLoading && p.rooms.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryGold)))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildRoomTile(context, isDark, p.rooms[i]),
                      childCount: p.rooms.length,
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search members...',
          hintStyle: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: isDark ? AppColors.cardDark : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.primaryGold.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildNoAccessScreen(bool isDark) {    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline,
                size: 72, color: AppColors.primaryGold.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text('Community Access Required',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'You do not have access to the community chat yet.\nPlease contact an admin to enable your access.',
              style: TextStyle(
                fontSize: 14, height: 1.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersStrip(BuildContext context, bool isDark, CommunityProvider p) {
    final filtered = _searchQuery.isEmpty
        ? p.allMembers
        : p.allMembers
            .where((m) => m.name.toLowerCase().contains(_searchQuery))
            .toList();
    final onlineCount = filtered.where((m) => m.isOnline).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '$onlineCount online · ${filtered.length} members',
              style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14,
                color: isDark ? Colors.white : Colors.black87),
            ),
          ]),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _buildMemberAvatar(isDark, filtered[i]),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty ? 'No members found' : 'No members yet',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(bool isDark, OnlineMember m) {
    return GestureDetector(
      onTap: () => _openDm(m),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                  child: m.photoUrl != null
                      ? ClipOval(child: AppImage(imagePath: m.photoUrl!, width: 48, height: 48))
                      : Text(
                          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.primaryGold,
                            fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: m.isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.cardDark : Colors.white, width: 2)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Text(
                    m.name.split(' ').first,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    m.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 9,
                      color: m.isOnline ? Colors.green : Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDm(OnlineMember member) async {
    final p = ref.read(communityChangeNotifierProvider);
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold)),
    );

    final room = await p.openDm(member.id);
    if (!mounted) return;
    Navigator.pop(context); // close loading

    if (room != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            room: room,
            dmUserName: member.name,
            dmUserPhoto: member.photoUrl,
            dmUserId: member.id,
            dmUserOnline: member.isOnline,
            dmUserLastSeen: member.lastSeen,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open chat. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRoomTile(BuildContext context, bool isDark, CommunityRoom room) {
    final iconMap = {
      'chat_bubble_outline': Icons.chat_bubble_outline,
      'volunteer_activism': Icons.volunteer_activism,
      'auto_awesome': Icons.auto_awesome,
      'menu_book': Icons.menu_book,
    };
    final icon = iconMap[room.icon] ?? Icons.chat_bubble_outline;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primaryGold, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87)),
                  if (room.description != null) ...[
                    const SizedBox(height: 2),
                    Text(room.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                  ],
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: room.isPublic
                            ? Colors.blue.withValues(alpha: 0.12)
                            : Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        room.roomType[0].toUpperCase() + room.roomType.substring(1),
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: room.isPublic ? Colors.blue[700] : Colors.green[700]),
                      ),
                    ),
                    if (!room.isPublic && room.memberCount != null) ...[
                      const SizedBox(width: 6),
                      Text('${room.memberCount} members',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                    ],
                  ]),
                  if (room.lastMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${room.lastMessage!.senderName.split(' ').first}: ${room.lastMessage!.text}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ],
        ),
      ),
    );
  }
}
