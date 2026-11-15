import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';

/// مقارنة قبل وبعد: كل اللي باقي أسود، وشكله لو صار بلون هوية العيادة (للتجربة قبل الاعتماد)
class BrandCompareScreen extends StatelessWidget {
  const BrandCompareScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          top: false,
          child: FloatingBar(
            title: 'قبل وبعد',
            body: ListView(
              padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.belowBar, 14, 40),
              children: [
                _header('أزرار'),
                _Item(1, 'زر قيّم', (a) => _pill('قيّم', a, padding: 22, fontSize: 16)),
                _Item(2, 'زر تحديد الموقع في بطاقة الموعد', (a) => CircleButton(icon: CupertinoIcons.location_fill, size: 50, bg: _c(a), fg: _on(a), onTap: () {})),
                _Item(3, 'زر الاتجاهات في الفروع', (a) => _pill('الاتجاهات', a, icon: CupertinoIcons.location_fill, fontSize: 15, padding: 12)),
                _Item(4, 'شريط عرض السلة', _cartBar, wide: true, surface: AppColors.bg),
                _Item(5, 'زر تطبيق الكوبون', (a) => _pill('تطبيق', a, height: 40, fontSize: 15, padding: 18)),
                _Item(6, 'اتصل بالفرع (نافذة الإلغاء)', (a) => _pill('اتصل بفرع الروضة', a, icon: CupertinoIcons.phone_fill), wide: true),
                _Item(7, 'زر تفعيل (التقويم والتنبيهات)', (a) => _pill('تفعيل', a, height: 40, fontSize: 14, padding: 18)),
                _Item(8, 'حاول مرة ثانية', (a) => _pill('حاول مرة ثانية', a, icon: CupertinoIcons.arrow_clockwise), wide: true),
                _Item(9, 'تحديث من App Store', (a) => _pill('تحديث من App Store', a, icon: CupertinoIcons.arrow_down_to_line), wide: true),
                _header('مؤشرات الاختيار والتقدم'),
                _Item(10, 'مفتاح تذكير واتساب', (a) => _SwitchDemo(color: _c(a))),
                _Item(11, 'الخط تحت التبويب المختار', _tabs, wide: true),
                _Item(12, 'إطار البطاقة المختارة', _choice, wide: true, surface: AppColors.bg),
                _Item(13, 'الدائرة حول علامة ✓', _dots),
                _Item(14, 'مربع رمز التحقق النشط', _otp, wide: true, surface: AppColors.bg),
                _Item(15, 'نقاط الصفحات', _pageDots),
                _Item(16, 'جلسات الباقة المستخدمة', _sessions, wide: true),
                _Item(17, 'رقم السلة الصغير', _badge, surface: AppColors.bg),
                _header('اقتراحي تبقى سوداء'),
                _Item(19, 'زر السلة لما تكون الخدمة مضافة', _cartButtons, note: 'أول مربع (+) هو غير المضاف، وهو بلون الهوية في الحالتين'),
                _Item(20, 'زر ادفع في التقسيط', (a) => _pill('ادفع', a), wide: true),
                _Item(21, 'حد البطاقة التجريبية في الدفع', _demoCard, wide: true, surface: AppColors.bg),
              ],
            ),
          ),
        ),
      );
}

/// قبل = أسود بخط أبيض، بعد = لون العيادة بخطها
Color _c(bool after) => after ? AppColors.accent : AppColors.ink;
Color _on(bool after) => after ? AppColors.onAccent : AppColors.white;

Widget _header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
      child: Semantics(header: true, child: Text(text, style: ts(20, weight: FontWeight.w500))),
    );

Widget _pill(String label, bool a, {IconData? icon, double height = 50, double fontSize = 17, double padding = 24}) => PillButton(
      label: label,
      icon: icon,
      height: height,
      fontSize: fontSize,
      padding: padding,
      bg: _c(a),
      fg: _on(a),
      onTap: () {},
    );

class _Item extends StatelessWidget {
  const _Item(this.no, this.title, this.sample, {this.wide = false, this.surface = AppColors.white, this.note});

  final int no;
  final String title;
  final Widget Function(bool after) sample;

  /// العريض: قبل فوق وبعد تحته، وغيره جنب بعض
  final bool wide;

  /// الخلفية اللي يطلع عليها العنصر في التطبيق
  final Color surface;
  final String? note;

  Widget _side(String label, bool after) => Column(
        crossAxisAlignment: wide ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
        children: [
          Text(label, textAlign: TextAlign.center, style: ts(13, weight: FontWeight.w600, color: after ? AppColors.ink : AppColors.faint)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
            child: sample(after),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$no. $title', style: ts(16, weight: FontWeight.w600)),
            if (note != null) Text(note!, style: ts(13, color: AppColors.faint)),
            const SizedBox(height: 12),
            if (wide) ...[
              _side('قبل', false),
              const SizedBox(height: 12),
              _side('بعد', true),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _side('قبل', false)),
                  const SizedBox(width: 10),
                  Expanded(child: _side('بعد', true)),
                ],
              ),
          ],
        ),
      );
}

