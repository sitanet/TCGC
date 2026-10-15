import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_cache_manager.dart';
import '../../../core/providers/audio_player_provider.dart';
import '../../../domain/entities/sermon.dart';
import '../../../data/services/favorites_service.dart';
import '../../../data/services/playlist_service.dart';
import '../../../data/services/download_service.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/playback_position_service.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/password_input_field.dart';
import '../../widgets/animated_play_button.dart';
import '../wallet/give_page.dart';
import '../wallet/wallet_page.dart';

class AudioPlayerPage extends ConsumerStatefulWidget {
  final Sermon sermon;

  const AudioPlayerPage({super.key, required this.sermon});

  @override
  ConsumerState<AudioPlayerPage> createState() => _AudioPlayerPageState();

  /// Check if user can access this sermon
  static bool canAccess(
    Sermon sermon, {
    required bool isServiceTeamMember,
    bool isGeneralMarried = false,
    bool isInHouseMarried = false,
  }) {
    if (sermon.isServiceTeamOnly && !isServiceTeamMember) return false;
    if (sermon.isGeneralMarriedOnly && !isGeneralMarried) return false;
    if (sermon.isInHouseMarriedOnly && !isInHouseMarried) return false;
    return true;
  }
}

class _AudioPlayerPageState extends ConsumerState<AudioPlayerPage> {
  final FavoritesService _favoritesService = FavoritesService();
  final PlaylistService _playlistService = PlaylistService();
  final DownloadService _downloadService = DownloadService();
  final DataService _dataService = DataService();

