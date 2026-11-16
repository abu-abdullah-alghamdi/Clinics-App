/// تحديد الموعد وإرساله للعميل، وإلغاء الموعد
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../extras.dart';
import '../services_data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'desk.dart';
import 'ui.dart';

Future<void> openSchedule(BuildContext context, DeskRequest r) => showDeskSheet<void>(context, (_) => ScheduleSheet(request: r));

Future<void> openCancel(BuildContext context, DeskRequest r) => showDeskSheet<void>(context, (_) => CancelSheet(request: r));

class ScheduleSheet extends StatefulWidget {
  const ScheduleSheet({super.key, required this.request});

  final DeskRequest request;

  @override
  State<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<ScheduleSheet> {
  late final List<DateTime> _days = openDays();
  late DateTime _day;
  late Period _period;
  DateTime? _time;
  String? _doctorId;
  bool _sent = false;

  DeskRequest get r => widget.request;

  @override
  void initState() {
    super.initState();
    final b = r.booking;
    _period = b.period;
    _doctorId = b.doctorId;
    // تعديل موعد: يبدأ من الموعد الحالي
    final at = b.at;
    if (at != null && b.status == RequestStatus.scheduled) {
      _day = _days.firstWhere((d) => sameDay(d, at), orElse: () => _days.first);
      _time = at;
      _period = at.hour < 12 ? Period.morning : (at.hour < 16 ? Period.noon : Period.evening);
    } else {
      // أول يوم فيه وقت فاضي في الفترة المطلوبة
      _day = _days.firstWhere((d) => _free(d, _period).isNotEmpty, orElse: () => _days.first);
    }
  }

  List<DateTime> _free(DateTime day, Period p) {
    final now = DateTime.now();
    return slotsFor(day, p).where((t) => t.isAfter(now)).toList();
  }

  bool _busy(DateTime t) {
    final d = _doctorId;
    return d != null && DeskScope.read(context).busy(d, t, except: r.id);
  }

  void _send() {
    final at = _time;
    final doc = _doctorId;
    if (at == null || doc == null) return;
    HapticFeedback.mediumImpact();
    DeskScope.read(context).schedule(r, at: at, doctorId: doc);
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) return _done();
    final desk = DeskScope.of(context);
    final b = r.booking;
    final doctors = desk.doctorsOf(r);
    final times = slotsFor(_day, _period);
    final now = DateTime.now();
    final ready = _time != null && _doctorId != null && !_busy(_time!);
    final summary = [
      if (_time != null) fmtAppointment(_time!),
      if (_doctorId != null) doctorById(_doctorId!).name,
    ].join('، ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(title: b.status == RequestStatus.scheduled ? 'تعديل الموعد' : 'تحديد الموعد'),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              _requestCard(),
              const SectionLabel('اليوم'),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _dayChip(_days[i]),
                ),
              ),
              const SectionLabel('الوقت'),
              SegmentedPill(
                options: [for (final p in Period.values) p.label],
                selected: _period.index,
                onChanged: (i) => setState(() {
                  _period = Period.values[i];
                  _time = null;
                }),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in times) _timeChip(t, past: !t.isAfter(now), busy: _busy(t)),
                ],
              ),
              const SectionLabel('الطبيب'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final d in doctors) _doctorChip(d)],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(color: AppColors.white),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(summary, textAlign: TextAlign.center, style: ts(15, weight: FontWeight.w500)),
                  ),
                PillButton(label: 'إرسال للعميل', icon: Icons.send_rounded, enabled: ready, onTap: _send),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _requestCard() {
    final b = r.booking;
    return DeskCard(
      child: Row(
        children: [
          PatientAvatar(name: r.patient),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.patient, style: ts(17, weight: FontWeight.w600)),
                Text(r.phone, textDirection: TextDirection.ltr, style: ts(13, color: AppColors.faint)),
                const SizedBox(height: 6),
                Text(b.title, style: ts(15, weight: FontWeight.w500)),
                if (b.packageName != null) Text(b.packageName!, style: ts(13, color: AppColors.body)),
                Text('${b.branch.name}، ${b.period.label}، ${b.doctor?.name ?? 'الطبيب المتاح'}', style: ts(13, color: AppColors.body)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(b.priceText, style: ts(15, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _dayChip(DateTime d) {
    final selected = sameDay(d, _day);
    final info = DayInfo((d.difference(appToday).inHours / 24).round());
    final fg = selected ? AppColors.onAccent : AppColors.ink;
    return Pressable(
      onTap: () => setState(() {
        _day = d;
        _time = null;
      }),
      selected: selected,
      semanticLabel: info.full,
      child: Container(
        width: 72,
        decoration: BoxDecoration(color: selected ? AppColors.accent : AppColors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(info.label, style: ts(12, color: fg)),
            Text(fmtNum(d.day), style: ts(24, weight: FontWeight.w600, color: fg, height: 1.2)),
            Text(info.month, style: ts(11, color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(DateTime t, {required bool past, required bool busy}) {
    final selected = _time == t;
    final enabled = !past && !busy;
    final label = fmtClock(t);
    return Pressable(
      onTap: enabled ? () => setState(() => _time = t) : null,
      enabled: enabled,
      selected: selected,
      semanticLabel: busy ? '$label، محجوز' : label,
      child: Container(
        width: 96,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : (enabled ? AppColors.white : AppColors.closed),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: ts(15,
              weight: FontWeight.w500,
              color: selected ? AppColors.onAccent : (enabled ? AppColors.ink : AppColors.closedText),
              decoration: busy ? TextDecoration.lineThrough : null),
        ),
      ),
    );
  }

  Widget _doctorChip(Doctor d) {
    final selected = _doctorId == d.id;
    return Pressable(
      onTap: () => setState(() => _doctorId = d.id),
      selected: selected,
      semanticLabel: d.name,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 16, 6),
        decoration: BoxDecoration(color: selected ? AppColors.accent : AppColors.white, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DoctorAvatar(doctor: d, size: 36),
            const SizedBox(width: 10),
            Text(d.name, style: ts(15, weight: FontWeight.w500, color: selected ? AppColors.onAccent : AppColors.ink)),
          ],
        ),
      ),
    );
  }

  Widget _done() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 48, color: AppColors.onAccent),
              ),
            ),
            const SizedBox(height: 18),
            Text('انرسل الموعد للعميل', textAlign: TextAlign.center, style: ts(22, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${r.patient}\n${fmtAppointment(r.booking.at!)}', textAlign: TextAlign.center, style: ts(15, color: AppColors.body)),
            const SizedBox(height: 24),
            PillButton(label: 'تم', onTap: () => Navigator.of(context).pop()),
          ],
        ),
      );
}

// ───────── الإلغاء

const _cancelReasons = ['طلب المريض الإلغاء', 'الطبيب غير متاح', 'تعذر التواصل مع المريض', 'سبب آخر'];

class CancelSheet extends StatefulWidget {
  const CancelSheet({super.key, required this.request});

  final DeskRequest request;

  @override
  State<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<CancelSheet> {
  int? _reason;
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  String? get _text {
    final i = _reason;
    if (i == null) return null;
    if (i == _cancelReasons.length - 1) {
      final t = _other.text.trim();
      return t.isEmpty ? null : t;
    }
    return _cancelReasons[i];
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final reason = _text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(title: 'إلغاء الموعد'),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              DeskCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.patient, style: ts(17, weight: FontWeight.w600)),
                    Text(r.booking.title, style: ts(15)),
                    if (r.booking.at != null) Text(fmtAppointment(r.booking.at!), style: ts(14, color: AppColors.body)),
                  ],
                ),
              ),
              const SectionLabel('السبب'),
              for (var i = 0; i < _cancelReasons.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Pressable(
                    onTap: () => setState(() => _reason = i),
                    selected: _reason == i,
                    semanticLabel: _cancelReasons[i],
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22)),
                      child: Row(
                        children: [
                          SelectDot(selected: _reason == i),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_cancelReasons[i], style: ts(16))),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_reason == _cancelReasons.length - 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22)),
                  child: TextField(
                    controller: _other,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: ts(16),
                    decoration: InputDecoration(border: InputBorder.none, hintText: 'السبب', hintStyle: ts(16, color: AppColors.faint)),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SafeArea(
            top: false,
            child: PillButton(
              label: 'إلغاء الموعد',
              bg: AppColors.red,
              fg: AppColors.onRed,
              enabled: reason != null,
              onTap: () {
                DeskScope.read(context).cancel(r, reason!);
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ],
    );
  }
}
