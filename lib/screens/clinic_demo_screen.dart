import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../extras.dart';
import '../native.dart';
import '../services_data.dart';
import '../state.dart';
import '../states.dart';
import '../theme.dart';
import '../widgets.dart';
import 'appointments_tab.dart';
import 'visit_extras.dart';

/// لوحة العيادة (تجريبية): تمثل لوحة التحكم اللي تستقبل الطلبات وتحدد المواعيد،
/// عشان نجرب كل الحالات من الجوال لين تتربط لوحة التحكم الحقيقية
class ClinicDemoScreen extends StatelessWidget {
  const ClinicDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = s.sorted;
    final groups = [
      ('طلبات جديدة', all.where((b) => b.status == RequestStatus.sent || b.status == RequestStatus.approved).toList()),
      ('مواعيد محددة', all.where((b) => b.status == RequestStatus.scheduled).toList()),
      ('السابقة', all.where((b) => b.past).toList()),
    ];
    return Scaffold(
      body: SafeArea(
        top: false,
        child: FloatingBar(
          title: 'لوحة العيادة',
          body: ListView(
            padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.belowBar, 14, 30),
            children: [
              for (final (title, list) in groups)
                if (list.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 22, 10, 8),
                    child: Semantics(header: true, child: Text('$title · ${fmtNum(list.length)}', style: ts(20, weight: FontWeight.w500))),
                  ),
                  for (final b in list) ...[
                    _RequestRow(booking: b, patient: b.recipientName ?? (s.name.trim().isNotEmpty ? s.name.trim() : 'المريض')),
                    const SizedBox(height: 8),
                  ],
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.booking, required this.patient});

  final Booking booking;
  final String patient;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final (label, bg, fg) = requestBadge(b);
    final at = b.at;
    final actions = _actions(context, b);
    return Pressable(
      onTap: actions.isEmpty ? null : () => showAppSheet(context, title: '${b.title} · #${b.number}', children: actions),
      semanticLabel: '${b.title}، $patient، $label',
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 16, 12),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(28)),
        child: Row(
          children: [
            RequestAvatar(booking: b, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.title, style: ts(16, weight: FontWeight.w600)),
                  Text('$patient · ${b.branch.name}', style: ts(13, color: AppColors.body)),
                  Text(
                    at != null && b.status != RequestStatus.sent && !b.isPackage
                        ? '${fmtWhen(at)}${withDoctor(b)}'
                        : '${b.period.label} · ${b.doctor?.name ?? 'الطبيب المتاح'}',
                    style: ts(13, color: AppColors.faint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: ts(12, weight: FontWeight.w600, color: fg)),
            ),
          ],
        ),
      ),
    );
  }

  /// أول يوم دوام بعد اليوم، بساعة من الفترة اللي طلبها المريض
  static DateTime _slot(Period p) {
    final d = DayInfo(firstOpenDay(fromToday: false)).date;
    return DateTime(d.year, d.month, d.day, p.hour, p == Period.evening ? 30 : 0);
  }

  /// بعد ساعة من الحين (لتجربة الإلغاء المتأخر)
  static DateTime _soon() {
    final t = DateTime.now().add(const Duration(hours: 1));
    return DateTime(t.year, t.month, t.day, t.hour, t.minute - t.minute % 5);
  }

  List<Widget> _actions(BuildContext context, Booking b) {
    final s = AppScope.read(context);

    Widget action(String label, VoidCallback run, {bool danger = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PillButton(
            label: label,
            height: 50,
            fontSize: 16,
            bg: danger ? AppColors.red : AppColors.bg,
            fg: danger ? AppColors.onRed : AppColors.ink,
            onTap: () {
              Navigator.of(context).pop();
              HapticFeedback.mediumImpact();
              run();
            },
          ),
        );

    void schedule(DateTime at) {
      final docs = doctorsFor(b.service, b.branchId);
      final doctorId = b.doctorId ?? (docs.isNotEmpty ? docs.first.id : doctors.first.id);
      s.clinicSchedule(b.id, at: at, doctorId: doctorId);
      // تجربة: تنبيه "تم تحديد موعدك" (بعد الربط يرسله السيرفر)
      Reminders.notifyLater('scheduled:${b.id}', 'تم تحديد موعدك', '${b.title} · ${fmtWhen(at)}', const Duration(seconds: 5));
    }

    final cancel = action('إلغاء من العيادة', () => s.cancelByClinic(b.id, 'اعتذر الطبيب لظرف طارئ ونعتذر لك'), danger: true);

    return switch (b.status) {
      RequestStatus.sent when b.isPackage => [action('موافقة على الباقة', () => s.clinicApprove(b.id)), cancel],
      RequestStatus.sent => [
          action('تحديد موعد ${fmtWhen(_slot(b.period))}', () => schedule(_slot(b.period))),
          action('تحديد موعد بعد ساعة', () => schedule(_soon())),
          cancel,
        ],
      RequestStatus.approved => [cancel],
      RequestStatus.scheduled => [
          if (!b.free && !b.paid) action('تأكيد الدفع في الفرع', () => s.clinicConfirmPayment(b.id)),
          action('مكتملة', () => s.clinicComplete(b.id)),
          action('لم يحضر', () => s.clinicNoShow(b.id)),
          cancel,
        ],
      _ => const <Widget>[],
    };
  }
}
