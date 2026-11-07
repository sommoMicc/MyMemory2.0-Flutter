import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import '../l10n/app_strings.dart';
import '../palette.dart';

/// Direct store links for the web home. Link preserves browser link semantics.
class StoreLinks extends StatelessWidget {
  const StoreLinks({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ink, width: 2),
          boxShadow: const [BoxShadow(color: ink, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, 'Porta SommoMemory con te'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                _StoreLink(
                  label: 'Google Play',
                  icon: Icons.android_rounded,
                  url:
                      'https://play.google.com/store/apps/details?id=cc.sommomi.mymemory',
                ),
                _StoreLink(
                  label: 'App Store',
                  icon: Icons.apple_rounded,
                  url: 'https://apps.apple.com/it/app/sommomemory/id6831015201',
                ),
              ],
            ),
          ],
        ),
      );
}

class _StoreLink extends StatelessWidget {
  const _StoreLink({
    required this.label,
    required this.icon,
    required this.url,
  });

  final String label;
  final IconData icon;
  final String url;

  @override
  Widget build(BuildContext context) => Link(
        uri: Uri.parse(url),
        target: LinkTarget.blank,
        builder: (context, followLink) => OutlinedButton.icon(
          onPressed: followLink,
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            minimumSize: const Size(148, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            side: const BorderSide(color: ink, width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          icon: Icon(icon, size: 21),
          label: Text(label),
        ),
      );
}
