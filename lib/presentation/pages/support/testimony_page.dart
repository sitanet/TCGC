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

  static const _categories = <({String key, String label})>[
    (key: 'general', label: 'Thanksgiving & Other Praises'),
    (key: 'healing', label: 'Healing & Miracle'),
    (key: 'breakthrough', label: 'Financial Breakthrough / Provision'),
    (key: 'salvation', label: 'Salvation & Spiritual Growth'),
    (key: 'family', label: 'Family & Marriage Restoration'),
    (key: 'career', label: 'Academic, Job & Career Promotion'),
    (key: 'deliverance', label: 'Deliverance & Protection'),
    (key: 'childbirth', label: 'Fruit of the Womb & Child Dedication'),
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
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPad),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF231D12), Color(0xFF15120D)]
                        : const [Color(0xFFFFFDF7), Color(0xFFF6EDD9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        color: AppColors.primaryGold,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tell What God Has Done',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Your testimony encourages faith across the church.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Category
              _label(isDark, 'Category'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: _inputDecoration(isDark, 'Select category'),
                dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                items: _categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.key,
                        child: Text(
                          c.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 14),

              // Headline
              _label(isDark, 'Testimony Headline *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration(
                  isDark,
                  'e.g. Miraculous Healing & Provision',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a headline'
                    : null,
              ),
              const SizedBox(height: 14),

              // Story
              _label(isDark, 'Your Testimony *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _contentController,
                maxLines: 6,
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
              const SizedBox(height: 14),

              // Full Name
              _label(isDark, 'Full Name *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(isDark, 'Your full name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Your full name is required'
                    : null,
              ),
              const SizedBox(height: 14),

              // Phone + Email
              _label(isDark, 'Phone / WhatsApp (Optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(isDark, 'e.g. 08012345678'),
              ),
              const SizedBox(height: 14),

              _label(isDark, 'Email (Optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(isDark, 'you@example.com'),
              ),
              const SizedBox(height: 16),

              // Share preference
              _label(isDark, 'Sharing Preference'),
              const SizedBox(height: 8),
              ..._shareOptions.map((opt) {
                final selected = _sharePreference == opt.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _sharePreference = opt.key),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            opt.icon,
                            size: 18,
                            color: selected
                                ? AppColors.primaryGold
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                          const SizedBox(width: 10),
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
                            size: 19,
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
              const SizedBox(height: 16),

              SizedBox(
                height: 52,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
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

  InputDecoration _inputDecoration(bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13.5,
        color:
            isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}
