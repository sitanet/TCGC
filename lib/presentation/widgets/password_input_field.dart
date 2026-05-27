import 'package:flutter/material.dart';

/// A reusable password/PIN input field with visibility toggle (eye icon)
class PasswordInputField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final int? maxLength;
  final TextInputType keyboardType;
  final bool isNumeric;
  final TextAlign textAlign;
  final TextStyle? style;
  final InputDecoration? decoration;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final int? minLines;
  final int? maxLines;

  const PasswordInputField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.maxLength,
    this.keyboardType = TextInputType.text,
    this.isNumeric = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.decoration,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.minLines,
    this.maxLines,
  }) : super(key: key);

  @override
  State<PasswordInputField> createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<PasswordInputField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = true;
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      maxLength: widget.maxLength,
      obscureText: _obscureText,
      autofocus: widget.autofocus,
      textAlign: widget.textAlign,
      enabled: widget.enabled,
      minLines: widget.minLines,
      maxLines: widget.maxLines ?? 1,
      style: widget.style,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: (widget.decoration ?? InputDecoration()).copyWith(
        labelText: widget.labelText,
        hintText: widget.hintText,
        counterText: widget.maxLength != null ? '' : null,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: Icon(
              _obscureText ? Icons.visibility_off : Icons.visibility,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            onPressed: widget.enabled ? _togglePasswordVisibility : null,
            tooltip: _obscureText ? 'Show password' : 'Hide password',
          ),
        ),
      ),
    );
  }
}
