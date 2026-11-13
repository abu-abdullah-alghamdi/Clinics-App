import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../extras.dart';
import '../main.dart';
import '../native.dart';
import '../services_data.dart';
import '../state.dart';
import '../states.dart';
import '../theme.dart';
import '../widgets.dart';
import 'extras_screens.dart';
import 'payment_screen.dart';
import 'request_screen.dart';
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

  /// السحب لتحت للتحديث (لما يتربط النظام يجيب الطلبات والمواعيد من السيرفر)
  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  bool _show(Booking b) => switch (_filter) {
        'requests' => b.status == RequestStatus.sent || b.status == RequestStatus.approved,
        'upcoming' => b.status == RequestStatus.scheduled,
        'past' => b.past,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.sorted.where(_show).toList();

    // العنوان الكبير يتعامل مع الساعة فوق، والـ SafeArea للأطراف بس
    return SafeArea(
      top: false,
      bottom: false,
      child: LargeTitleScroll(
        title: 'مواعيدي',
        onRefresh: _refresh,
        bottomSpace: navBottomSpace,
        children: [
          // التنبيهات مقفلة: يطلع بس لو عنده موعد محدد
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
              for (final f in const [('all', 'الكل'), ('requests', 'الطلبات'), ('upcoming', 'القادمة'), ('past', 'السابقة')])
                FilterPill(
                  label: f.$2,
                  selected: _filter == f.$1,
                  onTap: () => setState(() => _filter = f.$1),
                ),
            ],
          ),
          // كيف كانت زيارتك؟ (آخر زيارة مكتملة ما تقيّمت)
          if ((_filter == 'all' || _filter == 'past') && s.toRate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: RatePrompt(booking: s.toRate!),
            ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: StatusCard(
                icon: CupertinoIcons.calendar,
                iconBg: AppColors.accent,
                title: 'ما عندك مواعيد',
                actions: [
                  PillButton(label: 'اطلب موعد', height: 50, fontSize: 17, onTap: () => s.openDoctors()),
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
              child: RequestCard(booking: b),
            ),
        ],
      ),
    );
  }
}

/// "يوم"، "يومين"، "5 أيام"، "12 يوم"
String daysText(int n) => n == 1
    ? 'يوم'
    : n == 2
        ? 'يومين'
        : n <= 10
            ? '${fmtNum(n)} أيام'
            : '${fmtNum(n)} يوم';

/// شارة حالة الطلب: النص، الخلفية، ولون النص
(String, Color, Color) requestBadge(Booking b) => switch (b.status) {
      RequestStatus.sent => ('تم إرسال الطلب', const Color(0xFFFFF4D6), const Color(0xFF8A5A00)),
      RequestStatus.approved => ('وافقت العيادة', const Color(0xFFE3F5E9), AppColors.green),
      RequestStatus.scheduled => ('تم تحديد الموعد', const Color(0xFFE6EDFD), AppColors.blue),
      RequestStatus.completed => (b.isPackage ? 'تم تفعيل الباقة' : 'مكتملة', const Color(0xFFE3F5E9), AppColors.green),
      RequestStatus.noShow => ('لم تحضر', AppColors.closed, AppColors.ink),
      RequestStatus.cancelled => (b.cancelledByClinic ? 'ألغته العيادة' : 'ملغي', const Color(0xFFFBE3E1), AppColors.red),
    };