/// 4. شريط عرض السلة (بعد: مربع العدد يصير بلون الخط عشان يبان فوق لون العيادة)
Widget _cartBar(bool a) => Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 22, 10),
      decoration: BoxDecoration(
        color: _c(a),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 42),
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: a ? AppColors.onAccent : AppColors.accent, borderRadius: BorderRadius.circular(14)),
            child: Text('2', style: ts(18, weight: FontWeight.w700, color: a ? AppColors.accent : AppColors.onAccent)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('عرض السلة', style: ts(17, weight: FontWeight.w600, color: _on(a)))),
          Icon(CupertinoIcons.chevron_left, size: 18, color: _on(a)),
        ],
      ),
    );

/// 11. تبويبات صفحة الخدمات
Widget _tabs(bool a) => Row(
      children: [
        for (final (i, label) in const ['الكشف', 'الخدمات', 'الباقات', 'العروض'].indexed)
          Expanded(
            child: Column(
              children: [
                Text(label, style: ts(15, weight: i == 0 ? FontWeight.w700 : FontWeight.w400, color: i == 0 ? AppColors.ink : AppColors.body)),
                const SizedBox(height: 8),
                Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: i == 0 ? _c(a) : AppColors.ink.withAlpha(0), borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
      ],
    );

/// دائرة ✓ (حدها يتغيّر في 13 بس)
Widget _dot(bool selected, Color border) => Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      child: selected ? const Icon(Icons.check_rounded, size: 18, color: AppColors.onAccent) : null,
    );

/// 12. بطاقة الطبيب المختار في صفحة الطلب
Widget _choice(bool a) => Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _c(a), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.person_2_fill, size: 22, color: AppColors.onAccent),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('الطبيب المتاح', style: ts(16, weight: FontWeight.w600))),
          Text('400', style: ts(14, weight: FontWeight.w600)),
          const SizedBox(width: 10),
          _dot(true, AppColors.ink),
        ],
      ),
    );

/// 13. دائرة ✓ المختارة (وجنبها غير المختارة ما تتغيّر)
Widget _dots(bool a) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [_dot(true, _c(a)), const SizedBox(width: 14), _dot(false, AppColors.ink)],
    );

/// 14. مربعات رمز التحقق: الثالث هو اللي تكتب فيه
Widget _otp(bool a) => Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: i == 2 ? _c(a) : Colors.transparent, width: 1),
              ),
              child: Text(i < 2 ? '${i + 1}' : '', style: ts(28, weight: FontWeight.w500)),
            ),
          ),
        ],
      ],
    );

/// 15. نقاط الصفحات
Widget _pageDots(bool a) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == 0 ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(color: i == 0 ? _c(a) : AppColors.disabled, borderRadius: BorderRadius.circular(999)),
          ),
      ],
    );

/// 16. جلسات الباقة: أول جلستين مستخدمة
Widget _sessions(bool a) => Row(
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: i < 2 ? _c(a) : AppColors.bg, borderRadius: BorderRadius.circular(12)),
              child: i < 2 ? Icon(Icons.check_rounded, size: 18, color: _on(a)) : Text('${i + 1}', style: ts(13, color: AppColors.faint)),
            ),
          ),
        ],
      ],
    );

/// 17. رقم السلة على أيقونتها
Widget _badge(bool a) => SizedBox(
      width: 56,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.bag, size: 20, color: AppColors.ink),
          ),
          PositionedDirectional(
            top: -2,
            end: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _c(a),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.bg, width: 2),
              ),
              child: Text('2', style: ts(11, weight: FontWeight.w700, color: _on(a), height: 1)),
            ),
          ),
        ],
      ),
    );

/// 19. أزرار السلة: غير مضاف، مضاف (بطاقة الخدمة)، مضاف (صفحة الخدمة)
Widget _cartButtons(bool a) {
  Widget square(bool added) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: added ? _c(a) : AppColors.accent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Icon(added ? Icons.check_rounded : Icons.add_rounded, size: 24, color: added ? _on(a) : AppColors.onAccent),
      );
  return Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      square(false),
      square(true),
      CircleButton(icon: CupertinoIcons.bag_fill, size: 44, iconSize: 20, bg: _c(a), fg: _on(a), onTap: () {}),
    ],
  );
}

/// 21. بطاقة أرقام الاختبار في صفحة الدفع
Widget _demoCard(bool a) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _c(a), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.creditcard, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('بطاقة تجريبية', style: ts(15, weight: FontWeight.w600)),
                Text('4111 1111 1111 1111', textDirection: TextDirection.ltr, style: ts(14, color: AppColors.body)),
              ],
            ),
          ),
        ],
      ),
    );

/// 10. المفتاح يشتغل فعلاً عشان تشوفه وهو مطفي وشغال
class _SwitchDemo extends StatefulWidget {
  const _SwitchDemo({required this.color});

  final Color color;

  @override
  State<_SwitchDemo> createState() => _SwitchDemoState();
}

class _SwitchDemoState extends State<_SwitchDemo> {
  bool _on = true;

  @override
  Widget build(BuildContext context) => CupertinoSwitch(
        value: _on,
        activeTrackColor: widget.color,
        onChanged: (v) => setState(() => _on = v),
      );
}
