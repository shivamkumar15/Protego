import 'package:flutter/material.dart';

Widget buildTextField({
  required BuildContext context,
  required String label,
  required String hint,
  required TextEditingController controller,
  bool obscure = false,
  bool readOnly = false,
  TextInputType keyboardType = TextInputType.text,
  Widget? suffixIcon,
  Widget? prefixIcon,
  ValueChanged<String>? onChanged,
  String? Function(String?)? validator,
}) {
  return _AnimatedAuthTextField(
    label: label,
    hint: hint,
    controller: controller,
    obscure: obscure,
    readOnly: readOnly,
    keyboardType: keyboardType,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    onChanged: onChanged,
    validator: validator,
  );
}

class _AnimatedAuthTextField extends StatefulWidget {
  const _AnimatedAuthTextField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscure,
    required this.readOnly,
    required this.keyboardType,
    required this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    required this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final bool readOnly;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  State<_AnimatedAuthTextField> createState() => _AnimatedAuthTextFieldState();
}

class _AnimatedAuthTextFieldState extends State<_AnimatedAuthTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRaised = _isFocused || _hasText;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        TextFormField(
          focusNode: _focusNode,
          controller: widget.controller,
          obscureText: widget.obscure,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          validator: widget.validator,
          style: TextStyle(
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: isRaised ? widget.hint : '',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: widget.prefixIcon,
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor:
                isDark ? const Color(0xFF101010) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFE2E8F0),
                )),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFE2E8F0),
                )),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5)),
          ),
        ),
        Positioned(
          left: widget.prefixIcon == null ? 12 : 76,
          top: isRaised ? 3 : 17,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isRaised
                    ? (isDark
                        ? const Color(0xFF101010)
                        : const Color(0xFFF8FAFC))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: isRaised ? 11 : 14,
                  fontWeight: FontWeight.w600,
                  color: _isFocused
                      ? theme.colorScheme.primary
                      : isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF6B7280),
                ),
                child: Text(widget.label),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget buildButton({
  required BuildContext context,
  required String label,
  required bool isLoading,
  required VoidCallback? onPressed,
  bool isOutlined = false,
  Widget? icon,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  if (isOutlined) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon ?? const SizedBox.shrink(),
        label: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF111827)))
            : Text(label,
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  return SizedBox(
    height: 52,
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );
}
