import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../native.dart';
import '../services_data.dart';
import '../state.dart';
import '../states.dart';
import '../theme.dart';
import '../widgets.dart';
import 'booking_screen.dart';
import 'shell.dart';
import 'visit_extras.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  String _filter = 'all';

  /// المستخدم قفل تنبيه "التنبيهات مقفلة" (يرجع مع فتح التطبيق مرة ثانية)
  bool _bannerClosed = false;

  /// السحب لتحت للتحديث (لما يتربط النظام يجيب المواعيد من السيرفر)
  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.sorted
        .where((b) => _filter == 'all' || (_filter == 'upcoming' ? !b.completed : b.completed))
        .toList();

    // العنوان الكبير يتعامل مع الساعة فوق، والـ SafeArea للأطراف بس
    return SafeArea(
      top: false,
      bottom: false,
      child: LargeTitleScroll(
        title: 'مواعيدي',
        onRefresh: _refresh,
        bottomSpace: navBottomSpace,
        children: [
          // التنبيهات مقفلة: يطلع بس لو عنده موعد قادم
          ValueListenableBuilder<bool>(
            valueListenable: Reminders.blocked,
            builder: (context, blocked, _) => blocked && !_bannerClosed && s.upcoming.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: NotificationsBanner(onClose: () => setState(() => _bannerClosed = true)),
                  )
                : const SizedBox.shrink(),
          ),
          HScroll(
            height: 60,
            children: [
              for (final f in const [('all', 'الكل'), ('upcoming', 'القادمة'), ('completed', 'المكتملة')])
                FilterPill(
                  label: f.$2,
                  selected: _filter == f.$1,
                  onTap: () => setState(() => _filter = f.$1),
                ),
            ],
          ),
          // كيف كانت زيارتك؟ (آخر زيارة مكتملة ما تقيّمت)
          if (_filter != 'upcoming' && s.toRate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: RatePrompt(booking: s.toRate!),
            ),
          // اللي دفعها لشخص ثاني: تنتظر العيادة تحدد الموعد
          if (_filter != 'completed')
            for (final o in s.forOthers)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: OtherPersonCard(order: o),
              ),
          if (list.isEmpty && (_filter == 'completed' || s.forOthers.isEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: StatusCard(
                icon: CupertinoIcons.calendar,
                iconBg: AppColors.accent,
                title: 'ما عندك موعد',
                actions: [
                  PillButton(label: 'احجز موعد', height: 50, fontSize: 17, onTap: () => s.openDoctors()),
                  const SizedBox(height: 6),
                  PillButton(
                    label: 'تصفح الخدمات',
                    height: 50,
                    fontSize: 15,
                    weight: FontWeight.w400,
                    bg: Colors.transparent,
                    onTap: () => s.openServices(),
                  ),
                ],
              ),
            ),
          for (final b in list)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: b.completed || b.cancelledByClinic
                  ? _AppointmentCard(booking: b)
                  // اسحب البطاقة: تعديل أو إلغاء (مثل البريد والرسائل)
                  : Slidable(
                      key: ValueKey(b.id),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.46,
                        children: [
                          _SwipeAction(
                            label: 'تعديل',
                            icon: CupertinoIcons.calendar,
                            color: const Color(0xFF8E8E93),
                            onTap: () => openBooking(context, b.doctor, cat: b.cat, editing: b),
                          ),
                          _SwipeAction(
                            label: 'إلغاء',
                            icon: CupertinoIcons.trash,
                            color: AppColors.red,
                            onTap: () => confirmCancelBooking(context, b),
                          ),
                        ],
                      ),
                      child: _AppointmentCard(booking: b),
                    ),
            ),
        ],
      ),
    );
  }
}

