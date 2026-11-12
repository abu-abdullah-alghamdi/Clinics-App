import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../extras.dart';
import '../main.dart';
import '../services_data.dart';
import '../state.dart';
import '../theme.dart';
import '../states.dart';
import '../widgets.dart';
import 'booking_screen.dart';
import 'done_screen.dart';
import 'login_gate.dart';
import 'payment_screen.dart';

/// تأكيد الحجز: ملخص الموعد وزر واحد (بدون أي خانات؛ بيانات المستخدم من ملفه)
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({
    super.key,
    required this.doctor,
    required this.cat,
    required this.day,
    required this.time,
    required this.branchId,
    this.items = const [],
    this.fromCart = false,
    this.packageId,
  });

  /// جلسة من باقة مدفوعة: ينحجز بدون دفع
  final String? packageId;

  final Doctor doctor;
  final String cat;
  final int day;
  final int time;
  final String branchId;

  /// الخدمات المدفوعة (فاضية = زيارة عادية والدفع في العيادة)
  final List<OrderItem> items;
  final bool fromCart;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  /// الوقت ممكن يتغير لو انحجز قبل ما يأكد
  late int time = widget.time;

  /// الكشف بالتأمين (لو عنده بطاقة)
  bool _useInsurance = true;

  Doctor get doctor => widget.doctor;
  String get cat => widget.cat;
  int get day => widget.day;
  String get branchId => widget.branchId;
  List<OrderItem> get items => widget.items;
  bool get fromCart => widget.fromCart;

  Future<void> _confirm() async {
    // قاعدة وحدة: الحجز يحتاج جوال موثّق
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    final s = AppScope.read(context);

    // الوقت انحجز قبل ما يأكد (يصير فعلياً بعد ربط السيرفر)
    if (slotTaken(doctor.id, day, slotTimes.indexOf(time))) {
      final picked = await showSlotTakenSheet(context, doctorId: doctor.id, day: day, time: time);
      if (picked == null || !mounted) return;
      setState(() => time = picked);
    }
    if (!mounted) return;

    // حجز مكرر مع نفس الطبيب في نفس اليوم
    final existing = s.sameDayBooking(doctor.id, day);
    if (existing != null) {
      final choice = await showDuplicateSheet(context, existing: existing, newTime: time);
      if (choice == null || !mounted) return;
      if (choice == DuplicateChoice.editExisting) {
        final nav = Navigator.of(context);
        nav.popUntil((r) => r.isFirst);
        nav.push(iosModal(BookingScreen(doctor: existing.doctor, cat: existing.cat, editing: existing)));
        return;
      }
    }
    if (!mounted) return;

    final nav = Navigator.of(context);
    final pkg = widget.packageId;
    if (pkg != null) {
      final b = s.addBooking(
        doctorId: doctor.id,
        cat: cat,
        day: day,
        time: time,
        branchId: branchId,
        serviceIds: [for (final i in items) i.service.id],
      );
      s.usePackageSession(pkg);
      nav.pushAndRemoveUntil(iosRoute(DoneScreen(booking: b)), (r) => r.isFirst);
      return;
    }
    if (items.isNotEmpty) {
      nav.push(iosRoute(PaymentScreen(
        branchId: branchId,
        items: items,
        fromCart: fromCart,
        appointment: Appointment(doctorId: doctor.id, cat: cat, day: day, time: time),
      )));
      return;
    }
    final b = s.addBooking(doctorId: doctor.id, cat: cat, day: day, time: time, branchId: branchId);
    nav.pushReplacement(iosRoute(DoneScreen(booking: b)));
  }

  /// الجلسة من الباقة: رقمها وما فيه دفع
  Widget _packageNote(AppState s) {
    final p = s.packages.firstWhere((x) => x.id == widget.packageId);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(32)),
      child: Row(
        children: [
          const Icon(CupertinoIcons.cube_box, size: 22, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(child: Text('من باقتك · الجلسة ${fmtNum(p.used + 1)} من ${fmtNum(p.package.sessions)}', style: ts(16, weight: FontWeight.w600))),
          Text('مدفوعة', style: ts(14, color: AppColors.green, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// الدفع بالتأمين أو بدونه، وكم يغطي وكم يدفع في العيادة
  List<Widget> _insuranceChoice(InsuranceCard ins, Doctor d) {
    final price = priceValue(d);
    final covered = (price * (100 - ins.copay) / 100).round();
    Widget option(String label, String? sub, bool selected, VoidCallback onTap) => Pressable(
          onTap: onTap,
          selected: selected,
          semanticLabel: sub == null ? label : '$label، $sub',
          child: AnimatedContainer(
            duration: motion(context, 200),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 18, 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: selected ? AppColors.ink : Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                SelectDot(selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: ts(17, weight: FontWeight.w600)),
                      if (sub != null) Text(sub, style: ts(13, color: AppColors.faint)),
                    ],
                  ),
                ),
                if (sub != null) const Icon(CupertinoIcons.checkmark_shield, size: 22, color: AppColors.green),
              ],
            ),
          ),
        );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
        child: Text('طريقة الدفع', style: ts(20, weight: FontWeight.w500)),
      ),
      option('التأمين', '${ins.company} · ${ins.tier}', _useInsurance, () => setState(() => _useInsurance = true)),
      const SizedBox(height: 8),
      option('الدفع بدون تأمين', null, !_useInsurance, () => setState(() => _useInsurance = false)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(32)),
        child: Column(
          children: _useInsurance
              ? [
                  amountRow('سعر الكشف', money(price)),
                  amountRow('يغطيه التأمين (${fmtNum(100 - ins.copay)}%)', '- ${money(covered)}', color: AppColors.green),
                  const Divider(color: AppColors.bg, height: 18, thickness: 1.5),
                  amountRow('تدفع في العيادة', money(price - covered), bold: true),
                ]
              : [amountRow('تدفع في العيادة', money(price), bold: true)],
        ),
      ),
      if (_useInsurance)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Text('المبلغ النهائي بعد موافقة شركة التأمين', style: ts(13, color: AppColors.faint)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = doctor;
    final branch = branchById(branchId);
    final subtotal = items.fold(0, (a, b) => a + b.total);
    final title = items.isEmpty ? (categories[cat] ?? '') : items.map((i) => i.service.name).join('، ');

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: FloatingBar(title: 'تأكيد الحجز', body: ListView(
                padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.contentTop, 14, 20),
                children: [
                  CutCard(
                    image: d.image,
                    imageWidth: 150,
                    imageHeight: 200,
                    textWidth: 200,
                    padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
                    shadow: false,
                    children: [
                      Text('${d.n1}\n${d.n2}', style: ts(26, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(title, style: ts(14, color: AppColors.body)),
                      const SizedBox(height: 12),
                      Text(DayInfo(day).full, style: ts(24, color: AppColors.blue)),
                      Text(fmtRange(time, d.duration), style: ts(15)),
                      const SizedBox(height: 6),
                      Text(branch.name, style: ts(15, weight: FontWeight.w600)),
                      Text(branch.area, style: ts(13, color: AppColors.faint)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.packageId != null)
                    _packageNote(s)
                  else if (items.isNotEmpty)
                    AmountSummary(subtotal: subtotal)
                  else if (s.insurance != null)
                    ..._insuranceChoice(s.insurance!, d)
                  else
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(32)),
                      child: Column(
                        children: [
                          amountRow('سعر الكشف', d.price, bold: true),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text('الدفع في العيادة', style: ts(13, color: AppColors.faint)),
                          ),
                        ],
                      ),
                    ),
                ],
              )),
            ),
            BottomAction(
              child: PillButton(
                label: items.isNotEmpty && widget.packageId == null ? 'متابعة للدفع' : 'تأكيد الحجز',
                height: 50,
                onTap: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