  SpeakerModel? _speaker;
  List<Sermon> _otherMessages = [];
  List<Sermon> _relatedCategoryMessages = [];
  bool _isLoadingRelatedCategory = true;
  bool _showRemainingTime = true;

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _initializeServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccessAndPlay();
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        _loadSpeakerInfo();
        _loadRelatedCategoryMessages();
      });
    });
  }

  Future<void> _loadSpeakerInfo() async {
    debugPrint('=== LOADING SPEAKER INFO ===');
    debugPrint('Sermon speaker: "${widget.sermon.speaker}"');
    if (widget.sermon.speaker == null || widget.sermon.speaker!.isEmpty) {
      debugPrint('Speaker is null or empty, skipping');
      return;
    }

    try {
      List<SpeakerModel> speakers = [];
      try {
        speakers = await _dataService.getSpeakers();
        debugPrint('Got ${speakers.length} speakers from API');
      } catch (e) {
        debugPrint('Failed to fetch speakers: $e');
        // Continue without speaker profile - will try to get messages directly
      }

      final sermonSpeaker = widget.sermon.speaker!.toLowerCase().trim();

      // More flexible speaker matching - check for partial matches and contains
      SpeakerModel? speaker;
      for (final s in speakers) {
        final fullNameLower = s.fullName.toLowerCase().trim();
        final nameLower = s.name.toLowerCase().trim();

        // Exact match
        if (fullNameLower == sermonSpeaker || nameLower == sermonSpeaker) {
          speaker = s;
          break;
        }
        // Contains match (e.g., "Pastor John Doe" contains "John Doe")
        if (fullNameLower.contains(sermonSpeaker) ||
            sermonSpeaker.contains(fullNameLower)) {
          speaker = s;
          break;
        }
        if (nameLower.contains(sermonSpeaker) ||
            sermonSpeaker.contains(nameLower)) {
          speaker = s;
          break;
        }
      }

      debugPrint(
        'Match result: ${speaker != null ? "id=${speaker.id}, name=${speaker.fullName}" : "no match"}',
      );

      // Show explore section for all matched speakers
      if (speaker != null) {
        debugPrint('Speaker matched! Loading other messages...');

        // Try to load messages by speaker name
        final messages = await _dataService.getMessagesBySpeaker(
          widget.sermon.speaker!,
        );
        debugPrint(
          'Got ${messages.length} total messages from speaker "${widget.sermon.speaker}"',
        );

        final otherMessages = messages
            .where((m) => m.id != widget.sermon.id)
            .take(5)
            .toList();
        debugPrint(
          'Found ${otherMessages.length} other messages (excluding current)',
        );

        if (mounted) {
          setState(() {
            _speaker = speaker;
            _otherMessages = otherMessages;
          });
        }
      } else {
        debugPrint('Speaker not found in speakers list');
        // Still try to get messages by speaker name even without a speaker profile match
        final messages = await _dataService.getMessagesBySpeaker(
          widget.sermon.speaker!,
        );
        if (messages.isNotEmpty) {
          debugPrint(
            'Found ${messages.length} messages by speaker name (no profile)',
          );
          final otherMessages = messages
              .where((m) => m.id != widget.sermon.id)
              .take(5)
              .toList();
          if (otherMessages.isNotEmpty && mounted) {
            // Create a minimal speaker model for display
            setState(() {
              _speaker = SpeakerModel(
                id: -1, // Mark as no profile
                name: widget.sermon.speaker!,
                fullName: widget.sermon.speaker!,
              );
              _otherMessages = otherMessages;
            });
          }
        }
      }
    } catch (e, st) {
      debugPrint('Error loading speaker info: $e');
      debugPrint('Stack: $st');
    }
  }

  Future<void> _loadRelatedCategoryMessages() async {
    try {
      List<Sermon> categoryMessages = [];

      // 1. Try loading by category ID / category string
      if (widget.sermon.category.isNotEmpty) {
        categoryMessages = await _dataService.getMessagesByCategory(widget.sermon.category);
      }

      // 2. Fallback to category name if category ID returned no items
      if (categoryMessages.isEmpty && widget.sermon.categoryName.isNotEmpty) {
        categoryMessages = await _dataService.getMessagesByCategoryName(widget.sermon.categoryName);
      }

      // 3. Fallback: load all messages and filter by category or categoryName
      if (categoryMessages.isEmpty) {
        final allMessages = await _dataService.getMessages();
        categoryMessages = allMessages.where((m) =>
          (widget.sermon.category.isNotEmpty && m.category == widget.sermon.category) ||
          (widget.sermon.categoryName.isNotEmpty && m.categoryName.toLowerCase() == widget.sermon.categoryName.toLowerCase())
        ).toList();
      }

      // Filter out the currently playing sermon
      final filteredCategoryMessages = categoryMessages
          .where((m) => m.id != widget.sermon.id)
          .toList();

      if (mounted) {
        setState(() {
          _relatedCategoryMessages = filteredCategoryMessages;
          _isLoadingRelatedCategory = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading related category messages: $e');
      if (mounted) {
        setState(() {
          _isLoadingRelatedCategory = false;
        });
      }
    }
  }

  void _checkAccessAndPlay() {
    final authProvider = ref.read(authChangeNotifierProvider);
    final user = authProvider.user;
    final isServiceTeamMember = user?.isServiceTeamMember ?? false;
    final isGeneralMarried = user?.isGeneralMarried ?? false;
    final isInHouseMarried = user?.isInHouseMarried ?? false;

    final canAccess = AudioPlayerPage.canAccess(
      widget.sermon,
      isServiceTeamMember: isServiceTeamMember,
      isGeneralMarried: isGeneralMarried,
      isInHouseMarried: isInHouseMarried,
    );

    if (!canAccess) {
      _showAccessDeniedDialog();
    } else {
      _handlePlayback();
    }
  }

  String _getAccessDeniedMessage() {
    if (widget.sermon.isServiceTeamOnly) {
      return 'This message is only available for Service Team members.';
    } else if (widget.sermon.isGeneralMarriedOnly) {
      return 'This message is only available for General Married members.';
    } else if (widget.sermon.isInHouseMarriedOnly) {
      return 'This message is only available for In-House Married members.';
    }
    return 'You do not have access to this content.';
  }

  void _showAccessDeniedDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock, color: AppColors.primaryGold),
            const SizedBox(width: 8),
            const Text('Restricted Content'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(_getAccessDeniedMessage(), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Please contact an administrator if you believe you should have access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlayback() async {
    if (!mounted) return;

    final audioProvider = ref.read(audioPlayerChangeNotifierProvider);

    // If this sermon is already playing, don't restart
    if (audioProvider.currentSermon?.id == widget.sermon.id &&
        (audioProvider.isPlaying || audioProvider.isLoading)) {
      return;
    }

    final savedPosition = audioProvider.getSavedPosition(widget.sermon.id);

    if (savedPosition != null && savedPosition.isSignificant) {
      // Start playing immediately from where the user left off
      audioProvider.playSermonFromPosition(
        widget.sermon,
        savedPosition.position,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resumed from ${savedPosition.formattedPosition}'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Start over',
              textColor: AppColors.primaryGold,
              onPressed: () {
                audioProvider.clearSavedPosition(widget.sermon.id);
                audioProvider.seek(Duration.zero);
              },
            ),
          ),
        );
      }
    } else {
      await audioProvider.playSermon(widget.sermon);
    }
  }

  // ignore: unused_element
  void _showResumeDialog(PlaybackPosition savedPosition) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resume Playback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 48,
              color: AppColors.primaryGold,
            ),
            const SizedBox(height: 16),
            Text(
              'You were at ${savedPosition.formattedPosition} of ${savedPosition.formattedDuration}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Would you like to continue where you left off?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final audioProvider = ref.read(audioPlayerChangeNotifierProvider);
              audioProvider.clearSavedPosition(widget.sermon.id);
              audioProvider.playSermon(widget.sermon);
            },
            child: Text(
              'Start Over',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final audioProvider = ref.read(audioPlayerChangeNotifierProvider);
              audioProvider.playSermonFromPosition(
                widget.sermon,
                savedPosition.position,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeServices() async {
    await _favoritesService.initialize();
    await _playlistService.initialize();
    await _downloadService.initialize();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final errorMessage = audioProvider.errorMessage;

    // Show rating dialog after first successful play
    ref.listen<AudioPlayerProvider>(audioPlayerChangeNotifierProvider, (
      previous,
      next,
    ) {
      if (next.shouldShowRatingPopup && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            next.showRatingDialogIfNeeded(context);
          }
        });
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: CustomAppBar(
          title: widget.sermon.categoryName.isNotEmpty
              ? widget.sermon.categoryName
              : widget.sermon.category,
          lightBackground: true,
          actions: [
            if (!ref.watch(appConfigChangeNotifierProvider).config.walletPageDisabled)
              IconButton(
                onPressed: () => _showGivingBottomSheet(context, isDark),
                icon: Icon(
                  Icons.volunteer_activism,
                  color: AppColors.primaryGold,
                ),
                tooltip: 'Give an Offering',
              ),
            IconButton(
              onPressed: () => _showActionsBottomSheet(context, isDark),
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
            ),
          ],
        ),
        body: Builder(
          builder: (context) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  _buildAlbumArt(isDark, audioProvider.isPlaying),
                  const SizedBox(height: 24),
                  _buildSongInfo(context),
                  const SizedBox(height: 20),
                  _buildQuickActionsRow(isDark, audioProvider),
                  const SizedBox(height: 24),
                  _buildProgressBar(isDark, audioProvider),
                  const SizedBox(height: 20),
                  _buildControlsWithSpeed(isDark, audioProvider),
                  const SizedBox(height: 16),
                  if (errorMessage != null)
                    _buildCompactDownloadNotice(isDark, audioProvider),
                  const SizedBox(height: 24),
                  _buildRelatedCategorySection(isDark),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRelatedCategorySection(bool isDark) {
    if (_isLoadingRelatedCategory || _relatedCategoryMessages.isEmpty) {
      return const SizedBox.shrink();
    }

    final categoryTitle = widget.sermon.categoryName.isNotEmpty
        ? widget.sermon.categoryName
        : 'Related Messages';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 20),

        // Section Header Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                size: 20,
                color: AppColors.primaryGold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More in $categoryTitle',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_relatedCategoryMessages.length} related messages',
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
        const SizedBox(height: 18),

        // Horizontal Carousel List
        SizedBox(
          height: 225,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _relatedCategoryMessages.length,
            itemBuilder: (context, index) {
              final message = _relatedCategoryMessages[index];
              return _buildRelatedCategoryCard(message, isDark);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRelatedCategoryCard(Sermon message, bool isDark) {
    final speakerName = message.speaker != null && message.speaker!.isNotEmpty
        ? message.speaker!
        : 'TCGC';

    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AudioPlayerPage(sermon: message)),
        );
      },
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 1:1 Square Poster Artwork Card
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: message.imageUrl != null && message.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: message.imageUrl!,
                                cacheManager: CustomImageCacheManager.instance,
                                fit: BoxFit.cover,
                                memCacheWidth: 310,
                                memCacheHeight: 310,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholder: (_, __) => Container(
                                  color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                                  child: const Icon(Icons.music_note, size: 32, color: AppColors.primaryGold),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                                  child: const Icon(Icons.music_note, size: 32, color: AppColors.primaryGold),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryGold.withValues(alpha: 0.7),
                                      isDark ? AppColors.cardDark : const Color(0xFF1E293B),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(Icons.music_note, size: 36, color: Colors.white),
                                ),
                              ),
                      ),
                      // Floating Play Button
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2. Title directly below artwork card
            Text(
              message.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.2,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),

            const SizedBox(height: 2),

            // 3. Speaker Subtitle
            Text(
              speakerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primaryGold,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherMessageItem(Sermon message, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AudioPlayerPage(sermon: message)),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with play button overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child:
                      message.imageUrl != null && message.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: message.imageUrl!,
                          cacheManager: CustomImageCacheManager.instance,
                          width: 150,
                          height: 95,
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                          memCacheHeight: 190,
                          useOldImageOnUrlChange: true,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (_, __) => Container(
                            width: 150,
                            height: 95,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryGold.withOpacity(0.3),
                                  isDark
                                      ? AppColors.cardDark
                                      : AppColors.dividerLight,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(Icons.music_note, size: 32),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 150,
                            height: 95,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryGold.withOpacity(0.3),
                                  isDark
                                      ? AppColors.cardDark
                                      : AppColors.dividerLight,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(Icons.music_note, size: 32),
                          ),
                        )
                      : Container(
                          width: 150,
                          height: 95,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryGold.withOpacity(0.3),
                                isDark
                                    ? AppColors.cardDark
                                    : AppColors.dividerLight,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.music_note, size: 32),
                        ),
                ),
                // Play button overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGold.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          message.categoryName.isNotEmpty
                              ? message.categoryName
                              : message.category,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeakerBioDialog(bool isDark) {
    if (_speaker == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ClipOval(
              child:
                  _speaker!.photoUrl != null && _speaker!.photoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _speaker!.photoUrl!,
                      cacheManager: CustomImageCacheManager.instance,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      useOldImageOnUrlChange: true,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (_, __) => Container(
                        width: 100,
                        height: 100,
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.dividerLight,
                        child: const Icon(Icons.person, size: 50),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.dividerLight,
                        child: const Icon(Icons.person, size: 50),
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                      child: Center(
                        child: Text(
                          _speaker!.fullName.isNotEmpty
                              ? _speaker!.fullName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              _speaker!.fullName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (_speaker!.title != null && _speaker!.title!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _speaker!.title!,
                style: TextStyle(fontSize: 14, color: AppColors.primaryGold),
                textAlign: TextAlign.center,
              ),
            ],
            if (_speaker!.bio != null && _speaker!.bio!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    _speaker!.bio!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'No bio available',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullMinisterPhoto(bool isDark) {
    if (_speaker == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Full screen photo
                    if (_speaker!.photoUrl != null &&
                        _speaker!.photoUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: _speaker!.photoUrl!,
                        cacheManager: CustomImageCacheManager.instance,
                        fit: BoxFit.cover,
                        useOldImageOnUrlChange: true,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, __) => Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.black,
                          child: Center(
                            child: Icon(
                              Icons.person,
                              size: 100,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: isDark
                            ? AppColors.cardDark
                            : AppColors.dividerLight,
                        child: Center(
                          child: Text(
                            _speaker!.fullName.isNotEmpty
                                ? _speaker!.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 120,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGold,
                            ),
                          ),
                        ),
                      ),
                    // Gradient overlay at the bottom for bio
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                              Colors.black.withOpacity(0.9),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            Text(
                              _speaker!.fullName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            // Title
                            if (_speaker!.title != null &&
                                _speaker!.title!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _speaker!.title!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.primaryGold,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            // Bio
                            if (_speaker!.bio != null &&
                                _speaker!.bio!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.3,
                                ),
                                child: SingleChildScrollView(
                                  child: Text(
                                    _speaker!.bio!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Close button
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      right: 16,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSpeedBottomSheet(bool isDark, AudioPlayerProvider audioProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        return Container(
          padding: EdgeInsets.only(top: 16, bottom: 24 + bottomPadding),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Playback Speed',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ...AudioPlayerProvider.availableSpeeds.map(
                (speed) => ListTile(
                  leading: Icon(
                    audioProvider.playbackSpeed == speed
                        ? Icons.check
                        : Icons.speed,
                    color: audioProvider.playbackSpeed == speed
                        ? AppColors.primaryGold
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
                  title: Text(
                    '${speed}x${speed == 1.0 ? ' (Normal)' : ''}',
                    style: TextStyle(
                      fontWeight: audioProvider.playbackSpeed == speed
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: audioProvider.playbackSpeed == speed
                          ? AppColors.primaryGold
                          : null,
                    ),
                  ),
                  onTap: () {
                    audioProvider.setPlaybackSpeed(speed);
                    Navigator.pop(context);
                  },
                ),
              ),
              SizedBox(height: 8 + bottomPadding),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlbumArt(bool isDark, bool isPlaying) {
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = (screenWidth * 0.72).clamp(210.0, 310.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: artSize,
      height: artSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        boxShadow: [
          BoxShadow(
            color: isPlaying
                ? AppColors.primaryGold.withOpacity(isDark ? 0.35 : 0.28)
                : (isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.08)),
            blurRadius: isPlaying ? 32 : 16,
            spreadRadius: isPlaying ? 2 : 0,
            offset: Offset(0, isPlaying ? 12 : 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _buildAlbumImage(isDark, artSize),
      ),
    );
  }

  Widget _buildAlbumImage(bool isDark, double size) {
    if (widget.sermon.imageUrl == null || widget.sermon.imageUrl!.isEmpty) {
      return _buildPlaceholderArt(isDark);
    }
    return CachedNetworkImage(
      imageUrl: widget.sermon.imageUrl!,
      cacheManager: CustomImageCacheManager.instance,
      width: size,
      height: size,
      fit: BoxFit.cover,
      memCacheWidth: 600,
      memCacheHeight: 600,
      useOldImageOnUrlChange: true,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _buildPlaceholderArt(isDark),
      errorWidget: (_, __, ___) => _buildPlaceholderArt(isDark),
    );
  }

  Widget _buildPlaceholderArt(bool isDark) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGold.withOpacity(0.3),
                isDark ? AppColors.cardDark : AppColors.surfaceLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Center(
          child: Icon(
            Icons.music_note,
            size: 80,
            color: AppColors.primaryGold.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSongInfo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final speakerName = widget.sermon.speaker;
    final categoryText = widget.sermon.categoryName.isNotEmpty
        ? widget.sermon.categoryName
        : widget.sermon.category;

    return Column(
      children: [
        Text(
          widget.sermon.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            height: 1.25,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        if (speakerName != null && speakerName.isNotEmpty) ...[
          InkWell(
            onTap: _speaker != null
                ? () {
                    HapticFeedback.lightImpact();
                    _showSpeakerBioDialog(isDark);
                  }
                : null,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primaryGold.withOpacity(0.12)
                    : AppColors.primaryGold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryGold.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppColors.primaryGold,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      speakerName,
                      style: TextStyle(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (categoryText.isNotEmpty) ...[
              Text(
                categoryText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '  •  ',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark.withOpacity(0.5)
                      : AppColors.textSecondaryLight.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ],
            Text(
              _formatDate(widget.sermon.date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
    Widget? customIcon,
    bool isActive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white70 : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              customIcon ??
                  Icon(
                    icon,
                    size: 24,
                    color: iconColor ?? defaultColor,
                  ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: textColor ??
                      (isActive
                          ? AppColors.primaryGold
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(bool isDark, AudioPlayerProvider audioProvider) {
    return AnimatedBuilder(
      animation: Listenable.merge([_favoritesService, _downloadService]),
      builder: (context, _) {
        final isFavorite = _favoritesService.isFavorite(widget.sermon.id);
        final isDownloaded = _downloadService.isDownloaded(widget.sermon.id);
        final isDownloading = _downloadService.isDownloading(widget.sermon.id);
        final downloadProgress = _downloadService.getProgress(widget.sermon.id);
        final isTimerActive = audioProvider.isSleepTimerActive;
        final timerRemaining = audioProvider.sleepTimerRemaining;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardDark.withOpacity(0.5)
                : AppColors.surfaceLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickActionButton(
                icon: isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                iconColor: isFavorite ? Colors.redAccent : null,
                label: isFavorite ? 'Favorited' : 'Favorite',
                isActive: isFavorite,
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await _favoritesService.toggleFavorite(widget.sermon);
                  _trackMessageStat('favorite', !isFavorite);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isFavorite
                              ? 'Removed from favorites'
                              : 'Added to favorites',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              _buildQuickActionButton(
                icon: isDownloaded
                    ? Icons.download_done_rounded
                    : (isDownloading
                        ? Icons.downloading_rounded
                        : Icons.download_outlined),
                iconColor: isDownloaded
                    ? Colors.green
                    : (isDownloading ? AppColors.primaryGold : null),
                customIcon: isDownloading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: downloadProgress > 0 ? downloadProgress : null,
                          strokeWidth: 2.5,
                          color: AppColors.primaryGold,
                        ),
                      )
                    : null,
                label: isDownloaded
                    ? 'Saved'
                    : (isDownloading
                        ? '${(downloadProgress * 100).toInt()}%'
                        : 'Download'),
                isActive: isDownloaded || isDownloading,
                onTap: isDownloading
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        if (isDownloaded) {
                          _showDeleteDownloadDialog(context, isDark);
                        } else {
                          _showDownloadProgressDialog(context, isDark);
                        }
                      },
              ),
              _buildQuickActionButton(
                icon: Icons.playlist_add_rounded,
                label: 'Playlist',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showPlaylistBottomSheet(context, isDark);
                },
              ),
              _buildQuickActionButton(
                icon: isTimerActive
                    ? Icons.timer_rounded
                    : Icons.timer_outlined,
                iconColor: isTimerActive ? AppColors.primaryGold : null,
                label: isTimerActive
                    ? (timerRemaining != null && timerRemaining.inMinutes > 0
                        ? '${timerRemaining.inMinutes}m left'
                        : '<1m')
                    : 'Sleep Timer',
                isActive: isTimerActive,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showSleepTimerBottomSheet(isDark, audioProvider);
                },
              ),
              _buildQuickActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _shareSermon();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(bool isDark, AudioPlayerProvider audioProvider) {
    final duration = audioProvider.duration;
    final position = audioProvider.position;
    final durationMs = duration.inMilliseconds.toDouble();
    final positionMs = position.inMilliseconds.toDouble();
    final sliderValue = durationMs > 0
        ? (positionMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    final remainingDuration = duration > position
        ? duration - position
        : Duration.zero;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4.5,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 7,
              elevation: 3,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
            activeTrackColor: AppColors.primaryGold,
            inactiveTrackColor: isDark
                ? AppColors.dividerDark
                : AppColors.dividerLight,
            thumbColor: AppColors.primaryGold,
            overlayColor: AppColors.primaryGold.withOpacity(0.18),
          ),
          child: Slider(
            value: sliderValue,
            onChanged: (value) {
              final newPosition = Duration(
                milliseconds: (value * durationMs).toInt(),
              );
              audioProvider.seek(newPosition);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _showRemainingTime = !_showRemainingTime;
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    _showRemainingTime
                        ? '-${_formatDuration(remainingDuration)}'
                        : _formatDuration(duration),
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlsWithSpeed(
    bool isDark,
    AudioPlayerProvider audioProvider,
  ) {
    final isPlaying = audioProvider.isPlaying;
    final isLoading = audioProvider.isLoading;
    final hasNext = audioProvider.hasNext;
    final hasPrevious =
        audioProvider.hasPrevious || audioProvider.position.inSeconds > 3;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'Previous',
              onPressed: isLoading || !hasPrevious
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      await audioProvider.skipToPrevious();
                      if (mounted &&
                          audioProvider.currentSermon != null &&
                          audioProvider.currentSermon!.id != widget.sermon.id) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AudioPlayerPage(
                              sermon: audioProvider.currentSermon!,
                            ),
                          ),
                        );
                      }
                    },
              icon: Icon(
                Icons.skip_previous_rounded,
                size: 34,
                color: hasPrevious
                    ? (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight)
                    : (isDark
                        ? AppColors.textSecondaryDark.withOpacity(0.4)
                        : AppColors.textSecondaryLight.withOpacity(0.4)),
              ),
            ),
            IconButton(
              tooltip: '10s Back',
              onPressed: isLoading
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      audioProvider.seekBackward();
                    },
              icon: Icon(
                Icons.replay_10_rounded,
                size: 30,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            AnimatedPlayButton(
              isPlaying: isPlaying,
              isLoading: isLoading,
              size: 68,
              onTap: () {
                HapticFeedback.mediumImpact();
                if (isPlaying) {
                  audioProvider.pause();
                } else {
                  audioProvider.play();
                }
              },
            ),
            IconButton(
              tooltip: '10s Forward',
              onPressed: isLoading
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      audioProvider.seekForward();
                    },
              icon: Icon(
                Icons.forward_10_rounded,
                size: 30,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            IconButton(
              tooltip: 'Next',
              onPressed: isLoading || !hasNext
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      await audioProvider.skipToNext();
                      if (mounted && audioProvider.currentSermon != null) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AudioPlayerPage(
                              sermon: audioProvider.currentSermon!,
                            ),
                          ),
                        );
                      }
                    },
              icon: Icon(
                Icons.skip_next_rounded,
                size: 34,
                color: hasNext
                    ? (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight)
                    : (isDark
                        ? AppColors.textSecondaryDark.withOpacity(0.4)
                        : AppColors.textSecondaryLight.withOpacity(0.4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showSpeedBottomSheet(isDark, audioProvider);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: audioProvider.playbackSpeed != 1.0
                    ? AppColors.primaryGold
                    : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
                width: audioProvider.playbackSpeed != 1.0 ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.speed_rounded,
                  size: 16,
                  color: AppColors.primaryGold,
                ),
                const SizedBox(width: 6),
                Text(
                  '${audioProvider.playbackSpeed}x Speed',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSleepTimerBottomSheet(
    bool isDark,
    AudioPlayerProvider audioProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final isTimerActive = audioProvider.isSleepTimerActive;
        final remaining = audioProvider.sleepTimerRemaining;

        final options = <Map<String, dynamic>>[
          {'label': '15 minutes', 'duration': const Duration(minutes: 15)},
          {'label': '30 minutes', 'duration': const Duration(minutes: 30)},
          {'label': '45 minutes', 'duration': const Duration(minutes: 45)},
          {'label': '1 hour', 'duration': const Duration(hours: 1)},
          {
            'label': 'End of sermon',
            'duration': audioProvider.duration > audioProvider.position
                ? audioProvider.duration - audioProvider.position
                : const Duration(minutes: 5),
          },
        ];

        return Container(
          padding: EdgeInsets.only(top: 16, bottom: 20 + bottomPadding),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      color: AppColors.primaryGold,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Sleep Timer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (isTimerActive && remaining != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${remaining.inMinutes}m left',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              ...options.map((opt) {
                final Duration duration = opt['duration'] as Duration;
                final String label = opt['label'] as String;
                return ListTile(
                  leading: Icon(
                    Icons.timer_outlined,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  title: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    audioProvider.setSleepTimer(duration);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sleep timer set for $label'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    setState(() {});
                  },
                );
              }),
              if (isTimerActive) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.timer_off_outlined,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Turn off timer',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    audioProvider.cancelSleepTimer();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sleep timer turned off'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    setState(() {});
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactDownloadNotice(
    bool isDark,
    AudioPlayerProvider audioProvider,
  ) {
    final isDownloaded = _downloadService.isDownloaded(widget.sermon.id);
    final isDownloading = _downloadService.isDownloading(widget.sermon.id);
    final downloadProgress = _downloadService.getProgress(widget.sermon.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.orange.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isDownloading ? Icons.downloading : Icons.cloud_off_outlined,
                size: 18,
                color: isDownloading
                    ? AppColors.primaryGold
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : Colors.orange.shade700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDownloading
                      ? 'Downloading... ${(downloadProgress * 100).toInt()}%'
                      : 'Streaming issue',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : Colors.orange.shade900,
                  ),
                ),
              ),
              if (!isDownloading)
                TextButton(
                  onPressed: () {
                    if (isDownloaded) {
                      _downloadService.deleteDownload(widget.sermon.id);
                    }
                    _showDownloadProgressDialog(context, isDark);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isDownloaded ? 'Retry' : 'Download',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ),
              IconButton(
                onPressed: () => audioProvider.clearError(),
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: isDark
                    ? AppColors.textSecondaryDark
                    : Colors.orange.shade700,
              ),
            ],
          ),
          // Progress bar when downloading
          if (isDownloading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: downloadProgress,
                minHeight: 4,
                backgroundColor: isDark
                    ? AppColors.dividerDark
                    : Colors.orange.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showActionsBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isFavorite = _favoritesService.isFavorite(widget.sermon.id);
          final isDownloaded = _downloadService.isDownloaded(widget.sermon.id);
          final isDownloading = _downloadService.isDownloading(
            widget.sermon.id,
          );
          final downloadProgress = _downloadService.getProgress(
            widget.sermon.id,
          );
          final audioProvider = ref.read(audioPlayerChangeNotifierProvider);

          final bottomPadding = MediaQuery.of(context).padding.bottom;

          return Container(
            padding: EdgeInsets.only(top: 16, bottom: 24 + bottomPadding),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.dividerDark
                        : AppColors.dividerLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    '${_formatDate(widget.sermon.date)} - ${widget.sermon.title}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(),
                // Favorite
                ListTile(
                  leading: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : null,
                  ),
                  title: Text(
                    isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  ),
                  onTap: () async {
                    await _favoritesService.toggleFavorite(widget.sermon);
                    // Track favorite action to backend
                    _trackMessageStat('favorite', !isFavorite);
                    setModalState(() {});
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFavorite
                                ? 'Removed from favorites'
                                : 'Added to favorites',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                // Playlist
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text('Add to Playlist'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaylistBottomSheet(context, isDark);
                  },
                ),
                // Download
                ListTile(
                  leading: Icon(
                    isDownloaded
                        ? Icons.download_done
                        : (isDownloading ? Icons.downloading : Icons.download),
                    color: isDownloaded ? Colors.green : null,
                  ),
                  title: Text(
                    isDownloaded
                        ? 'Downloaded'
                        : (isDownloading
                              ? 'Downloading ${(downloadProgress * 100).toInt()}%'
                              : 'Download for Offline'),
                  ),
                  subtitle: isDownloaded ? const Text('Tap to delete') : null,
                  onTap: isDownloading
                      ? null
                      : () {
                          Navigator.pop(context);
                          if (isDownloaded) {
                            _showDeleteDownloadDialog(context, isDark);
                          } else {
                            _showDownloadProgressDialog(context, isDark);
                          }
                        },
                ),
                // Sleep Timer
                ListTile(
                  leading: Icon(
                    Icons.timer_outlined,
                    color: audioProvider.isSleepTimerActive ? AppColors.primaryGold : null,
                  ),
                  title: Text(
                    audioProvider.isSleepTimerActive
                        ? 'Sleep Timer (${audioProvider.sleepTimerRemaining != null && audioProvider.sleepTimerRemaining!.inMinutes > 0 ? "${audioProvider.sleepTimerRemaining!.inMinutes}m left" : "<1m left"})'
                        : 'Sleep Timer',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showSleepTimerBottomSheet(isDark, audioProvider);
                  },
                ),
                // Share
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareSermon();
                  },
                ),
                SizedBox(height: 8 + bottomPadding),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _trackMessageStat(String action, bool added) async {
    try {
      await _dataService.trackMessageStat(
        messageId: widget.sermon.id,
        action: action,
        added: added,
      );
    } catch (e) {
      debugPrint('Failed to track message stat: $e');
    }
  }

  void _shareSermon() {
    final sermon = widget.sermon;
    final shareUrl = 'https://tcgc.thecitygatechurch.org/app/message/${sermon.id}/';
    final formattedTitle = '${_formatDate(sermon.date)} - ${sermon.title}';
    final shareText =
        '''🎧 "$formattedTitle"

${sermon.description}

Listen now: $shareUrl''';
    Share.share(shareText, subject: formattedTitle);
    // Track share action to backend
    _trackMessageStat('share', true);
  }

  void _showDeleteDownloadDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download?'),
        content: const Text(
          'This will remove the downloaded file from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _downloadService.deleteDownload(widget.sermon.id);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDownloadProgressDialog(BuildContext context, bool isDark) {
    // Start the download
    _downloadService.downloadSermon(widget.sermon);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ListenableBuilder(
              listenable: _downloadService,
              builder: (context, child) {
                final progress = _downloadService.getProgress(widget.sermon.id);
                final isDownloading = _downloadService.isDownloading(
                  widget.sermon.id,
                );
                final isDownloaded = _downloadService.isDownloaded(
                  widget.sermon.id,
                );
                final progressPercent = (progress * 100).toInt();

                // Auto close when done
                if (isDownloaded && !isDownloading) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (Navigator.canPop(dialogContext)) {
                      Navigator.pop(dialogContext);
                    }
                    if (mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(child: Text('Download complete!')),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  });
                }

                return AlertDialog(
                  backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // Circular progress indicator with percentage
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 8,
                                backgroundColor: isDark
                                    ? AppColors.dividerDark
                                    : AppColors.dividerLight,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDownloaded
                                      ? Colors.green
                                      : AppColors.primaryGold,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDownloaded
                                      ? Icons.check_circle
                                      : Icons.downloading,
                                  size: 32,
                                  color: isDownloaded
                                      ? Colors.green
                                      : AppColors.primaryGold,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$progressPercent%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDownloaded
                                        ? Colors.green
                                        : AppColors.primaryGold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      Text(
                        isDownloaded ? 'Download Complete!' : 'Downloading...',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Sermon title
                      Text(
                        '${_formatDate(widget.sermon.date)} - ${widget.sermon.title}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      // Linear progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDownloaded ? Colors.green : AppColors.primaryGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Status text
                      Text(
                        isDownloaded
                            ? 'Available for offline playback'
                            : 'Please wait while downloading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  actions: isDownloading
                      ? null
                      : [
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                if (mounted) setState(() {});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDownloaded
                                    ? Colors.green
                                    : AppColors.primaryGold,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(isDownloaded ? 'Done' : 'Close'),
                            ),
                          ),
                        ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showPlaylistBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
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
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.dividerDark
                        : AppColors.dividerLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add to Playlist',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCreatePlaylistDialog(
                      context,
                      isDark,
                      setModalState,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_playlistService.playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.playlist_play,
                          size: 48,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No playlists yet',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _showCreatePlaylistDialog(
                            context,
                            isDark,
                            setModalState,
                          ),
                          child: const Text('Create your first playlist'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _playlistService.playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = _playlistService.playlists[index];
                      final isInPlaylist = _playlistService.isInPlaylist(
                        playlist.id,
                        widget.sermon.id,
                      );
                      return ListTile(
                        leading: Icon(
                          isInPlaylist
                              ? Icons.playlist_add_check
                              : Icons.playlist_play,
                          color: isInPlaylist ? AppColors.primaryGold : null,
                        ),
                        title: Text(playlist.name),
                        subtitle: Text('${playlist.count} songs'),
                        trailing: isInPlaylist
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () async {
                          if (isInPlaylist) {
                            await _playlistService.removeFromPlaylist(
                              playlist.id,
                              widget.sermon.id,
                            );
                          } else {
                            await _playlistService.addToPlaylist(
                              playlist.id,
                              widget.sermon,
                            );
                          }
                          setModalState(() {});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isInPlaylist
                                      ? 'Removed from ${playlist.name}'
                                      : 'Added to ${playlist.name}',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(
    BuildContext context,
    bool isDark,
    StateSetter setModalState,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final playlist = await _playlistService.createPlaylist(name);
                await _playlistService.addToPlaylist(
                  playlist.id,
                  widget.sermon,
                );
                if (mounted) {
                  Navigator.pop(dialogContext);
                  setModalState(() {});
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Added to "$name"')));
                }
              }
            },
            child: const Text('Create & Add'),
          ),
        ],
      ),
    );
  }

  void _showGivingBottomSheet(BuildContext context, bool isDark) {
    final walletProvider = ref.read(walletChangeNotifierProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              Icons.volunteer_activism,
              size: 64,
              color: AppColors.primaryGold,
            ),
            const SizedBox(height: 16),
            Text(
              'Are you blessed by this ministration?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Give an offering by clicking below',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _authenticateAndNavigateToGive(
                    walletProvider.hasWallet,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Give Special Offering',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _authenticateAndNavigateToGive(bool hasWallet) async {
    if (!mounted) return;

    final walletProvider = ref.read(walletChangeNotifierProvider);

    // If no wallet, just navigate to wallet page (no auth needed yet)
    if (!hasWallet) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WalletPage()),
      );
      return;
    }

    // Check if PIN is set
    final hasPin = await walletProvider.checkHasPin();
    if (!hasPin) {
      // No PIN set, just navigate to give page
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GivePage()),
        );
      }
      return;
    }

    // Try biometric authentication first
    final biometricProvider = ref.read(biometricChangeNotifierProvider);
    await biometricProvider.initialize();

    if (biometricProvider.biometricTransactionEnabled &&
        biometricProvider.isAvailable) {
      final authenticated = await biometricProvider
          .authenticateForTransaction();
      if (authenticated && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GivePage()),
        );
        return;
      }
    }

    // Fall back to PIN dialog
    if (mounted) {
      _showGivePinDialog();
    }
  }

  void _showGivePinDialog() {
    final pinController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isVerifying = false;

    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.primaryGold, size: 24),
              const SizedBox(width: 8),
              const Text('Enter Transaction PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your PIN to continue',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    letterSpacing: 8,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGold,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                ),
                onSubmitted: (_) async {
                  if (pinController.text.isEmpty || isVerifying) return;
                  setDialogState(() => isVerifying = true);

                  final walletProvider = ref.read(walletChangeNotifierProvider);
                  final isValid = await walletProvider.verifyPin(
                    pinController.text,
                  );

                  if (!mounted) return;

                  if (isValid) {
                    Navigator.pop(dialogContext, true);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GivePage()),
                    );
                  } else {
                    setDialogState(() => isVerifying = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid PIN. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    pinController.clear();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      if (pinController.text.isEmpty) return;
                      setDialogState(() => isVerifying = true);

                      final walletProvider = ref.read(
                        walletChangeNotifierProvider,
                      );
                      final isValid = await walletProvider.verifyPin(
                        pinController.text,
                      );

                      if (!mounted) return;

                      if (isValid) {
                        Navigator.pop(dialogContext, true);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GivePage()),
                        );
                      } else {
                        setDialogState(() => isVerifying = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid PIN. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        pinController.clear();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
