import 'package:flutter/material.dart';

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final String? errorText;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;

  const InputField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.errorText,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isError = errorText != null;
    final color = isError ? Colors.red : (focusNode?.hasFocus ?? false ? Colors.blue : Colors.grey[800]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(color: color),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: color),
          errorText: errorText,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[500]!),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }
}
