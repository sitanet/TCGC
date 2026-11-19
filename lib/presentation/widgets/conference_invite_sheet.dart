import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart';

enum ConferenceSession { all, morning, evening }
enum ConferenceStreamType { audio, video }

class ConferenceInviteSheet extends ConsumerStatefulWidget {
  final ConferenceStreamType initialStreamType;

  const ConferenceInviteSheet({
    super.key,
    this.initialStreamType = ConferenceStreamType.audio,
  });

  static Future<void> show(
    BuildContext context, {
    ConferenceStreamType initialStreamType = ConferenceStreamType.audio,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConferenceInviteSheet(
        initialStreamType: initialStreamType,
      ),
    );
  }

  @override
  ConsumerState<ConferenceInviteSheet> createState() => _ConferenceInviteSheetState();
}

class _ConferenceInviteSheetState extends ConsumerState<ConferenceInviteSheet> {
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tcgc.tcgc';
  static const String _appStoreUrl =
      'https://apps.apple.com/app/citygate-mobile/id6821748352';

  ConferenceSession _session = ConferenceSession.all;
  late ConferenceStreamType _streamType;
  late final TextEditingController _messageController;
  bool _userEdited = false;

  @override
  void initState() {
    super.initState();
    _streamType = widget.initialStreamType;
    _messageController = TextEditingController(text: _buildDefaultMessage());
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _senderName() {
    final user = ref.read(authChangeNotifierProvider).user;
    if (user != null) {
      final fullName = '${user.firstName} ${user.lastName}'.trim();
      if (fullName.isNotEmpty) return fullName;
    }
    return 'A friend';
  }

  String _buildStreamLink() {
    final base = _streamType == ConferenceStreamType.video
        ? 'https://tcgc.thecitygatechurch.org/app/video/'
        : 'https://tcgc.thecitygatechurch.org/app/audio/';
    if (_session == ConferenceSession.morning) return '$base?session=morning';
    if (_session == ConferenceSession.evening) return '$base?session=evening';
    return base;
  }

  String _buildDefaultMessage() {
    final senderName = _senderName();
    final sessionText = switch (_session) {
      ConferenceSession.morning => 'the *Morning Session*',
      ConferenceSession.evening => 'the *Evening Session*',
      ConferenceSession.all => 'the *Morning & Evening Sessions* (Monday – Sunday)',
    };
    final isVideo = _streamType == ConferenceStreamType.video;
    final actionVerb = isVideo ? 'watch' : 'listen';
    final actionTitle = isVideo ? '📺 *Watch live with me here:*' : '🎧 *Listen live with me here:*';
    final link = _buildStreamLink();

    return 'Hello!\n\n'
        '*$senderName* warmly invites you to *Image & Glory Conference 2026*.\n\n'
        '*Theme: The Rise of True Worshippers*\n\n'
        'I\'ll be joining $sessionText, and I\'d love for you to join me!\n\n'
        'Let\'s $actionVerb together live on the CityGate Mobile App and share in this wonderful experience.\n\n'
        '$actionTitle\n'
        '$link\n\n'
        '📱 *Download the CityGate Mobile App:*\n'
        '• Google Play: $_playStoreUrl\n'
        '• App Store: $_appStoreUrl\n\n'
        'Looking forward to having you join me! 🙌';
  }

  void _updateTemplateIfNotEdited() {
    if (!_userEdited) {
      _messageController.text = _buildDefaultMessage();
    }
  }

  Future<void> _shareOnWhatsApp() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final encoded = Uri.encodeComponent(text);
    final waUri = Uri.parse('https://wa.me/?text=$encoded');

    try {
      final launched = await launchUrl(
        waUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        if (mounted) Navigator.pop(context);
        return;
      }
    } catch (_) {}

    await Share.share(text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.25),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + safeBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/imgc_2026_banner.jpg',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Image & Glory Conference 2026',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Theme: The Rise of True Worshippers • The CityGate Church',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Session selector
              Text(
                'Select Session',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    isDark,
                    label: 'Mon–Sun (All)',
                    selected: _session == ConferenceSession.all,
                    onTap: () => setState(() {
                      _session = ConferenceSession.all;
                      _updateTemplateIfNotEdited();
                    }),
                  ),
                  _buildChip(
                    isDark,
                    label: 'Morning Session',
                    selected: _session == ConferenceSession.morning,
                    onTap: () => setState(() {
                      _session = ConferenceSession.morning;
                      _updateTemplateIfNotEdited();
                    }),
                  ),
                  _buildChip(
                    isDark,
                    label: 'Evening Session',
                    selected: _session == ConferenceSession.evening,
                    onTap: () => setState(() {
                      _session = ConferenceSession.evening;
                      _updateTemplateIfNotEdited();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stream type selector
              Text(
                'Stream Link Destination',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildChip(
                      isDark,
                      label: '🎧 Listen Live (Audio)',
                      selected: _streamType == ConferenceStreamType.audio,
                      onTap: () => setState(() {
                        _streamType = ConferenceStreamType.audio;
                        _updateTemplateIfNotEdited();
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChip(
                      isDark,
                      label: '📺 Watch Live (Video)',
                      selected: _streamType == ConferenceStreamType.video,
                      onTap: () => setState(() {
                        _streamType = ConferenceStreamType.video;
                        _updateTemplateIfNotEdited();
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Editable message box
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customize Your Invite Message',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  if (_userEdited)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _userEdited = false;
                          _messageController.text = _buildDefaultMessage();
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
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 6,
                minLines: 4,
                onChanged: (_) => _userEdited = true,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.primaryGold.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primaryGold),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 18),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _shareOnWhatsApp,
                        icon: const Icon(Icons.share_rounded, color: Colors.black, size: 18),
                        label: const Text(
                          'Invite on WhatsApp',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _messageController.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite message copied!')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.primaryGold.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Icon(Icons.copy_rounded, color: AppColors.primaryGold, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(
    bool isDark, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryGold
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primaryGold
                : (isDark ? Colors.white12 : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.black
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
