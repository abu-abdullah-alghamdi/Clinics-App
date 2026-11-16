/// لوحة العيادة: موقع ويب يشتغل على الكمبيوتر والآيباد والجوال
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../clinic_config.dart';
import '../data.dart';
import '../extras.dart';
import '../main.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'appointments_page.dart';
import 'desk.dart';
import 'preview_panel.dart';
import 'reports_page.dart';
import 'requests_page.dart';
import 'schedule_sheet.dart';
import 'ui.dart';

/// متصفح صفحات اللوحة (النوافذ تنفتح فوقه، والقائمة والمعاينة برّاه)
final deskNav = GlobalKey<NavigatorState>();

class DashboardApp extends StatefulWidget {
  const DashboardApp({super.key, this.desk});

  /// للاختبارات (وإلا تنشأ وحدة جديدة)
  final DeskState? desk;

  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  late final DeskState _desk = widget.desk ?? DeskState();

  @override
  Widget build(BuildContext context) => AppScope(
        state: appState,
        child: DeskScope(
          desk: _desk,
          child: MaterialApp(
            navigatorKey: deskNav,
            title: 'لوحة ${ClinicConfig.current.appName}',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: appTheme(),
            builder: (context, child) => DeskFrame(navigator: child!),
            home: const _DeskHome(),
          ),
        ),
      );
}

/// صفحة اللوحة الحالية (داخل المتصفح عشان النوافذ تنفتح فوقها)
class _DeskHome extends StatelessWidget {
  const _DeskHome();

  @override
  Widget build(BuildContext context) {
    final desk = DeskScope.of(context);
    if (desk.staff == null) return const Scaffold(body: _LoginPage());
    return Scaffold(
      body: switch (desk.page) {
        DeskPage.requests => const RequestsPage(),
        DeskPage.appointments => const AppointmentsPage(),
        DeskPage.reports => const ReportsPage(),
        // المعاينة برّا المتصفح (عشان نوافذ التطبيق تنفتح داخل الجوال)
        DeskPage.preview => const SizedBox.shrink(),
      },
    );
  }
}

/// الإطار: القائمة على اليمين، الصفحة بالنص، والمعاينة على اليسار (في الشاشات العريضة)
class DeskFrame extends StatelessWidget {
  const DeskFrame({super.key, required this.navigator});

  final Widget navigator;

  static final _previewKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final desk = DeskScope.of(context);
    final staff = desk.staff;
    if (staff == null) return navigator;
    final size = deskSize(context);
    final docked = size == DeskSize.desktop;
    final previewPage = !docked && desk.page == DeskPage.preview;

    final content = Stack(
      children: [
        Positioned.fill(child: Visibility(visible: !previewPage, maintainState: true, child: navigator)),
        if (!docked)
          Positioned.fill(
            child: Visibility(
              visible: previewPage,
              maintainState: true,
              child: ColoredBox(
                color: AppColors.bg,
                child: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: AppPreview(key: _previewKey))),
              ),
            ),
          ),
        const Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: _ArrivalToast())),
      ],
    );

    if (size == DeskSize.phone) {
      return Material(
        color: AppColors.bg,
        child: Column(children: [Expanded(child: content), const _BottomBar()]),
      );
    }
    return Material(
      color: AppColors.bg,
      child: Row(
        children: [
          const _Sidebar(),
          Expanded(child: content),
          if (docked)
            Container(
              width: 420,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('معاينة التطبيق', style: ts(16, weight: FontWeight.w600, color: AppColors.body)),
                  ),
                  Expanded(child: AppPreview(key: _previewKey)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// عناصر القائمة حسب الصلاحية
List<({DeskPage page, String label, IconData icon, int count})> _items(DeskState desk, {required bool withPreview}) {
  final role = desk.staff!.role;
  final today = desk.appointmentsOn(appToday).where((r) => r.booking.status == RequestStatus.scheduled).length;
  return [
    if (role.canSchedule) (page: DeskPage.requests, label: 'الطلبات', icon: CupertinoIcons.tray_arrow_down, count: desk.waiting.length),
    (page: DeskPage.appointments, label: 'المواعيد', icon: CupertinoIcons.calendar, count: today),
    if (role.seesReports) (page: DeskPage.reports, label: 'التقارير', icon: CupertinoIcons.chart_bar, count: 0),
    if (withPreview) (page: DeskPage.preview, label: 'المعاينة', icon: CupertinoIcons.device_phone_portrait, count: 0),
  ];
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final desk = DeskScope.of(context);
    final staff = desk.staff!;
    final docked = deskSize(context) == DeskSize.desktop;
    final clinic = ClinicConfig.current;
    return Container(
      width: 250,
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
              child: Row(
                children: [
                  _Monogram(size: 44, letter: clinic.monogram),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clinic.appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, weight: FontWeight.w600)),
                        Text('لوحة العيادة', style: ts(13, color: AppColors.faint)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final item in _items(desk, withPreview: !docked))
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _NavTile(
                  label: item.label,
                  icon: item.icon,
                  count: item.count,
                  selected: desk.page == item.page,
                  onTap: () => desk.go(item.page),
                ),
              ),
            const Spacer(),
            Padding(padding: const EdgeInsets.all(12), child: _StaffCard(staff: staff)),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.label, required this.icon, required this.count, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onAccent : AppColors.ink;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: count > 0 ? '$label، ${fmtNum(count)}' : label,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: selected ? AppColors.accent : AppColors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: ts(16, weight: FontWeight.w500, color: fg))),
            if (count > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 26),
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: selected ? AppColors.onAccent : AppColors.bg, borderRadius: BorderRadius.circular(13)),
                child: Text(fmtNum(count), style: ts(13, weight: FontWeight.w600, color: selected ? AppColors.accent : AppColors.ink, height: 1)),
              ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.staff});

  final Staff staff;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PatientAvatar(name: staff.name.replaceFirst('د. ', ''), size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staff.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, weight: FontWeight.w600)),
                      Text('${staff.role.label}، ${staff.scope}', maxLines: 2, style: ts(12, color: AppColors.faint)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            PillButton(label: 'تبديل الحساب', height: 40, fontSize: 14, padding: 14, bg: AppColors.white, onTap: () => DeskScope.read(context).signOut()),
          ],
        ),
      );
}

