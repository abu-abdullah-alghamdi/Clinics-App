import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../native.dart';
import '../state.dart';
import '../states.dart';
import '../theme.dart';
import '../widgets.dart';
import 'otp_screen.dart';

/// معاينة الحالات اللي ما تطلع عادة (للتجربة، تتقفل قبل النشر من showStatesPreview)
class StatesPreviewScreen extends StatelessWidget {
  const StatesPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final nav = Navigator.of(context);
    void open(Widget page) => nav.push(iosRoute(page));

    /// يرجع للتبويب المطلوب عشان يشوف الحالة في مكانها
    void goTab(int tab) {
      s.setTab(tab);
      nav.popUntil((r) => r.isFirst);
    }

    final tomorrow = DayInfo(firstOpenDay(fromToday: false)).date;
    final sample = s.upcoming.isNotEmpty
        ? s.upcoming.first
        : Booking(
            id: 'demo',
            number: '2400',
            serviceId: 's5',
            branchId: 'rawdah',
            doctorId: 'd2',
            status: RequestStatus.scheduled,
            at: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17, 30),
          );

    return Scaffold(
      body: SafeArea(
        top: false,
        child: FloatingBar(title: 'معاينة الحالات', body: ListView(
          padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.belowBar, 14, 30),
          children: [
            _Group(title: 'صفحات كاملة', rows: [
              _Row('تحميل البيانات', onTap: () => open(const _LoadingDemo())),
              _Row('انقطاع الإنترنت', onTap: () => open(Builder(
                    builder: (ctx) => StatusPage(
                      card: OfflineCard(onRetry: () => Navigator.of(ctx).pop()),
                      footer: const OfflineHint(),
                    ),
                  ))),
              _Row('خطأ من السيرفر', onTap: () => open(Builder(
                    builder: (ctx) => StatusPage(card: ServerErrorCard(onRetry: () => Navigator.of(ctx).pop())),
                  ))),
              _Row('تحديث إجباري', onTap: () => open(const ForceUpdatePage(closable: true))),
              _Row('صيانة', onTap: () {
                final t = DateTime.now().add(const Duration(hours: 1));
                open(MaintenancePage(backAt: DateTime(t.year, t.month, t.day, t.hour), closable: true));
              }),
            ]),
            _Group(title: 'الدفع', rows: [
              _Row('الدفع ثم النجاح', onTap: () => open(const _PayDemo(success: true))),
              _Row('الدفع ثم الفشل', onTap: () => open(const _PayDemo(success: false))),
              const _Row('تجربة حقيقية', hint: 'ادفع ببطاقة رقمها ينتهي بـ 0002 عشان يفشل'),
            ]),
            _Group(title: 'المواعيد', rows: [
              _Row('طلب مكرر', onTap: () => showDuplicateSheet(context, existing: sample)),
              _Row('إلغاء موعد مدفوع', onTap: () => showPaidCancelSheet(context, sample, 300)),
              _Row('إلغاء متأخر', onTap: () => showLateCancelSheet(context, sample, const Duration(minutes: 80))),
              _Row('التنبيهات مقفلة', onTap: () {
                Reminders.blocked.value = true;
                goTab(1);
              }),
              _Row('التقويم مقفل', onTap: () => showCalendarBlockedSheet(context)),
            ]),
            _Group(title: 'الدخول', rows: [
              _Row(
                'رمز التحقق غير صحيح',
                hint: 'اكتب أي رمز غير 1111',
                onTap: () => open(const OtpScreen(national: '551234567', inside: true)),
              ),
            ]),
          ],
        )),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 22, 10, 8),
            child: Semantics(header: true, child: Text(title, style: ts(20, weight: FontWeight.w500))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(32)),
            child: Column(
              children: [
                for (final r in rows) ...[
                  r,
                  if (r != rows.last) const Divider(height: 1, thickness: 1, color: AppColors.bg),
                ],
              ],
            ),
          ),
        ],
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, {this.hint, this.onTap});

  final String label;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: hint == null ? label : '$label، $hint',
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: ts(17)),
                    if (hint != null) Text(hint!, style: ts(13, color: AppColors.faint)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(CupertinoIcons.forward, size: 18, color: AppColors.faint),
            ],
          ),
        ),
      );
}

/// صفحة الأطباء وهي تتحمل
class _LoadingDemo extends StatelessWidget {
  const _LoadingDemo();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          top: false,
          child: FloatingBar(body: ListView(
            padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.contentTop, 14, 30),
            children: const [
              SizedBox(height: 14),
              BigTitle('الأطباء'),
              SizedBox(height: 14),
              Skeleton(height: 60, radius: 999),
              SizedBox(height: 14),
              DoctorCardSkeleton(),
              SizedBox(height: 14),
              DoctorCardSkeleton(),
            ],
          )),
        ),
      );
}

/// حركة الدفع: تحقق ثم نجاح أو فشل
class _PayDemo extends StatefulWidget {
  const _PayDemo({required this.success});

  final bool success;

  @override
  State<_PayDemo> createState() => _PayDemoState();
}

class _PayDemoState extends State<_PayDemo> {
  PayPhase _phase = PayPhase.processing;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() => _phase = widget.success ? PayPhase.success : PayPhase.failure);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (widget.success) {
      nav.pop();
    } else {
      nav.pushReplacement(iosRoute(const PaymentFailedScreen(amount: 200, methodText: 'مدى ···· 4821')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: PaymentProgressView(phase: _phase, amount: 200, methodText: 'مدى ···· 4821')),
      );
}
