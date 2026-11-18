import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/community_provider.dart';
import '../../../core/providers/listen_together_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/app_image.dart';
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
                  'Only one member may host a sermon per room at a time. Keep chat contributions uplifting and relevant.'),
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
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
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
      body: !ref.watch(authChangeNotifierProvider).isAuthenticated
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
                        backgroundColor: isDark ? AppColors.cardDark : const Color(0xFFF2F2F2),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2B2415), const Color(0xFF1C1912)]
              : [const Color(0xFFFFF8E7), const Color(0xFFFDF2D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: isDark ? 0.35 : 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryGold, Color(0xFFB8941F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.forum_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fellowship & Lounge',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Chat with members & listen to sermons together',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  '$onlineCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.greenAccent : Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search members or chat rooms...',
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
              'Connect with fellow church members, join chat rooms, share prayer requests, and listen to sermons together in real time.',
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
              'Fellowship with church units & groups',
            ),
            const SizedBox(height: 12),
            _buildGuestFeatureRow(
              isDark,
              Icons.headphones_rounded,
              'Listen Together',
              'Stream sermons in sync with members',
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
        ? Colors.blue
        : (room.roomType == 'group' ? Colors.teal : Colors.deepPurple);
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHosting
                ? Colors.green.withValues(alpha: 0.55)
                : AppColors.primaryGold.withValues(alpha: isDark ? 0.16 : 0.14),
            width: isHosting ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                  colors: [
                    AppColors.primaryGold.withValues(alpha: 0.22),
                    AppColors.primaryGold.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppColors.primaryGold.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(icon, color: AppColors.primaryGold, size: 25),
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
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHosting) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.headphones_rounded, size: 11, color: Colors.green),
                              SizedBox(width: 3),
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
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 11, color: badgeColor),
                            const SizedBox(width: 4),
                            Text(
                              room.roomType[0].toUpperCase() + room.roomType.substring(1),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? badgeColor.shade200 : badgeColor.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