/// بطاقة طلب أو موعد في "مواعيدي" (تتغير حسب الحالة)
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.booking});

  final Booking booking;

  Widget _box(Widget child, {Color color = AppColors.bg}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
        child: child,
      );

  /// يوم الموعد ووقته والفرع
  Widget _whenBox(DateTime at) => _box(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fmtDay(at), style: ts(22, color: AppColors.blue)),
          Text(fmtClock(at), style: ts(17, weight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(booking.branch.name, style: ts(15, weight: FontWeight.w600)),
        ],
      ));

  Future<void> _calendar(BuildContext context) async {
    final ok = await addBookingToCalendar(booking);
    if (!ok && context.mounted) await showCalendarBlockedSheet(context);
  }

  void _again(BuildContext context) {
    final b = booking;
    openRequest(context, service: b.service, package: b.status == RequestStatus.cancelled ? b.package : null);
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final s = AppScope.of(context);
    final (label, badgeBg, badgeFg) = requestBadge(b);
    final at = b.at;
    final scheduled = b.status == RequestStatus.scheduled && at != null;
    final payable = !b.free && !b.paid && (scheduled || b.status == RequestStatus.approved);

    // سطر المبلغ: مدفوع، أو الدفع في الفرع، أو المبلغ
    String? payText;
    if (!b.free && (b.active || (b.isPackage && b.status == RequestStatus.completed))) {
      payText = b.paid
          ? 'مدفوع ${money(s.orderFor(b)?.total ?? b.price)}'
          : b.payLater
              ? 'الدفع في الفرع ${b.priceText}'
              : b.priceText;
    } else if (b.free && b.active) {
      payText = b.priceText;
    }

    final cancel = PillButton(
      label: scheduled ? 'إلغاء الموعد' : 'إلغاء الطلب',
      height: 50,
      fontSize: 16,
      bg: AppColors.bg,
      fg: AppColors.red,
      onTap: () => confirmCancelBooking(context, b),
    );

    final actions = <Widget>[
      // الدفع: بعد ما تحدد العيادة الموعد (أو توافق على الباقة)
      if (payable)
        Row(
          children: [
            Expanded(
              child: PillButton(
                label: 'ادفع الحين',
                height: 50,
                fontSize: 16,
                onTap: () => Navigator.of(context).push(iosRoute(PaymentScreen(request: b))),
              ),
            ),
            if (!b.payLater) ...[
              const SizedBox(width: 6),
              Expanded(
                child: PillButton(
                  label: 'ادفع لاحقاً',
                  height: 50,
                  fontSize: 16,
                  bg: AppColors.bg,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    s.payLater(b.id);
                  },
                ),
              ),
            ],
          ],
        ),
      if (scheduled)
        Row(
          children: [
            // الاتجاهات للفرع (قوقل ماب)
            CircleButton(
              icon: CupertinoIcons.location_fill,
              size: 50,
              bg: AppColors.ink,
              fg: AppColors.white,
              semanticLabel: 'الاتجاهات إلى ${b.branch.name}',
              onTap: () => launchUrl(b.branch.mapsUri, mode: LaunchMode.externalApplication),
            ),
            const SizedBox(width: 6),
            CircleButton(
              icon: CupertinoIcons.calendar_badge_plus,
              size: 50,
              bg: AppColors.bg,
              semanticLabel: 'أضف إلى التقويم',
              onTap: () => _calendar(context),
            ),
            const SizedBox(width: 6),
            Expanded(child: cancel),
          ],
        )
      else if (b.active)
        cancel,
      if (b.status == RequestStatus.completed && b.isPackage)
        PillButton(label: 'باقاتي', height: 50, fontSize: 16, onTap: () => Navigator.of(context).push(iosRoute(const PackagesScreen()))),
      if (b.status == RequestStatus.completed && !b.isPackage) ...[
        // رتوش جلسة الليزر خلال المدة
        if (s.touchUpDaysLeft(b) case final left?)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillButton(label: 'اطلب الرتوش', height: 50, fontSize: 16, onTap: () => requestTouchUp(context, b)),
              const SizedBox(height: 6),
              Text('باقي ${daysText(left)}', textAlign: TextAlign.center, style: ts(13, color: AppColors.faint)),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: PillButton(label: 'اطلب مرة ثانية', height: 50, fontSize: 16, bg: AppColors.bg, onTap: () => _again(context)),
            ),
            const SizedBox(width: 10),
            if (s.ratings[b.id] case final stars?)
              RatedStars(stars: stars)
            else
              PillButton(
                label: 'قيّم',
                height: 50,
                fontSize: 16,
                padding: 22,
                bg: AppColors.ink,
                fg: AppColors.white,
                onTap: () => showRatingSheet(context, b),
              ),
          ],
        ),
      ],
      if (b.status == RequestStatus.noShow || b.status == RequestStatus.cancelled)
        PillButton(label: 'اطلب مرة ثانية', height: 50, fontSize: 16, bg: AppColors.bg, onTap: () => _again(context)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: cardShadow,
        border: highContrast(context) ? Border.all(color: AppColors.ink, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                child: Text(label, style: ts(13, weight: FontWeight.w600, color: badgeFg)),
              ),
              const Spacer(),
              // رقم الطلب، ومرجع الإرسال لو انرسل مع طلبات ثانية من السلة
              Text(lines([b.number, b.groupRef]), textAlign: TextAlign.end, style: ts(13, color: AppColors.faint)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              RequestAvatar(booking: b),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, style: ts(20, height: 1.3)),
                    if (b.packageName != null) Text(b.packageName!, style: ts(15, color: AppColors.body)),
                    Text(b.doctor?.name ?? 'الطبيب المتاح', style: ts(14, color: AppColors.body)),
                    if (b.forOther) Text('لـ ${b.recipientName}', style: ts(14, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (scheduled)
            _whenBox(at!)
          else if (b.status == RequestStatus.sent)
            _box(
              Row(
                children: [
                  const Icon(CupertinoIcons.clock, size: 22, color: Color(0xFF8A5A00)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم إرسال طلبك بنجاح إلى العيادة، سيتم التواصل معك',
                      style: ts(15, weight: FontWeight.w500, color: const Color(0xFF8A5A00), height: 1.5),
                    ),
                  ),
                ],
              ),
              color: const Color(0xFFFFF4D6),
            )
          else
            Text(
              at != null && !b.isPackage ? lines([fmtWhen(at), b.branch.name]) : lines([b.branch.name, b.period.label]),
              style: ts(15, color: b.status == RequestStatus.cancelled ? AppColors.closedText : AppColors.ink,
                  decoration: b.status == RequestStatus.cancelled && at != null ? TextDecoration.lineThrough : null),
            ),
          if (b.status == RequestStatus.sent) ...[
            const SizedBox(height: 10),
            Text(lines([b.branch.name, b.period.label]), style: ts(15)),
          ],
          // سبب إلغاء العيادة (والمبلغ يرجع كامل لو مدفوع)
          if (b.cancelledByClinic) ...[
            const SizedBox(height: 10),
            _box(Text(
              b.paid ? '${b.clinicCancelReason}، والمبلغ يرجع لك كامل' : b.clinicCancelReason!,
              style: ts(14, color: AppColors.body, height: 1.6),
            )),
          ],
          if (payText != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(b.paid ? Icons.check_rounded : CupertinoIcons.creditcard, size: 18, color: b.paid ? AppColors.green : AppColors.faint),
                const SizedBox(width: 6),
                Expanded(child: Text(payText, style: ts(15, weight: FontWeight.w500))),
              ],
            ),
          ],
          for (final a in actions) ...[const SizedBox(height: 12), a],
        ],
      ),
    );
  }
}
