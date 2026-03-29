import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppMessageType { error, success, info }

class AppMessageCard extends StatelessWidget {
  final String text;
  final AppMessageType type;

  const AppMessageCard({super.key, required this.text, required this.type});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case AppMessageType.error:
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        icon = Icons.error_outline;
        break;
      case AppMessageType.success:
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        icon = Icons.check_circle_outline;
        break;
      case AppMessageType.info:
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1E40AF);
        icon = Icons.info_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.splineSans(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showAppMessage(
  BuildContext context,
  String text, {
  AppMessageType type = AppMessageType.error,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: AppMessageCard(text: text, type: type),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
      duration: const Duration(seconds: 4),
    ),
  );
}
