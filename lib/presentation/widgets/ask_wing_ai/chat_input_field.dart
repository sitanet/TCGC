import 'package:flutter/material.dart';

/// Elegant chat input field with animated send button
class ChatInputField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmit;
  final bool enabled;

  const ChatInputField({
    Key? key,
    required this.controller,
    required this.onSubmit,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  bool _hasText = false;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _onFocusChanged() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isActive = _hasText && widget.enabled;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Text field ──
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _isFocused
                        ? primaryColor.withValues(alpha: 0.6)
                        : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    width: _isFocused ? 1.5 : 1,
                  ),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.enabled
                        ? 'Ask Wing AI a question...'
                        : 'Daily limit reached',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: widget.enabled ? (text) => _handleSubmit() : null,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ── Send button ──
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 48 : 44,
                height: isActive ? 48 : 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: isActive
                      ? LinearGradient(
                          colors: [
                            primaryColor,
                            primaryColor.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isActive
                      ? null
                      : (isDark ? Colors.grey[700] : Colors.grey[300]),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isActive ? _handleSubmit : null,
                    borderRadius: BorderRadius.circular(28),
                    child: Center(
                      child: Icon(
                        Icons.send_rounded,
                        color: isActive
                            ? Colors.white
                            : (isDark ? Colors.grey[500] : Colors.grey[500]),
                        size: isActive ? 22 : 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty && widget.enabled) {
      widget.onSubmit(text);
    }
  }
}