/// شريط تحت في الجوال
class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    final desk = DeskScope.of(context);
    final items = _items(desk, withPreview: true);
    return Container(
      color: AppColors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: _BarItem(
                    label: item.label,
                    icon: item.icon,
                    // الشارة الحمراء للطلبات اللي تنتظر بس
                    count: item.page == DeskPage.requests ? item.count : 0,
                    selected: desk.page == item.page,
                    onTap: () => desk.go(item.page),
                  ),
                ),
              Expanded(
                child: _BarItem(
                  label: 'الحساب',
                  icon: CupertinoIcons.person_crop_circle,
                  count: 0,
                  selected: false,
                  onTap: () => showDeskSheet<void>(
                    deskNav.currentContext!,
                    (ctx) => Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SheetHeader(title: 'الحساب'),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _StaffCard(staff: DeskScope.read(ctx).staff!),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({required this.label, required this.icon, required this.count, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onAccent : AppColors.ink;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: count > 0 ? '$label، ${fmtNum(count)}' : label,
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: selected ? AppColors.accent : AppColors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: count > 0,
              label: Text(fmtNum(count)),
              backgroundColor: AppColors.red,
              textColor: AppColors.onRed,
              child: Icon(icon, size: 22, color: fg),
            ),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, style: ts(12, weight: FontWeight.w500, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.size, required this.letter});

  final double size;
  final String letter;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Text(letter, style: ts(size * 0.45, weight: FontWeight.w700, color: AppColors.onAccent)),
      );
}

/// تنبيه "طلب جديد" لما يوصل طلب من التطبيق
class _ArrivalToast extends StatefulWidget {
  const _ArrivalToast();

  @override
  State<_ArrivalToast> createState() => _ArrivalToastState();
}

class _ArrivalToastState extends State<_ArrivalToast> {
  ValueNotifier<DeskRequest?>? _source;
  DeskRequest? _request;
  bool _shown = false;
  Timer? _hide;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final source = DeskScope.read(context).arrival;
    if (source != _source) {
      _source?.removeListener(_onArrival);
      _source = source..addListener(_onArrival);
    }
  }

  void _onArrival() {
    final r = _source?.value;
    if (r == null || !mounted) return;
    _hide?.cancel();
    setState(() {
      _request = r;
      _shown = true;
    });
    _hide = Timer(const Duration(seconds: 10), _dismiss);
  }

  void _dismiss() {
    if (mounted) setState(() => _shown = false);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _source?.removeListener(_onArrival);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _request;
    if (r == null) return const SizedBox.shrink();
    final canSchedule = DeskScope.of(context).staff?.role.canSchedule ?? false;
    return IgnorePointer(
      ignoring: !_shown,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, -1.5),
        duration: motion(context, 320),
        curve: Curves.easeOutCubic,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.bell_fill, color: AppColors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('طلب جديد من ${r.patient}', style: ts(15, weight: FontWeight.w600, color: AppColors.white)),
                      Text('${r.booking.title}، ${r.booking.period.label}', style: ts(13, color: const Color(0xFFD0D0D4))),
                    ],
                  ),
                ),
                if (canSchedule && !r.booking.isPackage) ...[
                  const SizedBox(width: 10),
                  PillButton(
                    label: 'حدد الموعد',
                    height: 40,
                    fontSize: 14,
                    padding: 14,
                    bg: AppColors.white,
                    fg: AppColors.ink,
                    onTap: () {
                      _dismiss();
                      final nav = deskNav.currentContext;
                      if (nav != null) openSchedule(nav, r);
                    },
                  ),
                ],
                const SizedBox(width: 6),
                CircleButton(icon: Icons.close_rounded, size: 36, iconSize: 18, bg: const Color(0xFF2C2C2E), fg: AppColors.white, semanticLabel: 'إغلاق', onTap: _dismiss),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────── الدخول

class _LoginPage extends StatelessWidget {
  const _LoginPage();

  @override
  Widget build(BuildContext context) {
    final clinic = ClinicConfig.current;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: _Monogram(size: 76, letter: clinic.monogram)),
            const SizedBox(height: 16),
            Text(clinic.appName, textAlign: TextAlign.center, style: ts(30, weight: FontWeight.w600)),
            Text('لوحة العيادة', textAlign: TextAlign.center, style: ts(17, color: AppColors.body)),
            const SectionLabel('الدخول بحساب'),
            for (final s in demoStaff)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DeskCard(
                  onTap: () => DeskScope.read(context).signIn(s),
                  padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
                  child: Row(
                    children: [
                      PatientAvatar(name: s.name.replaceFirst('د. ', ''), size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: ts(16, weight: FontWeight.w600)),
                            Text('${s.role.label}، ${s.scope}', style: ts(13, color: AppColors.faint)),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_left, size: 18, color: AppColors.faint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
