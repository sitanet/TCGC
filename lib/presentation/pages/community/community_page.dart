import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/providers/listen_together_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/app_image.dart';
import '../../widgets/community/share_to_community_sheet.dart';
import '../audio/audio_player_page.dart';
import '../audio/transcript_list_page.dart';
import 'chat_room_page.dart';
import '../auth/auth_flow_page.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _checkingPolicy = true;
  bool _policyAccepted = false;
  bool _policyChecked = false;
  Sermon? _featuredMessage;
  bool _featuredStudied = false;

  String get _policyKey {
    final userId = ref.read(authChangeNotifierProvider).user?.id ?? 'default';
    return 'community_policy_accepted_v1_$userId';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCommunity());
  }

  Future<void> _initCommunity() async {
    if (!ref.read(authChangeNotifierProvider).isAuthenticated) {
      if (!mounted) return;
      setState(() => _checkingPolicy = false);
      return;
    }
    final p = ref.read(communityChangeNotifierProvider);
    await p.loadCachedData();
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_policyKey) ?? false;
    if (!mounted) return;
    setState(() {
      _policyAccepted = accepted;
      _checkingPolicy = false;
    });
    if (accepted) {
      _loadCommunityData();
    }
  }

  void _loadCommunityData() {
    final p = ref.read(communityChangeNotifierProvider);
    // Refresh in the background without blocking cached UI
    p.fetchRooms();
    p.fetchAllMembers();
    p.startHeartbeat();
    _loadFeaturedMessage();
  }

  Future<void> _loadFeaturedMessage() async {
    try {
      final messages = await DataService().getMessages(forceRefresh: false);
      final publicMessages = messages
          .where((s) =>
              !s.isServiceTeamOnly &&
              !s.isGeneralMarriedOnly &&
              !s.isInHouseMarriedOnly)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (publicMessages.isEmpty || !mounted) return;
      final latest = publicMessages.first;
      final prefs = await SharedPreferences.getInstance();
      final studied = prefs.getBool('studied_message_${latest.id}') ?? false;
      if (!mounted) return;
      setState(() {
        _featuredMessage = latest;
        _featuredStudied = studied;
      });
    } catch (_) {}
  }

  Future<void> _toggleFeaturedStudied() async {
    final msg = _featuredMessage;
    if (msg == null) return;
    final next = !_featuredStudied;
    setState(() => _featuredStudied = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('studied_message_${msg.id}', next);
  }

  Future<void> _acceptPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_policyKey, true);
    if (!mounted) return;
    setState(() => _policyAccepted = true);
    _loadCommunityData();
  }

  void _showPolicyDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AppColors.primaryGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Community & Data Policy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _policyBullet(isDark, '1. Respectful Fellowship',
                  'Treat every member with Christian love and respect. Harassment, hate speech, spam, or offensive content is strictly prohibited.'),
              _policyBullet(isDark, '2. Listen Together Etiquette',
                  'Only one member may host a message per room at a time. Keep chat contributions uplifting and relevant.'),
              _policyBullet(isDark, '3. Data Protection & Privacy (NDPR)',
                  'Your name, profile photo, and online status are visible to authenticated church members. Messages, voice notes, and shared files are stored securely solely to provide community fellowship. Never share passwords, PINs, BVN/NIN, or bank details in chat.'),
              _policyBullet(isDark, '4. Moderation & Control',
                  'You can delete your own messages at any time. Admins may remove content or revoke access if these guidelines are violated.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
      backgroundColor: isDark ? const Color(0xFF12100C) : const Color(0xFFF9F3E3),
      appBar: CustomAppBar(
        title: 'Community',
        showBackButton: false,
        lightBackground: !isDark,
        actions: [
          if (_policyAccepted)
            IconButton(
              tooltip: 'Community & Data Policy',
              icon: const Icon(Icons.verified_user_outlined, color: AppColors.primaryGold),
              onPressed: () => _showPolicyDialog(isDark),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF14110C), const Color(0xFF0E0D0A)]
                : [const Color(0xFFFCF7EA), const Color(0xFFF4EAD2)],
          ),
        ),
        child: !ref.watch(authChangeNotifierProvider).isAuthenticated
          ? _buildGuestPreview(isDark)
          : _checkingPolicy
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : !_policyAccepted
              ? _buildPolicyGate(isDark)
              : !p.hasAccess
                  ? _buildNoAccessScreen(isDark)
                  : RefreshIndicator(
        color: AppColors.primaryGold,
        onRefresh: () async {
          await p.fetchRooms();
          await p.fetchAllMembers();
        },
        child: CustomScrollView(
          slivers: [
            // Fellowship Header Banner
            SliverToBoxAdapter(child: _buildHeroHeader(isDark, p)),
            // Search bar
            SliverToBoxAdapter(child: _buildSearchBar(isDark)),
            // Members Strip (all members with online/offline)
            SliverToBoxAdapter(child: _buildMembersStrip(context, isDark, p)),
            // Pinned Message of the Week + Takeaway Prompt
            if (_featuredMessage != null)
              SliverToBoxAdapter(
                  child: _buildFeaturedMessageCard(context, isDark)),
            // Section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: Row(
                  children: [
                    Text('Chat Rooms',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                          color: isDark ? Colors.white : Colors.black87,
                        )),
                    const SizedBox(width: 8),
                    if (p.rooms.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${p.rooms.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Category filter chips (when rooms have categories)
            if (_roomCategories(p.rooms).length > 1)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _roomCategories(p.rooms).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) {
                      final cat = _roomCategories(p.rooms)[idx];
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [AppColors.primaryGold, Color(0xFFB58E24)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : (isDark ? AppColors.cardDark : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : AppColors.primaryGold.withValues(alpha: isDark ? 0.2 : 0.25),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryGold.withValues(alpha: 0.28),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? Colors.black
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Rooms list
            p.isLoading && p.rooms.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryGold)))
                : _filteredRooms(p.rooms).isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  p.error != null ? Icons.cloud_off_rounded : Icons.forum_outlined,
                                  size: 40,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No rooms match "$_searchQuery"'
                                    : (p.error ?? 'No chat rooms available yet.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (p.authExpired)
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final ok = await AuthFlowPage.open(context);
                                    if (ok == true && mounted) {
                                      _loadCommunityData();
                                    }
                                  },
                                  icon: const Icon(Icons.login_rounded, size: 18, color: Colors.black),
                                  label: const Text(
                                    'Sign In Again',
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGold,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                )
                              else
                                TextButton.icon(
                                  onPressed: () {
                                    p.fetchRooms();
                                    p.fetchAllMembers();
                                  },
                                  icon: const Icon(Icons.refresh, color: AppColors.primaryGold, size: 18),
                                  label: const Text('Refresh', style: TextStyle(color: AppColors.primaryGold)),
                                ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final listenState = ref.watch(listenTogetherProvider);
                            final activeLocalRoomId =
                                listenState.isJoined ? listenState.currentRoomId : null;
                            final rooms = _filteredRooms(p.rooms, p, activeLocalRoomId);
                            final room = rooms[i];
                            final isHosting =
                                _isRoomCurrentlyHosting(room, p, activeLocalRoomId);
                            final catLabel = room.categoryName ?? 'General';
                            final prevIsHosting = i > 0 &&
                                _isRoomCurrentlyHosting(rooms[i - 1], p, activeLocalRoomId);

                            String? sectionHeader;
                            if (isHosting) {
                              if (i == 0) sectionHeader = 'LIVE HOSTING';
                            } else if (_selectedCategory == 'All' &&
                                _roomCategories(p.rooms).length > 1) {
                              final prevCat =
                                  i > 0 ? (rooms[i - 1].categoryName ?? 'General') : null;
                              if (i == 0 || prevIsHosting || prevCat != catLabel) {
                                sectionHeader = catLabel.toUpperCase();
                              }
                            }

                            if (sectionHeader == null) {
                              return _buildRoomTile(
                                context,
                                isDark,
                                room,
                                p,
                                isHosting: isHosting,
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                                  child: Row(
                                    children: [
                                      if (isHosting) ...[
                                        Container(
                                          width: 7,
                                          height: 7,
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: const BoxDecoration(
                                            color: Colors.greenAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                      Text(
                                        sectionHeader,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.9,
                                          color: isHosting
                                              ? Colors.green
                                              : AppColors.primaryGold.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildRoomTile(
                                  context,
                                  isDark,
                                  room,
                                  p,
                                  isHosting: isHosting,
                                ),
                              ],
                            );
                          },
                          childCount: _filteredRooms(
                            p.rooms,
                            p,
                            ref.watch(listenTogetherProvider).isJoined
                                ? ref.watch(listenTogetherProvider).currentRoomId
                                : null,
                          ).length,
                        ),
                      ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      ),
    );
  }

  List<String> _roomCategories(List<CommunityRoom> rooms) {
    final hasUncategorized = rooms.any((r) => (r.categoryName ?? '').isEmpty);
    final seen = <String>{};
    final ordered = <String>[];
    for (final r in rooms) {
      final name = r.categoryName;
      if (name != null && name.isNotEmpty && seen.add(name)) {
        ordered.add(name);
      }
    }
    if (ordered.isEmpty) return ['All'];
    return ['All', ...ordered, if (hasUncategorized) 'General'];
  }

  bool _isRoomCurrentlyHosting(
    CommunityRoom room,
    CommunityProvider p,
    int? activeLocalRoomId,
  ) {
    return p.isRoomHosting(room.id) ||
        (activeLocalRoomId != null && room.id == activeLocalRoomId);
  }

  List<CommunityRoom> _filteredRooms(
    List<CommunityRoom> rooms, [
    CommunityProvider? p,
    int? activeLocalRoomId,
  ]) {
    final filtered = rooms.where((r) {
      if (_selectedCategory != 'All') {
        final cat = (r.categoryName != null && r.categoryName!.isNotEmpty)
            ? r.categoryName!
            : 'General';
        if (cat != _selectedCategory) return false;
      }
      if (_searchQuery.isEmpty) return true;
      return r.name.toLowerCase().contains(_searchQuery) ||
          (r.description ?? '').toLowerCase().contains(_searchQuery) ||
          (r.categoryName ?? '').toLowerCase().contains(_searchQuery);
    }).toList();

    if (p != null) {
      final hosting = <CommunityRoom>[];
      final others = <CommunityRoom>[];
      for (final r in filtered) {
        if (_isRoomCurrentlyHosting(r, p, activeLocalRoomId)) {
          hosting.add(r);
        } else {
          others.add(r);
        }
      }
      return [...hosting, ...others];
    }
    return filtered;
  }

  Widget _buildHeroHeader(bool isDark, CommunityProvider p) {
    final onlineCount = p.allMembers.where((m) => m.isOnline).length;
    final liveRoomsCount = p.rooms.where((r) => p.isRoomHosting(r.id)).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF231D12), Color(0xFF12100B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: 0.65),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: isDark ? 0.16 : 0.24),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.goldVariant1, AppColors.primaryGold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.forum_rounded, color: Colors.black, size: 25),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TCGC Community Fellowship',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Chat with members & listen to messages together',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.goldVariant2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroStatPill(
                isDark,
                dotColor: Colors.greenAccent,
                label: '$onlineCount Online',
                textColor: Colors.greenAccent,
                bgColor: Colors.green.withValues(alpha: 0.18),
                borderColor: Colors.greenAccent.withValues(alpha: 0.35),
              ),
              _heroStatPill(
                isDark,
                icon: Icons.groups_rounded,
                label: '${p.rooms.length} Rooms',
                textColor: AppColors.goldVariant2,
                bgColor: AppColors.primaryGold.withValues(alpha: 0.18),
                borderColor: AppColors.primaryGold.withValues(alpha: 0.45),
              ),
              if (liveRoomsCount > 0)
                _heroStatPill(
                  isDark,
                  icon: Icons.headphones_rounded,
                  label: '$liveRoomsCount Live Listening',
                  textColor: Colors.greenAccent,
                  bgColor: Colors.green.withValues(alpha: 0.18),
                  borderColor: Colors.greenAccent.withValues(alpha: 0.4),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStatPill(
    bool isDark, {
    Color? dotColor,
    IconData? icon,
    required String label,
    required Color textColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search members or chat rooms...',
          hintStyle: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryGold, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: isDark ? AppColors.cardDark : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.primaryGold.withValues(alpha: isDark ? 0.22 : 0.24),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _policyBullet(bool isDark, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? AppColors.textSecondaryDark : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestPreview(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon badge
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGold.withValues(alpha: 0.25),
                    AppColors.primaryGold.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGold.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 44,
                color: AppColors.primaryGold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Join Our Community',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Connect with fellow members, join chat rooms, share prayer requests, and listen to messages together in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 28),
            // Feature highlights
            _buildGuestFeatureRow(
              isDark,
              Icons.forum_rounded,
              'Chat Rooms',
              'Fellowship with units & groups',
            ),
            const SizedBox(height: 12),
            _buildGuestFeatureRow(
              isDark,
              Icons.headphones_rounded,
              'Listen Together',
              'Stream messages in sync with members',
            ),
            const SizedBox(height: 12),
            _buildGuestFeatureRow(
              isDark,
              Icons.people_rounded,
              'Online Members',
              'See who is online & connect live',
            ),
            const SizedBox(height: 32),
            // Sign In button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => AuthFlowPage.open(context),
                icon: const Icon(Icons.login_rounded, size: 18, color: Colors.black),
                label: const Text(
                  'Sign In to Join Community',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Create account button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => AuthFlowPage.open(context, isSignUp: true),
                icon: const Icon(Icons.person_add_rounded, size: 18, color: AppColors.primaryGold),
                label: const Text(
                  'Create Free Account',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryGold, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestFeatureRow(bool isDark, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryGold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyGate(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2B2415), const Color(0xFF1C1912)]
                    : [const Color(0xFFFFF8E7), const Color(0xFFFDF2D6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_rounded,
                      color: AppColors.primaryGold, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  'Community Guidelines & Data Protection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome! Please review how our church community works and how your data is protected before joining.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _policyBullet(
                  isDark,
                  '1. Respectful Christian Fellowship',
                  'Speak with grace, love, and respect. Harassment, hate speech, spam, or inappropriate content is strictly prohibited.',
                ),
                _policyBullet(
                  isDark,
                  '2. Listen Together & Room Etiquette',
                  'Any member can join a group, host a sermon when no host is active, and contribute via text, voice notes, or reactions.',
                ),
                _policyBullet(
                  isDark,
                  '3. Data Protection & Privacy (NDPR)',
                  'Your name, profile photo, and online status are visible to authenticated TCGC members. Messages, voice notes, and shared files are stored securely solely to deliver community fellowship. Never share passwords, PINs, BVN/NIN, or bank details in chat.',
                ),
                _policyBullet(
                  isDark,
                  '4. Your Control & Safety',
                  'You can delete your own messages anytime. Admins may remove content or restrict access if these guidelines are violated.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => setState(() => _policyChecked = !_policyChecked),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: _policyChecked,
                    activeColor: AppColors.primaryGold,
                    onChanged: (v) => setState(() => _policyChecked = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'I have read and agree to the Community Guidelines & Data Protection Policy.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _policyChecked ? _acceptPolicy : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                disabledBackgroundColor: AppColors.primaryGold.withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Accept & Enter Community',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
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

  Widget _buildFeaturedMessageCard(BuildContext context, bool isDark) {
    final sermon = _featuredMessage!;
    final hasTranscript =
        sermon.transcript != null && sermon.transcript!.trim().isNotEmpty;
    final dateStr =
        '${sermon.date.day}/${sermon.date.month}/${sermon.date.year}';
    final subtitleParts = <String>[
      if (sermon.speaker != null && sermon.speaker!.trim().isNotEmpty)
        sermon.speaker!.trim(),
      dateStr,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: isDark ? 0.28 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: isDark ? 0.08 : 0.09),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 13, color: AppColors.primaryGold),
                    SizedBox(width: 5),
                    Text(
                      'MESSAGE OF THE WEEK',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.primaryGold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _toggleFeaturedStudied,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _featuredStudied
                        ? Colors.green.withValues(alpha: 0.14)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _featuredStudied
                          ? Colors.green.withValues(alpha: 0.5)
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _featuredStudied
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: _featuredStudied
                            ? (isDark ? Colors.greenAccent : Colors.green[700])
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _featuredStudied ? 'Studied' : 'Mark Studied',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _featuredStudied
                              ? (isDark
                                  ? Colors.greenAccent
                                  : Colors.green[800])
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: sermon.imageUrl != null && sermon.imageUrl!.isNotEmpty
                    ? AppImage(
                        imagePath: sermon.imageUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 52,
                        height: 52,
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                        child: const Icon(Icons.headphones_rounded,
                            color: AppColors.primaryGold, size: 26),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sermon.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'What stood out to you most? Listen and share your takeaway with the fellowship.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AudioPlayerPage(sermon: sermon),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded,
                    size: 16, color: Colors.black),
                label: const Text(
                  'Listen',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              if (hasTranscript)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TranscriptViewPage(
                          overrideUrl: sermon.transcript,
                          overrideTitle: sermon.title,
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.article_outlined,
                    size: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  label: Text(
                    'Transcript',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () {
                  ShareToCommunitySheet.show(
                    context,
                    resourceType: 'audio',
                    resourceId: int.tryParse(sermon.id),
                    resourceTitle: sermon.title,
                    fallbackUrl:
                        'https://tcgc.thecitygatechurch.org/app/message/${sermon.id}/',
                  );
                },
                icon: const Icon(Icons.forum_outlined,
                    size: 15, color: AppColors.primaryGold),
                label: const Text(
                  'Share Takeaway',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGold,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor:
                      AppColors.primaryGold.withValues(alpha: 0.12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembersStrip(BuildContext context, bool isDark, CommunityProvider p) {
    final filtered = (_searchQuery.isEmpty
            ? p.allMembers
            : p.allMembers
                .where((m) => m.name.toLowerCase().contains(_searchQuery)))
        .toList()
      ..sort((a, b) {
        if (a.isOnline == b.isOnline) return 0;
        return a.isOnline ? -1 : 1;
      });
    final onlineCount = filtered.where((m) => m.isOnline).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: isDark ? 0.16 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: isDark ? 0.06 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 17, color: AppColors.primaryGold),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Fellowship Members',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$onlineCount / ${filtered.length} online',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.greenAccent : Colors.green[800],
                  ),
                ),
              ),
            ],
          ),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final member = filtered[i];
                  final showDivider =
                      i > 0 && !member.isOnline && filtered[i - 1].isOnline;
                  if (!showDivider) return _buildMemberAvatar(isDark, member);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 1,
                        height: 52,
                        margin: const EdgeInsets.only(right: 12, bottom: 8),
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                      _buildMemberAvatar(isDark, member),
                    ],
                  );
                },
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty ? 'No members found' : 'No members yet',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(bool isDark, OnlineMember m) {
    final isOnline = m.isOnline;
    final content = Container(
      margin: EdgeInsets.only(right: isOnline ? 10 : 8),
      padding: EdgeInsets.symmetric(horizontal: isOnline ? 8 : 4, vertical: 6),
      decoration: isOnline
          ? BoxDecoration(
              color: Colors.green.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withValues(alpha: isDark ? 0.45 : 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: isDark ? 0.12 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                padding: EdgeInsets.all(isOnline ? 2.5 : 1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isOnline
                      ? const LinearGradient(
                          colors: [Color(0xFF22C55E), AppColors.primaryGold],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  border: isOnline
                      ? null
                      : Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                          width: 1.5,
                        ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: isOnline
                      ? AppColors.primaryGold.withValues(alpha: 0.2)
                      : (isDark ? Colors.white10 : Colors.grey.shade200),
                  child: m.photoUrl != null
                      ? ClipOval(
                          child: AppImage(
                              imagePath: m.photoUrl!, width: 44, height: 44))
                      : Text(
                          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: isOnline
                                ? AppColors.primaryGold
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: isOnline ? 13 : 11,
                  height: isOnline ? 13 : 11,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xFF22C55E)
                        : Colors.grey.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 56,
            child: Text(
              m.name.split(' ').first,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isOnline ? FontWeight.w700 : FontWeight.normal,
                color: isDark
                    ? (isOnline ? Colors.white : AppColors.textSecondaryDark)
                    : (isOnline ? Colors.black87 : AppColors.textSecondaryLight),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => _openDm(m),
      child: isOnline ? content : Opacity(opacity: 0.58, child: content),
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

  Future<void> _confirmStopHosting(
    BuildContext context,
    CommunityRoom room,
    CommunityProvider p,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Stop Live Hosting?'),
        content: Text(
          'This will end the live hosted message in "${room.name}" so it is no longer live.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop Hosting'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(listenTogetherProvider.notifier)
        .forceEndRoomSession(room.id);
    if (ok && mounted) {
      await p.fetchRooms();
      await p.refreshHostingRooms();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stopped live hosting in "${room.name}"')),
        );
      }
    }
  }

  Widget _buildRoomTile(
    BuildContext context,
    bool isDark,
    CommunityRoom room,
    CommunityProvider p, {
    bool isHosting = false,
  }) {
    final iconMap = {
      'chat_bubble_outline': Icons.chat_bubble_outline,
      'volunteer_activism': Icons.volunteer_activism,
      'auto_awesome': Icons.auto_awesome,
      'menu_book': Icons.menu_book,
      'headphones': Icons.headphones_rounded,
    };
    final icon = iconMap[room.icon] ?? Icons.chat_bubble_outline;
    final badgeColor = room.isPublic
        ? AppColors.primaryGold
        : (room.roomType == 'group' ? const Color(0xFFB58E24) : const Color(0xFF78716C));
    final badgeTextColor = room.isPublic
        ? (isDark ? AppColors.primaryGold : const Color(0xFF8C6B14))
        : (room.roomType == 'group'
            ? (isDark ? const Color(0xFFE5C86E) : const Color(0xFF7C5D10))
            : (isDark ? Colors.white70 : const Color(0xFF57534E)));
    final badgeIcon = room.isPublic
        ? Icons.public_rounded
        : (room.roomType == 'group' ? Icons.groups_rounded : Icons.lock_rounded);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
        );
        p.refreshHostingRooms();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: isHosting
              ? LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF152419), AppColors.cardDark]
                      : [const Color(0xFFF3FBF5), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isHosting ? null : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHosting
                ? Colors.green.withValues(alpha: 0.55)
                : AppColors.primaryGold.withValues(alpha: isDark ? 0.18 : 0.2),
            width: isHosting ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isHosting ? Colors.green : Colors.black)
                  .withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isHosting
                      ? [
                          Colors.green.withValues(alpha: 0.24),
                          Colors.green.withValues(alpha: 0.08),
                        ]
                      : [
                          AppColors.primaryGold.withValues(alpha: 0.24),
                          AppColors.primaryGold.withValues(alpha: 0.08),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: (isHosting ? Colors.green : AppColors.primaryGold)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                isHosting ? Icons.headphones_rounded : icon,
                color: isHosting ? Colors.green : AppColors.primaryGold,
                size: 25,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.28),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 11, color: badgeTextColor),
                            const SizedBox(width: 4),
                            Text(
                              room.roomType[0].toUpperCase() + room.roomType.substring(1),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isHosting) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.headphones_rounded, size: 11, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final url = 'https://tcgc.thecitygatechurch.org/app/community/${room.id}/';
                            final session = p.activeSessionForRoom(room.id);
                            final title = (session != null && session.resourceTitle.isNotEmpty)
                                ? session.resourceTitle
                                : null;
                            final text = title != null
                                ? '🎧 Listen Together LIVE in "${room.name}"!\nNow playing: $title\n\nTap to join the group & listen live:\n$url'
                                : '🎧 Join "${room.name}" — Listen Together LIVE on Citygate Mobile!\n\nTap to join & listen:\n$url';
                            Share.share(text);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryGold.withValues(alpha: 0.45),
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.share_rounded, size: 11, color: AppColors.primaryGold),
                                SizedBox(width: 4),
                                Text(
                                  'Share',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (const [
                          'super_admin',
                          'admin',
                          'admin_operational',
                          'media',
                          'pastorate',
                        ].contains(ref.read(authChangeNotifierProvider).user?.role))
                          GestureDetector(
                            onTap: () => _confirmStopHosting(context, room, p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(alpha: 0.45),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.stop_circle_rounded, size: 11, color: Colors.redAccent),
                                  SizedBox(width: 4),
                                  Text(
                                    'Stop',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (room.description != null && room.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      room.description!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (!room.isPublic && room.memberCount != null) ...[
                        Icon(
                          Icons.people_outline_rounded,
                          size: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${room.memberCount} members',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        if (room.lastMessage != null)
                          Text(
                            ' · ',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                      ],
                      if (room.lastMessage != null)
                        Expanded(
                          child: Text(
                            '${room.lastMessage!.senderName.split(' ').first}: ${room.lastMessage!.text}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else if (room.isPublic || room.memberCount == null)
                        Text(
                          'Tap to join the conversation',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryGold, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
