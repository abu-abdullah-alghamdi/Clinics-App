import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../services_data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'request_screen.dart';
import 'service_screen.dart';

/// البحث من الرئيسية: الخدمات والأطباء مع بعض
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// يتجاهل "ال" والهمزات عشان "الليزر" تلقى "ليزر" و"أسنان" تلقى "اسنان"
  String _norm(String t) => normalizeDigits(t)
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll('.', '')
      .split(' ')
      .map((w) => w.startsWith('ال') && w.length > 3 ? w.substring(2) : w)
      .join(' ')
      .trim();

  bool _match(String text, String q) => _norm(text).contains(_norm(q));

  void _remember() => AppScope.read(context).addRecentSearch(_ctrl.text);

  void _search(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    setState(() {});
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
        child: Semantics(header: true, child: Text(text, style: ts(20, weight: FontWeight.w500))),
      );

  Widget _list(List<Widget> rows) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(30)),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                decoration: BoxDecoration(
                  border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.bg)),
                ),
                child: rows[i],
              ),
          ],
        ),
      );

  Widget _row({required Widget lead, required String title, required String sub, Widget? trail, required VoidCallback onTap}) => Pressable(
        onTap: () {
          _remember();
          onTap();
        },
        semanticLabel: '$title، $sub',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              lead,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ts(16, weight: FontWeight.w500)),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, color: AppColors.faint)),
                  ],
                ),
              ),
              trail ?? const Icon(CupertinoIcons.back, size: 18, color: AppColors.faint),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final q = _ctrl.text.trim();
    final svc = q.isEmpty
        ? const <Service>[]
        : services.where((x) => _match(x.name, q) || _match(categories[x.cat] ?? '', q)).toList();
    final docs = q.isEmpty
        ? const <Doctor>[]
        : doctors.where((d) => _match(d.name, q) || _match(d.role, q) || d.cats.any((c) => _match(categories[c] ?? '', q))).toList();
    final nav = Navigator.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      style: ts(17),
                      decoration: pillInput('خدمة، طبيب، أو تخصص').copyWith(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        prefixIcon: const Icon(CupertinoIcons.search, color: AppColors.ink),
                        suffixIcon: q.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح',
                                icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.faint),
                                onPressed: () => _search(''),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _remember(),
                    ),
                  ),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => nav.pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Text('إلغاء', style: ts(16, weight: FontWeight.w500)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (q.isEmpty) ...[
                    if (s.recentSearches.isNotEmpty) ...[
                      _header('بحثت قبل'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final r in s.recentSearches)
                            Pressable(
                              onTap: () => _search(r),
                              semanticLabel: r,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(999)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(CupertinoIcons.clock, size: 15, color: AppColors.faint),
                                    const SizedBox(width: 6),
                                    Text(r, style: ts(15)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    _header('التخصصات'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in categories.values) FilterPill(label: c, selected: false, onTap: () => _search(c)),
                      ],
                    ),
                  ] else if (svc.isEmpty && docs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          const Icon(CupertinoIcons.search, size: 40, color: AppColors.faint),
                          const SizedBox(height: 12),
                          Text('ما لقينا شي باسم "$q"', textAlign: TextAlign.center, style: ts(18)),
                        ],
                      ),
                    )
                  else ...[
                    if (svc.isNotEmpty) ...[
                      _header('الخدمات'),
                      _list([
                        for (final x in svc)
                          _row(
                            lead: ServiceImage(service: x, size: 48),
                            title: x.name,
                            sub: '★ ${x.ratingText}، ${x.availabilityText}',
                            trail: Text(priceLabel(x), style: ts(15, weight: FontWeight.w600)),
                            onTap: () => openService(context, x),
                          ),
                      ]),
                    ],
                    if (docs.isNotEmpty) ...[
                      _header('الأطباء'),
                      _list([
                        for (final d in docs)
                          _row(
                            lead: DoctorAvatar(doctor: d, size: 48),
                            title: d.name,
                            sub: d.role,
                            onTap: () => openRequest(context, doctor: d),
                          ),
                      ]),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
