import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../app/themes/admin_theme.dart';

class AdminBreadcrumbItem {
  final String label;
  final String? route;

  AdminBreadcrumbItem({required this.label, this.route});
}

class AdminBreadcrumbs extends StatelessWidget {
  final List<AdminBreadcrumbItem> items;

  const AdminBreadcrumbs({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _buildItem(context, items[i], i == items.length - 1),
          if (i < items.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '/',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildItem(
    BuildContext context,
    AdminBreadcrumbItem item,
    bool isLast,
  ) {
    final color = isLast ? AdminTheme.textPrimary : AdminTheme.textSecondary;
    final fontWeight = isLast ? FontWeight.w600 : FontWeight.normal;

    return InkWell(
      onTap: (isLast || item.route == null)
          ? null
          : () => context.go(item.route!),
      child: Text(
        item.label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
