import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api_service.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';

class TestimonyPage extends ConsumerStatefulWidget {
  const TestimonyPage({super.key});

  @override
  ConsumerState<TestimonyPage> createState() => _TestimonyPageState();
}

class _TestimonyPageState extends ConsumerState<TestimonyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _category = 'general';
  String _sharePreference = 'public';
  bool _submitting = false;

  static const _categories = <({String key, String label, IconData icon})>[
    (key: 'general', label: 'Thanksgiving', icon: Icons.volunteer_activism_rounded),
    (key: 'healing', label: 'Healing & Miracle', icon: Icons.healing_rounded),
    (key: 'breakthrough', label: 'Provision', icon: Icons.trending_up_rounded),
    (key: 'salvation', label: 'Salvation', icon: Icons.auto_awesome_rounded),
    (key: 'family', label: 'Family & Marriage', icon: Icons.family_restroom_rounded),
    (key: 'career', label: 'Career & Academics', icon: Icons.workspace_premium_rounded),
    (key: 'deliverance', label: 'Deliverance', icon: Icons.shield_outlined),
    (key: 'childbirth', label: 'Child Dedication', icon: Icons.child_care_rounded),
  ];

  static const _shareOptions = <({String key, String label, IconData icon})>[
    (
      key: 'public',
      label: 'Share with My Name (Public)',
      icon: Icons.public_rounded,
    ),
    (
      key: 'anonymous',
      label: 'Share Anonymously (Hide My Name)',
      icon: Icons.visibility_off_outlined,
    ),
    (
      key: 'private',
      label: 'Private (Pastoral Team Only)',
      icon: Icons.lock_outline_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authChangeNotifierProvider).user;
      if (user != null) {
        if (_nameController.text.isEmpty) {
          _nameController.text = user.fullName;
        }
        if (_emailController.text.isEmpty) {
          _emailController.text = user.email;
        }
        if (_phoneController.text.isEmpty && user.phoneNumber != null) {
          _phoneController.text = user.phoneNumber!;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    try {
      final res = await ApiService().post(ApiConstants.submitTestimony, {
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'category': _category,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'share_preference': _sharePreference,
      });

      if (!mounted) return;
      setState(() => _submitting = false);

      if (res.isSuccess) {
        final msg = res.data['message']?.toString() ??
            'Glory to God! Your testimony has been received.';
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.celebration_rounded, color: AppColors.primaryGold),
                SizedBox(width: 10),
                Text('Testimony Received'),
              ],
            ),
            content: Text(msg),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Amen',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      } else {
        final err = res.errorMessage ?? 'Could not submit testimony.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit testimony: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Share Testimony',
        showBackButton: true,
        lightBackground: !isDark,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 16, 18, 32 + bottomPad),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header banner
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF2B2212), Color(0xFF19140E), Color(0xFF131118)]
                        : const [Color(0xFFFFFDF8), Color(0xFFFAF0DA), Color(0xFFF3E4C2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: isDark ? 0.45 : 0.65),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: isDark ? 0.14 : 0.16),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryGold.withValues(
                              alpha: isDark ? 0.10 : 0.16,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFFE082),
                                    AppColors.primaryGold,
                                    Color(0xFFC89B2B),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryGold.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.celebration_rounded,
                                color: Colors.black,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGold.withValues(
                                        alpha: isDark ? 0.18 : 0.22,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'SHARE YOUR STORY',
                                      style: TextStyle(
                                        color: AppColors.primaryGold,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tell What God Has Done',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Your testimony encourages faith across the church.',
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
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Section 1: Category & Story
              _sectionCard(
                isDark: isDark,
                title: 'Your Testimony',
                icon: Icons.auto_stories_rounded,
                children: [
                  _label(isDark, 'Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((c) {
                      final selected = _category == c.key;
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _category = c.key);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryGold
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primaryGold
                                  : (isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                c.icon,
                                size: 15,
                                color: selected
                                    ? Colors.black
                                    : (isDark
                                        ? AppColors.primaryGold
                                        : Colors.black54),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                c.label,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? Colors.black
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  _label(isDark, 'Testimony Headline *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      isDark,
                      'e.g. Miraculous Healing & Provision',
                      icon: Icons.title_rounded,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a headline'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  _label(isDark, 'Details *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _contentController,
                    maxLines: 7,
                    minLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      isDark,
                      'Share the details of what God did...',
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return 'Please write your testimony';
                      if (text.length < 15) {
                        return 'Please write at least 15 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 2: Contact Details
              _sectionCard(
                isDark: isDark,
                title: 'Your Contact Info',
                icon: Icons.person_outline_rounded,
                children: [
                  _label(isDark, 'Full Name *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      isDark,
                      'Your full name',
                      icon: Icons.badge_outlined,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Your full name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  _label(isDark, 'Phone / WhatsApp (Optional)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      isDark,
                      'e.g. 08012345678',
                      icon: Icons.phone_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _label(isDark, 'Email (Optional)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(
                      isDark,
                      'you@example.com',
                      icon: Icons.email_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 3: Share preference
              _sectionCard(
                isDark: isDark,
                title: 'Sharing Preference',
                icon: Icons.visibility_outlined,
                children: [
                  ..._shareOptions.map((opt) {
                    final selected = _sharePreference == opt.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _sharePreference = opt.key);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryGold
                                    .withValues(alpha: isDark ? 0.16 : 0.12)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primaryGold
                                  : (isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300),
                              width: selected ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primaryGold.withValues(alpha: 0.2)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  opt.icon,
                                  size: 17,
                                  color: selected
                                      ? AppColors.primaryGold
                                      : (isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 20,
                                color: selected
                                    ? AppColors.primaryGold
                                    : (isDark
                                        ? Colors.white24
                                        : Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 22),

              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
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
                    _submitting ? 'Submitting...' : 'Submit Testimony',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    elevation: 4,
                    shadowColor: AppColors.primaryGold.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
              Icon(icon, size: 18, color: AppColors.primaryGold),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _label(bool isDark, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13.5,
        color:
            isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
      prefixIcon: icon != null
          ? Icon(icon, size: 19, color: AppColors.primaryGold)
          : null,
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
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
        borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}
