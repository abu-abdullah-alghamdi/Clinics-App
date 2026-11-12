import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services_data.dart';
import '../theme.dart';
import '../widgets.dart';

/// فروعنا: كل فرع في بطاقة مع الاتصال والاتجاهات
class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ما قدرنا نفتح الرابط على هذا الجهاز', style: ts(14, color: AppColors.white))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          top: false,
          child: FloatingBar(title: 'فروعنا', body: ListView(
            padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.belowBar, 14, 30),
            children: [
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(40)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final b in branches) ...[
                      BranchBox(branch: b, onOpen: (uri) => _open(context, uri)),
                      if (b != branches.last) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          )),
        ),
      );
}

/// بطاقة فرع: الاسم، الدوام، مفتوح أو مغلق، وزري الاتصال والاتجاهات
class BranchBox extends StatelessWidget {
  const BranchBox({super.key, required this.branch, required this.onOpen});

  final Branch branch;
  final void Function(Uri uri) onOpen;

  @override
  Widget build(BuildContext context) {
    final b = branch;
    final open = b.openAt(DateTime.now());
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(28),
        border: highContrast(context) ? Border.all(color: AppColors.ink, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(b.name, style: ts(19, weight: FontWeight.w600))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: open ? AppColors.green.withAlpha(26) : AppColors.closed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        open ? 'مفتوح الآن' : 'مغلق الآن',
                        style: ts(13, weight: FontWeight.w600, color: open ? AppColors.green : AppColors.closedText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(Branch.hoursText, style: ts(14, color: AppColors.body)),
                const SizedBox(height: 2),
                Text(b.area, style: ts(13, color: AppColors.faint)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'اتصال',
                  icon: CupertinoIcons.phone_fill,
                  height: 50,
                  fontSize: 15,
                  padding: 12,
                  bg: AppColors.white,
                  onTap: () => onOpen(Uri.parse('tel:${b.phone}')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PillButton(
                  label: 'الاتجاهات',
                  icon: CupertinoIcons.location_fill,
                  height: 50,
                  fontSize: 15,
                  padding: 12,
                  bg: AppColors.ink,
                  fg: AppColors.white,
                  onTap: () => onOpen(b.mapsUri),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

