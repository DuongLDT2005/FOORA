import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fallback when OpenStreetMap has no result or location is unavailable.
class OpenGoogleMapsButton extends StatelessWidget {
  const OpenGoogleMapsButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=siêu+thị'),
      mode: LaunchMode.externalApplication,
    ),
    icon: Icon(LucideIcons.externalLink, size: 15.r),
    label: const Text('Tìm trên Google Maps'),
  );
}
