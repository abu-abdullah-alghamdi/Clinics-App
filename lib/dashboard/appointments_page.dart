/// المواعيد حسب اليوم: حضر، ما حضر، الدفع في الفرع، تعديل، إلغاء
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../extras.dart';
import '../services_data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'desk.dart';
import 'schedule_sheet.dart';
import 'ui.dart';

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final desk = DeskScope.of(context);
    final list = desk.appointmentsOn(desk.day);
    final active = list.where((r) => r.booking.status == RequestStatus.scheduled).length;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 16, 16, 40),
      children: [
        PageHeader(title: 'المواعيد', trailing: active == 0 ? null : Tag('${fmtNum(active)} قادم')),
        const BranchFilter(),
        const _DayStrip(),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const EmptyNote(icon: CupertinoIcons.calendar, text: 'ما فيه مواعيد في هذا اليوم')
        else
          for (final r in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: AppointmentRow(request: r)),
      ],
    );
  }
}

/// أيام: أمس واليوم والأسبوعين الجاية، وعلى كل يوم عدد مواعيده
class _DayStrip extends StatefulWidget {
  const _DayStrip();

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  static const _first = -2;
  final _days = [for (var i = _first; i < 14; i++) DayInfo(i)];

  // يبدأ من اليوم (أمس وقبله على اليمين)
  late final _scroll = ScrollController(initialScrollOffset: -_first * 80.0);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desk = DeskScope.of(context);
    final days = _days;
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        controller: _scroll,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = days[i];
          final selected = sameDay(d.date, desk.day);
          final count = d.closed ? 0 : desk.appointmentsOn(d.date).where((r) => r.booking.status == RequestStatus.scheduled).length;
          final fg = selected ? AppColors.onAccent : (d.closed ? AppColors.closedText : AppColors.ink);
          return Pressable(
            onTap: () => desk.setDay(d.date),
            selected: selected,
            semanticLabel: '${d.full}، ${fmtNum(count)} موعد',
            child: Container(
              width: 72,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : (d.closed ? AppColors.closed : AppColors.white),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(d.label, style: ts(12, color: fg)),
                  Text(fmtNum(d.date.day), style: ts(24, weight: FontWeight.w600, color: fg, height: 1.2)),
                  Text(d.closed ? 'مغلق' : (count == 0 ? d.month : '${fmtNum(count)} موعد'), style: ts(11, color: fg)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AppointmentRow extends StatelessWidget {
  const AppointmentRow({super.key, required this.request});

  final DeskRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final b = r.booking;
    final desk = DeskScope.of(context);
    final role = desk.staff!.role;
    final phone = deskSize(context) == DeskSize.phone;
    final scheduled = b.status == RequestStatus.scheduled;

    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Text(fmtClock(b.at!), style: ts(18, weight: FontWeight.w600)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.patient, style: ts(16, weight: FontWeight.w600)),
              Text(b.title, style: ts(14)),
              Text('${b.doctor?.name ?? ''}، ${b.branch.name}', style: ts(13, color: AppColors.body)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [statusTag(r), if (!b.isPackage) payTag(r), if (r.fromApp) const Tag('من المعاينة', bg: Color(0xFFE6EDFD), fg: AppColors.blue)],
              ),
              if (b.cancelledByClinic) Padding(padding: const EdgeInsets.only(top: 6), child: Text(b.clinicCancelReason!, style: ts(13, color: AppColors.faint))),
            ],
          ),
        ),
        if (!phone) Text(b.priceText, style: ts(15, weight: FontWeight.w600)),
      ],
    );

    final actions = scheduled ? _actions(context, r, role) : const <Widget>[];
    return DeskCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, DeskRequest r, StaffRole role) {
    final desk = DeskScope.read(context);
    final started = r.booking.at!.isBefore(DateTime.now().add(const Duration(minutes: 30)));

    Widget button(String label, VoidCallback onTap, {Color? bg, Color? fg}) => PillButton(
          label: label,
          height: 44,
          fontSize: 15,
          padding: 18,
          bg: bg ?? AppColors.bg,
          fg: fg ?? AppColors.ink,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
        );

    return [
      // حضر وما حضر: من نص ساعة قبل الموعد
      if (started) button('حضر', () => desk.complete(r), bg: AppColors.accent, fg: AppColors.onAccent),
      if (started && role.canManage) button('ما حضر', () => desk.noShow(r)),
      if (role.canManage && !r.settled && !r.booking.isPackage) button('تأكيد الدفع', () => desk.confirmPayment(r)),
      if (role.canSchedule) button('تعديل الموعد', () => openSchedule(context, r)),
      if (role.canManage) button('إلغاء', () => openCancel(context, r), fg: AppColors.red),
    ];
  }
}
