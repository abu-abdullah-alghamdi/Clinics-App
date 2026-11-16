/// التقارير: الأرقام اللي تهم أي عيادة
library;

import 'package:flutter/material.dart';

import '../data.dart';
import '../extras.dart';
import '../services_data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'desk.dart';
import 'ui.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const _ranges = [7, 30];
  int _range = 1;

  @override
  Widget build(BuildContext context) {
    final desk = DeskScope.of(context);
    final days = _ranges[_range];
    final items = desk.since(days);
    final m = _Metrics(items, desk.waiting);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 16, 16, 40),
      children: [
        const PageHeader(title: 'التقارير'),
        const BranchFilter(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 360,
            child: SegmentedPill(
              options: const ['آخر 7 أيام', 'آخر 30 يوم'],
              selected: _range,
              onChanged: (i) => setState(() => _range = i),
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 3 : 2;
          final w = (c.maxWidth - 12 * (cols - 1)) / cols;
          final tiles = [
            _Kpi('الطلبات', fmtNum(items.length), 'طلب جديد'),
            _Kpi('سرعة الرد', m.avgResponse == null ? '-' : fmtRemaining(m.avgResponse!), 'من وصول الطلب لتحديد الموعد'),
            _Kpi('تحوّل لموعد', '${fmtNum(m.conversion)}%', 'من الطلبات اللي انرد عليها'),
            _Kpi('الغياب', '${fmtNum(m.noShowRate)}%', 'من المواعيد اللي جا وقتها'),
            _Kpi('الإيرادات', money(m.revenue), 'المدفوع من التطبيق والفرع'),
            _Kpi('بانتظار الموعد', fmtNum(desk.waiting.length), m.oldestWait == null ? 'ما فيه طلبات' : 'أقدمها ${ago(m.oldestWait!)}'),
          ];
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
        }),
        const SectionLabel('الطلبات اليومية'),
        DeskCard(child: _DailyBars(items: items, days: days)),
        LayoutBuilder(builder: (context, c) {
          final two = c.maxWidth >= 900;
          final cards = [
            _Breakdown(title: 'أكثر الخدمات طلباً', rows: m.topServices),
            _Breakdown(title: 'الفترة المفضلة', rows: m.periods),
            if (desk.staff!.role.allBranches && desk.branchFilter == null) _Breakdown(title: 'الفروع', rows: m.branches),
            _Breakdown(title: 'زيارات الأطباء المكتملة', rows: m.doctors),
          ];
          if (!two) return Column(children: cards);
          return Wrap(
            spacing: 12,
            children: [for (final x in cards) SizedBox(width: (c.maxWidth - 12) / 2, child: x)],
          );
        }),
      ],
    );
  }
}

class _Metrics {
  _Metrics(this.items, List<DeskRequest> waiting) : oldestWait = waiting.isEmpty ? null : waiting.first.booking.createdAt;

  final List<DeskRequest> items;
  final DateTime? oldestWait;

  Iterable<RequestStatus> get _st => items.map((r) => r.booking.status);

  Duration? get avgResponse {
    final d = [for (final r in items) if (r.scheduledAt != null) r.scheduledAt!.difference(r.booking.createdAt).inMinutes];
    if (d.isEmpty) return null;
    return Duration(minutes: (d.reduce((a, b) => a + b) / d.length).round());
  }

  int get conversion {
    final answered = _st.where((s) => s != RequestStatus.sent).length;
    if (answered == 0) return 0;
    final ok = _st.where((s) => s != RequestStatus.sent && s != RequestStatus.cancelled).length;
    return (ok * 100 / answered).round();
  }

  int get noShowRate {
    final done = _st.where((s) => s == RequestStatus.completed || s == RequestStatus.noShow).length;
    if (done == 0) return 0;
    return (_st.where((s) => s == RequestStatus.noShow).length * 100 / done).round();
  }

  int get revenue => items
      .where((r) => r.booking.paid && r.booking.status != RequestStatus.cancelled)
      .fold(0, (sum, r) => sum + r.booking.price);

  List<(String, int)> _count(String Function(DeskRequest r) key, {Iterable<DeskRequest>? from, int? take}) {
    final map = <String, int>{};
    for (final r in from ?? items) {
      final k = key(r);
      map[k] = (map[k] ?? 0) + 1;
    }
    final list = map.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return take == null ? list : list.take(take).toList();
  }

  List<(String, int)> get topServices => _count((r) => r.booking.service.name, take: 5);
  List<(String, int)> get periods => _count((r) => r.booking.period.label);
  List<(String, int)> get branches => _count((r) => r.booking.branch.name);
  List<(String, int)> get doctors =>
      _count((r) => r.booking.doctor?.name ?? '', from: items.where((r) => r.booking.status == RequestStatus.completed));
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.title, this.value, this.hint);

  final String title;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) => DeskCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ts(15, color: AppColors.body)),
            const SizedBox(height: 6),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(28, weight: FontWeight.w600, height: 1.2)),
            const SizedBox(height: 4),
            Text(hint, style: ts(13, color: AppColors.faint)),
          ],
        ),
      );
}

/// عمود لكل يوم
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.items, required this.days});

  final List<DeskRequest> items;
  final int days;

  @override
  Widget build(BuildContext context) {
    final dates = [for (var i = days - 1; i >= 0; i--) appToday.subtract(Duration(days: i))];
    final counts = [for (final d in dates) items.where((r) => sameDay(r.booking.createdAt, d)).length];
    final max = counts.fold(1, (a, b) => b > a ? b : a);
    final every = days <= 7 ? 1 : 5;
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < dates.length; i++)
            Expanded(
              child: Semantics(
                label: '${fmtDay(dates[i])}: ${fmtNum(counts[i])} طلب',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: days <= 7 ? 8 : 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (days <= 7) Text(fmtNum(counts[i]), style: ts(13, weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Container(
                        height: 4 + 130 * counts[i] / max,
                        decoration: BoxDecoration(
                          color: counts[i] == 0 ? AppColors.disabled : chartColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 18,
                        child: (dates.length - 1 - i) % every == 0
                            ? Text(fmtNum(dates[i].day), style: ts(12, color: AppColors.faint))
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// أعمدة أفقية: الاسم والعدد
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.rows});

  final String title;
  final List<(String, int)> rows;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold(1, (a, r) => r.$2 > a ? r.$2 : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        DeskCard(
          child: rows.isEmpty
              ? Text('ما فيه بيانات في هذي الفترة', style: ts(15, color: AppColors.faint))
              : Column(
                  children: [
                    for (final (name, n) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(width: 130, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14))),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: FractionallySizedBox(
                                  widthFactor: (n / max).clamp(0.04, 1.0),
                                  child: Container(
                                    height: 14,
                                    decoration: BoxDecoration(color: chartColor, borderRadius: BorderRadius.circular(7)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(width: 32, child: Text(fmtNum(n), textAlign: TextAlign.end, style: ts(14, weight: FontWeight.w600))),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