/// زر يطلع لما تسحب بطاقة الموعد
class _SwipeAction extends StatelessWidget {
  const _SwipeAction({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CustomSlidableAction(
        onPressed: (_) => onTap(),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(40)),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: AppColors.white),
              const SizedBox(height: 6),
              Text(label, style: ts(15, weight: FontWeight.w500, color: AppColors.white)),
            ],
          ),
        ),
      );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final d = b.doctor;
    if (b.cancelledByClinic) return _CancelledCard(booking: b);
    final s = AppScope.of(context);
    final stars = s.ratings[b.id];
    Widget bottom;
    if (b.completed) {
      bottom = Row(
        children: [
          Expanded(
            child: PillButton(
              label: 'احجز مرة ثانية',
              onTap: () => openBooking(context, d, cat: b.cat, day: firstOpenDay()),
            ),
          ),
          if (stars != null) ...[const SizedBox(width: 10), RatedStars(stars: stars)],
        ],
      );
    } else if (b.dayIndex == 0 && s.checkedIn.contains(b.id)) {
      // سجّل وصوله: دوره والتواصل مع الاستقبال
      bottom = const CheckedInBox();
    } else {
      final row = Row(
        children: [
          // الاتجاهات للفرع (خرائط آبل)
          CircleButton(
            icon: CupertinoIcons.location_fill,
            size: 44,
            bg: AppColors.ink,
            fg: AppColors.white,
            semanticLabel: 'الاتجاهات إلى ${b.branch.name}',
            onTap: () => launchUrl(b.branch.mapsUri, mode: LaunchMode.externalApplication),
          ),
          const SizedBox(width: 6),
          Expanded(child: PillButton(label: 'إعادة جدولة', onTap: () => openBooking(context, d, cat: b.cat, editing: b))),
          const SizedBox(width: 6),
          PillButton(
            label: 'إلغاء',
            bg: AppColors.bg,
            fg: AppColors.red,
            fontSize: 16,
            padding: 22,
            onTap: () => confirmCancelBooking(context, b),
          ),
        ],
      );
      // يوم الموعد: زر "وصلت" يبلغ الاستقبال
      bottom = b.dayIndex == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PillButton(
                  label: 'وصلت',
                  icon: CupertinoIcons.location_solid,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    s.checkIn(b.id);
                  },
                ),
                const SizedBox(height: 8),
                row,
              ],
            )
          : row;
    }

    return CutCard(
      image: d.image,
      imageHeight: 276,
      bottom: bottom,
      children: [
        Text('${d.n1}\n${d.n2}', style: ts(32, height: 1.2)),
        const SizedBox(height: 4),
        Text(d.role, style: ts(15, color: AppColors.body)),
        const SizedBox(height: 12),
        Text(b.completed ? 'مكتمل' : 'قادم', style: ts(28, color: b.completed ? AppColors.green : AppColors.blue)),
        Text(b.title, style: ts(15)),
        Text(b.day.full, style: ts(15, weight: FontWeight.w500)),
        Text(b.range, style: ts(15)),
        const SizedBox(height: 4),
        Text(b.branch.name, style: ts(15, weight: FontWeight.w600)),
      ],
    );
  }
}

/// موعد ألغته العيادة: شارة واضحة، السبب، وطريقة الحجز من جديد
class _CancelledCard extends StatelessWidget {
  const _CancelledCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final d = b.doctor;
    final s = AppScope.of(context);
    final paid = s.orderFor(b)?.paidOnline ?? false;
    return CutCard(
      image: d.image,
      imageHeight: 236,
      imageWidth: 170,
      borderColor: const Color(0xFFF3C7C2),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(20)),
            child: Text(
              paid ? '${b.clinicCancelReason}، والمبلغ يرجع لك كامل' : b.clinicCancelReason!,
              style: ts(14, color: AppColors.body, height: 1.6),
            ),
          ),
          const SizedBox(height: 12),
          PillButton(
            label: 'احجز موعد جديد مع ${d.n1}',
            height: 50,
            fontSize: 16,
            onTap: () => openBooking(context, d, cat: b.cat),
          ),
          PillButton(
            label: 'اختر طبيب ثاني',
            height: 50,
            fontSize: 15,
            weight: FontWeight.w400,
            bg: Colors.transparent,
            onTap: () => s.openDoctors(b.cat),
          ),
        ],
      ),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFFFBE3E1), borderRadius: BorderRadius.circular(999)),
          child: Text('ألغته العيادة', style: ts(13, weight: FontWeight.w600, color: AppColors.red)),
        ),
        const SizedBox(height: 12),
        Text('${d.n1}\n${d.n2}', style: ts(30, height: 1.2)),
        const SizedBox(height: 4),
        Text('${b.title} · ${b.branch.name}', style: ts(15, color: AppColors.body)),
        const SizedBox(height: 10),
        Text(
          '${b.day.full} · ${fmtTime(b.time)}',
          style: ts(18, color: AppColors.closedText, decoration: TextDecoration.lineThrough),
        ),
      ],
    );
  }
}
