/// عناصر مشتركة في لوحة العيادة (بنفس هوية التطبيق)
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../services_data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'desk.dart';

/// لون الرسوم البيانية: لون العيادة لو يبان على الأبيض، وإلا أسود
Color get chartColor => AppColors.accentOnBar;

/// عرض الشاشة: جوال، آيباد، كمبيوتر
enum DeskSize { phone, tablet, desktop }

DeskSize deskSize(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 760) return DeskSize.phone;
  if (w < 1240) return DeskSize.tablet;
  return DeskSize.desktop;
}

/// بطاقة بيضاء
class DeskCard extends StatelessWidget {
  const DeskCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(26)),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}

/// عنوان الصفحة وتحته الفلاتر
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // في الجوال ما فيه قائمة جانبية: نوع الحساب يطلع فوق العنوان
    final role = DeskScope.of(context).staff?.role;
    final phone = deskSize(context) == DeskSize.phone;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (phone && role != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: RoleBadge(role: role)),
          Row(
            children: [
              Expanded(child: Semantics(header: true, child: Text(title, style: ts(32, color: AppColors.title, height: 1.2)))),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Semantics(header: true, child: Text(text, style: ts(17, weight: FontWeight.w600))),
      );
}

/// شارة صغيرة (الحالة، الدفع)
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.bg = AppColors.bg, this.fg = AppColors.ink});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: ts(12, weight: FontWeight.w600, color: fg)),
      );
}

/// شارة حالة الطلب
Tag statusTag(DeskRequest r) {
  final b = r.booking;
  return switch (b.status) {
    RequestStatus.sent => const Tag('بانتظار الموعد', bg: Color(0xFFFFF1D6), fg: Color(0xFF8A5A00)),
    RequestStatus.approved => const Tag('بانتظار الدفع', bg: Color(0xFFFFF1D6), fg: Color(0xFF8A5A00)),
    RequestStatus.scheduled => const Tag('مؤكد', bg: Color(0xFFE6EDFD), fg: AppColors.blue),
    RequestStatus.completed => const Tag('حضر', bg: Color(0xFFE3F4E8), fg: AppColors.green),
    RequestStatus.noShow => const Tag('ما حضر', bg: Color(0xFFFDE8E7), fg: AppColors.red),
    RequestStatus.cancelled => const Tag('ملغي', bg: AppColors.closed, fg: AppColors.closedText),
  };
}

/// شارة الدفع
Tag payTag(DeskRequest r) {
  final b = r.booking;
  if (b.free) return const Tag('بدون مبلغ');
  if (b.paid) return Tag(b.orderNumber == 'branch' ? 'دفع في الفرع' : 'مدفوع', bg: const Color(0xFFE3F4E8), fg: AppColors.green);
  if (b.payLater) return const Tag('يدفع في الفرع');
  return const Tag('غير مدفوع', bg: Color(0xFFFDE8E7), fg: AppColors.red);
}

/// فلتر الفرع (للمالك بس)
class BranchFilter extends StatelessWidget {
  const BranchFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final desk = DeskScope.of(context);
    if (!(desk.staff?.role.allBranches ?? false)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterPill(label: 'كل الفروع', selected: desk.branchFilter == null, onTap: () => desk.setBranchFilter(null)),
            for (final b in branches) ...[
              const SizedBox(width: 8),
              FilterPill(label: b.name, selected: desk.branchFilter == b.id, onTap: () => desk.setBranchFilter(b.id)),
            ],
          ],
        ),
      ),
    );
  }
}

/// صورة المريض: أول حرف من اسمه
class PatientAvatar extends StatelessWidget {
  const PatientAvatar({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
        child: Text(name.isEmpty ? '؟' : name.characters.first, style: ts(size * 0.4, weight: FontWeight.w600)),
      );
}

/// حالة فاضية
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DeskCard(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Icon(icon, size: 34, color: AppColors.faint),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: ts(16, color: AppColors.body)),
          ],
        ),
      );
}

/// يفتح نافذة: في الكمبيوتر والآيباد بالنص، وفي الجوال من تحت
Future<T?> showDeskSheet<T>(BuildContext context, WidgetBuilder builder) {
  if (deskSize(context) == DeskSize.phone) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.bg,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
        child: builder(ctx),
      ),
    ),
  );
}

/// رأس النافذة: العنوان وزر الإغلاق
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 6),
        child: Row(
          children: [
            Expanded(child: Text(title, style: ts(22, weight: FontWeight.w600))),
            CircleButton(icon: Icons.close_rounded, semanticLabel: 'إغلاق', onTap: () => Navigator.of(context).pop()),
          ],
        ),
      );
}

/// "الأحد 22 نوفمبر، 5:30 م"
String fmtAppointment(DateTime t) => '${fmtDay(t)}، ${fmtClock(t)}';

/// نوع الحساب: الاستقبال أو إدارة العيادة
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final StaffRole role;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: role == StaffRole.admin ? AppColors.accent : AppColors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              role == StaffRole.admin ? CupertinoIcons.person_badge_plus : CupertinoIcons.person_2,
              size: 16,
              color: role == StaffRole.admin ? AppColors.onAccent : AppColors.ink,
            ),
            const SizedBox(width: 6),
            Text(role.label, style: ts(14, weight: FontWeight.w600, color: role == StaffRole.admin ? AppColors.onAccent : AppColors.ink)),
          ],
        ),
      );
}
