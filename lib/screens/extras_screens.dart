import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../extras.dart';
import '../services_data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'request_screen.dart';

/// غلاف الصفحات الفرعية: الأزرار الثابتة فوق والمحتوى يمر تحت الساعة
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          top: false,
          child: FloatingBar(
            title: title,
            body: ListView(
              padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.contentTop, 14, 30),
              children: children,
            ),
          ),
        ),
      );
}

BoxDecoration _card([double r = 30]) => BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(r));

/// شارة صغيرة
Widget pillBadge(String text, {Color bg = AppColors.bg, Color fg = AppColors.ink}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: ts(12, weight: FontWeight.w600, color: fg)),
    );

String _date(DateTime d) => '${fmtNum(d.day)} ${monthNames[d.month - 1]} ${fmtNum(d.year)}';

// ───────── باقاتي

class PackagesScreen extends StatelessWidget {
  const PackagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return _Page(
      title: 'باقاتي',
      children: [
        if (s.packages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(
              children: [
                const Icon(CupertinoIcons.cube_box, size: 44, color: AppColors.faint),
                const SizedBox(height: 12),
                Text('ما عندك باقات', style: ts(20)),
              ],
            ),
          ),
        for (final p in s.packages) ...[
          _PackageCard(pkg: p),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.pkg});

  final UserPackage pkg;

  @override
  Widget build(BuildContext context) {
    final p = pkg;
    final sv = p.package.service;
    final pending = AppScope.of(context).activeSessionOf(p.id);
    return Opacity(
      opacity: p.done ? 0.7 : 1,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _card(34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ServiceImage(service: sv, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sv.name, style: ts(18, weight: FontWeight.w600)),
                      Text(p.package.name, style: ts(13, color: AppColors.faint)),
                      Text('تنتهي ${_date(p.expires)}', style: ts(13, color: AppColors.faint)),
                    ],
                  ),
                ),
                if (p.done) pillBadge('مكتملة', bg: const Color(0xFFE3F5E9), fg: AppColors.green),
              ],
            ),
            const SizedBox(height: 18),
            Semantics(
              label: '${fmtNum(p.used)} من ${fmtNum(p.package.sessions)} جلسات',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < p.package.sessions; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i < p.used ? AppColors.ink : AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: i < p.used
                              ? const Icon(Icons.check_rounded, size: 18, color: AppColors.white)
                              : Text(fmtNum(i + 1), style: ts(13, color: AppColors.faint)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('${fmtNum(p.used)} من ${fmtNum(p.package.sessions)} جلسات', style: ts(14, weight: FontWeight.w600))),
                Text(p.done ? 'خلصت' : 'باقي ${fmtNum(p.left)}', style: ts(14, color: AppColors.faint)),
              ],
            ),
            if (pending != null) ...[
              const SizedBox(height: 14),
              PillButton(
                label: 'طلب الجلسة #${pending.number}',
                icon: CupertinoIcons.clock,
                fontSize: 16,
                bg: AppColors.bg,
                onTap: () {
                  AppScope.read(context).setTab(1);
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ] else if (!p.done) ...[
              const SizedBox(height: 14),
              PillButton(
                label: 'اطلب الجلسة ${fmtNum(p.used + 1)}',
                icon: CupertinoIcons.calendar,
                fontSize: 16,
                onTap: () => openRequest(context, userPackage: p),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
