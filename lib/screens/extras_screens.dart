import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../extras.dart';
import '../main.dart';
import '../services_data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'service_booking_screen.dart';
import 'visit_extras.dart';

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

Widget _section(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
      child: Semantics(header: true, child: Text(text, style: ts(20, weight: FontWeight.w500))),
    );

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
                      Text('${p.package.name} · تنتهي ${_date(p.expires)}', style: ts(13, color: AppColors.faint)),
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
            if (!p.done) ...[
              const SizedBox(height: 14),
              PillButton(
                label: 'احجز الجلسة ${fmtNum(p.used + 1)}',
                icon: CupertinoIcons.calendar,
                fontSize: 16,
                onTap: () => openServiceBooking(context, [OrderItem(sv, 1)], packageId: p.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────── الملف الطبي

class MedicalScreen extends StatefulWidget {
  const MedicalScreen({super.key});

  @override
  State<MedicalScreen> createState() => _MedicalScreenState();
}

class _MedicalScreenState extends State<MedicalScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    Widget info(IconData icon, String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 15, color: AppColors.faint),
                    const SizedBox(width: 6),
                    Text(label, style: ts(12, color: AppColors.faint)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(value, textDirection: TextDirection.ltr, style: ts(17, weight: FontWeight.w600)),
              ],
            ),
          ),
        );

    final visits = switch (_tab) {
      1 => medicalVisits.where((v) => v.prescriptions.isNotEmpty).toList(),
      2 => medicalVisits.where((v) => v.files.isNotEmpty).toList(),
      _ => medicalVisits,
    };

    return _Page(
      title: 'ملفي الطبي',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _card(),
          child: Row(
            children: [
              info(CupertinoIcons.drop, 'فصيلة الدم', bloodType),
              const SizedBox(width: 8),
              info(CupertinoIcons.exclamationmark_circle, 'الحساسية', allergies),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            for (final (i, label) in const [(0, 'الزيارات'), (1, 'الوصفات'), (2, 'التقارير')])
              FilterPill(label: label, selected: _tab == i, onTap: () => setState(() => _tab = i)),
          ],
        ),
        const SizedBox(height: 4),
        for (final v in visits) ...[
          const SizedBox(height: 10),
          Pressable(
            onTap: () => Navigator.of(context).push(iosRoute(VisitScreen(visit: v))),
            semanticLabel: '${v.title}، ${v.doctor.name}، ${v.dateText}',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: _card(),
              child: Row(
                children: [
                  DoctorAvatar(doctor: v.doctor, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.title, style: ts(16, weight: FontWeight.w600)),
                        Text('${v.doctor.name} · ${v.dateText}', style: ts(13, color: AppColors.faint)),
                        if (v.prescriptions.isNotEmpty || v.files.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (v.prescriptions.isNotEmpty) pillBadge('وصفة'),
                              for (final f in v.files) pillBadge(f.name),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.back, size: 18, color: AppColors.faint),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class VisitScreen extends StatelessWidget {
  const VisitScreen({super.key, required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final v = visit;
    return _Page(
      title: v.title,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _card(),
          child: Row(
            children: [
              DoctorAvatar(doctor: v.doctor, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.doctor.name, style: ts(17, weight: FontWeight.w600)),
                    Text('${v.dateText} · ${branchById(v.branchId).name}', style: ts(13, color: AppColors.faint)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _section('ملخص الطبيب'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _card(),
          child: Text(v.summary, style: ts(15, color: AppColors.body, height: 1.75)),
        ),
        if (v.prescriptions.isNotEmpty) ...[
          _section('الوصفة'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: _card(),
            child: Column(
              children: [
                for (final rx in v.prescriptions)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: rx == v.prescriptions.last ? null : const Border(bottom: BorderSide(color: AppColors.bg)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
                          child: const Icon(Icons.medication_rounded, size: 20, color: AppColors.ink),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rx.name, style: ts(16, weight: FontWeight.w500)),
                              Text(rx.dose, style: ts(13, color: AppColors.faint)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (v.files.isNotEmpty) ...[
          _section('الملفات'),
          for (final f in v.files)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: _card(26),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
                    child: const Icon(CupertinoIcons.doc_text, size: 20, color: AppColors.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name, style: ts(16, weight: FontWeight.w500)),
                        Text(f.size, textDirection: TextDirection.ltr, style: ts(13, color: AppColors.faint)),
                      ],
                    ),
                  ),
                  CircleButton(
                    icon: CupertinoIcons.arrow_down_to_line,
                    size: 40,
                    iconSize: 18,
                    bg: AppColors.bg,
                    semanticLabel: 'تحميل ${f.name}',
                    onTap: () => showInfoAlert(context, f.name, 'الملفات تتوفر بعد ربط نظام العيادة'),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ───────── التأمين

class InsuranceScreen extends StatelessWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ins = s.insurance;
    return _Page(
      title: 'التأمين',
      children: [
        if (ins == null)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(
              children: [
                const Icon(CupertinoIcons.checkmark_shield, size: 44, color: AppColors.faint),
                const SizedBox(height: 12),
                Text('ما أضفت بطاقة تأمين', style: ts(20)),
              ],
            ),
          )
        else ...[
          Semantics(
            label: '${ins.company}، رقم العضوية ${ins.member}، الفئة ${ins.tier}، تنتهي ${ins.expiry}',
            child: ExcludeSemantics(child: _InsuranceCardView(card: ins)),
          ),
          _section('التغطية'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: _card(),
            child: Column(
              children: [
                for (final c in coverageList)
                  Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    decoration: BoxDecoration(
                      border: c == coverageList.last ? null : const Border(bottom: BorderSide(color: AppColors.bg)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: c.covered ? const Color(0xFFE3F5E9) : const Color(0xFFFBE3E1), shape: BoxShape.circle),
                          child: Icon(c.covered ? Icons.check_rounded : Icons.close_rounded, size: 17, color: c.covered ? AppColors.green : AppColors.red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(c.label, style: ts(16))),
                        Text(c.note, style: ts(13, color: c.covered ? AppColors.faint : AppColors.red)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        PillButton(
          label: ins == null ? 'إضافة بطاقة التأمين' : 'تحديث البطاقة',
          bg: ins == null ? AppColors.accent : AppColors.white,
          fontSize: 16,
          onTap: () => showInfoAlert(context, 'بطاقة التأمين', 'إضافة البطاقة وتحديثها تتوفر بعد ربط نظام العيادة'),
        ),
      ],
    );
  }
}

class _InsuranceCardView extends StatelessWidget {
  const _InsuranceCardView({required this.card});

  final InsuranceCard card;

  @override
  Widget build(BuildContext context) {
    Widget field(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ts(12, color: const Color(0xB3FFFFFF))),
            Text(value, textDirection: TextDirection.ltr, style: ts(16, weight: FontWeight.w600, color: AppColors.white)),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0E3A5B), Color(0xFF1F6E8C)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.checkmark_shield, size: 24, color: AppColors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(card.company, style: ts(17, weight: FontWeight.w600, color: AppColors.white))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(999)),
                child: Text('سارية', style: ts(13, weight: FontWeight.w600, color: AppColors.white)),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text('رقم العضوية', style: ts(12, color: const Color(0xB3FFFFFF))),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(card.member, textDirection: TextDirection.ltr, style: ts(22, weight: FontWeight.w600, color: AppColors.white).copyWith(letterSpacing: 1)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              field('الفئة', card.tier),
              const SizedBox(width: 30),
              field('تنتهي', card.expiry),
              const SizedBox(width: 30),
              field('نسبة التحمل', '${fmtNum(card.copay)}%'),
            ],
          ),
        ],
      ),
    );
  }
}
