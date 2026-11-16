// صور مرجعية للوحة العيادة: الكمبيوتر والآيباد والجوال (بنفس التاريخ الثابت للصور المرجعية)
library;

import 'dart:convert';

import 'package:clinics_app/dashboard/dashboard_app.dart';
import 'package:clinics_app/dashboard/desk.dart';
import 'package:clinics_app/repo/mock_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= 0.005) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<void> _loadFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest) {
    final loader = FontLoader((entry as Map<String, dynamic>)['family'] as String);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load((font as Map<String, dynamic>)['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate().toList()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Staff _role(StaffRole r) => demoStaff.firstWhere((s) => s.role == r);

Future<void> _shot(
  WidgetTester tester,
  String name,
  Size size, {
  StaffRole? role = StaffRole.admin,
  DeskPage page = DeskPage.requests,
  Future<void> Function(WidgetTester tester, DeskState desk)? then,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final desk = DeskState();
  if (role != null) {
    desk.signIn(_role(role));
    desk.go(page);
  }
  await tester.pumpWidget(DashboardApp(key: UniqueKey(), desk: desk));
  await _settle(tester);
  if (then != null) {
    await then(tester, desk);
    await _settle(tester);
  }
  await expectLater(find.byType(DashboardApp), matchesGoldenFile('goldens/$name.png'));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 11));
}

Future<void> _openSchedule(WidgetTester tester, DeskState desk) async {
  await tester.tap(find.text('حدد الموعد').first);
  await _settle(tester);
}

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  const desktop = Size(1440, 900);
  const tablet = Size(1024, 768);
  const phone = Size(390, 844);

  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    MockBackend.latency = Duration.zero;
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
    goldenFileComparator = _TolerantComparator((goldenFileComparator as LocalFileComparator).basedir.resolve('dashboard_test.dart'));
  });

  testWidgets('اللوحة: الدخول', (t) => _shot(t, 'd01_login', desktop, role: null), variant: ios);
  testWidgets('اللوحة: الطلبات (كمبيوتر)', (t) => _shot(t, 'd02_requests_desktop', desktop), variant: ios);
  testWidgets('اللوحة: تحديد الموعد (كمبيوتر)', (t) => _shot(t, 'd03_schedule_desktop', desktop, then: _openSchedule), variant: ios);
  testWidgets('اللوحة: المواعيد (كمبيوتر)', (t) => _shot(t, 'd04_appointments_desktop', desktop, page: DeskPage.appointments), variant: ios);
  testWidgets('اللوحة: التقارير (كمبيوتر)', (t) => _shot(t, 'd05_reports_desktop', desktop, page: DeskPage.reports), variant: ios);
  testWidgets('اللوحة: الطلبات (آيباد)', (t) => _shot(t, 'd06_requests_tablet', tablet), variant: ios);
  testWidgets('اللوحة: المعاينة (آيباد)', (t) => _shot(t, 'd07_preview_tablet', tablet, page: DeskPage.preview), variant: ios);
  testWidgets('اللوحة: الطلبات (جوال)', (t) => _shot(t, 'd08_requests_phone', phone), variant: ios);
  testWidgets('اللوحة: تحديد الموعد (جوال)', (t) => _shot(t, 'd09_schedule_phone', phone, then: _openSchedule), variant: ios);
  testWidgets('اللوحة: المواعيد (جوال)', (t) => _shot(t, 'd10_appointments_phone', phone, page: DeskPage.appointments), variant: ios);
  testWidgets('اللوحة: الاستقبال', (t) => _shot(t, 'd11_reception_desktop', desktop, role: StaffRole.reception), variant: ios);
  testWidgets('اللوحة: معاينة التطبيق (كمبيوتر)', (t) => _shot(t, 'd12_preview_desktop', desktop, page: DeskPage.preview), variant: ios);
  testWidgets('اللوحة: الدخول (جوال)', (t) => _shot(t, 'd13_login_phone', phone, role: null), variant: ios);
}
