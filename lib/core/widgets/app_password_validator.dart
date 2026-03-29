import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPasswordValidator extends StatelessWidget {
  final String password;

  const AppPasswordValidator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final bool hasCaps = password.contains(RegExp(r'[A-Z]'));
    final bool hasLength = password.length >= 9;
    final bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child));
      },
      child: password.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey('validator_visible'),
              padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildRequirement('9+ Chars', hasLength),
                  _buildRequirement('1 Uppercase', hasCaps),
                  _buildRequirement('1 Special', hasSpecial),
                ],
              ),
            ),
    );
  }

  Widget _buildRequirement(String label, bool isMet) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: isMet ? const Color(0xFF10B981) : Colors.grey[400],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
              color: isMet ? const Color(0xFF10B981) : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

