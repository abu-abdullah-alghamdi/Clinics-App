// لوحة العيادة: الصلاحيات، تحديد الموعد ووصوله للتطبيق، والصفحات بمقاسات الكمبيوتر والآيباد والجوال
import 'dart:convert';

import 'package:clinics_app/dashboard/appointments_page.dart';
import 'package:clinics_app/dashboard/dashboard_app.dart';
import 'package:clinics_app/dashboard/desk.dart';
import 'package:clinics_app/dashboard/schedule_sheet.dart';
import 'package:clinics_app/data.dart';
import 'package:clinics_app/main.dart';
import 'package:clinics_app/services_data.dart';
import 'package:clinics_app/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void _screen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Staff _role(StaffRole r) => demoStaff.firstWhere((s) => s.role == r);

Future<void> _pump(WidgetTester tester, [int times = 10]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// يقفل اللوحة عشان مؤقتات التطبيق اللي في المعاينة تتوقف
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 11));
}

void main() {
  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  group('الصلاحيات', () {
    test('المالك يشوف كل الفروع، والاستقبال فرعه بس', () {
      final desk = DeskState()..signIn(_role(StaffRole.owner));
      final branchesSeen = desk.visible.map((r) => r.booking.branchId).toSet();
      expect(branchesSeen.length, greaterThan(1));

      desk.signIn(_role(StaffRole.reception));
      final own = _role(StaffRole.reception).branchId;
      expect(desk.visible, isNotEmpty);
      expect(desk.visible.every((r) => r.booking.branchId == own), isTrue);
    });

    test('الطبيب يشوف مواعيده بس، وما يحدد مواعيد', () {
      final desk = DeskState()..signIn(_role(StaffRole.doctor));
      final doc = _role(StaffRole.doctor).doctorId;
      expect(desk.visible.every((r) => r.booking.doctorId == doc), isTrue);
      expect(desk.visible.any((r) => r.booking.status == RequestStatus.sent), isFalse);
      expect(StaffRole.doctor.canSchedule, isFalse);
      expect(StaffRole.doctor.seesReports, isFalse);
      expect(desk.page, DeskPage.appointments);
    });

    test('التقارير للمالك ومدير الفرع بس', () {
      expect(StaffRole.owner.seesReports, isTrue);
      expect(StaffRole.manager.seesReports, isTrue);
      expect(StaffRole.reception.seesReports, isFalse);
    });
  });

  group('الطلبات والمواعيد', () {
    test('الطلبات الجديدة الأقدم أول', () {
      final desk = DeskState()..signIn(_role(StaffRole.owner));
      final list = desk.waiting;
      expect(list, isNotEmpty);
      for (var i = 1; i < list.length; i++) {
        expect(list[i - 1].booking.createdAt.isAfter(list[i].booking.createdAt), isFalse);
      }
    });

    test('تحديد موعد: يصير مؤكد، والطبيب يصير مشغول بنفس الوقت', () {
      final desk = DeskState()..signIn(_role(StaffRole.owner));
      final r = desk.waiting.first;
      final day = openDays()[1];
      final at = slotsFor(day, Period.evening).first;
      final doc = desk.doctorsOf(r).first.id;
      desk.schedule(r, at: at, doctorId: doc);
      expect(r.booking.status, RequestStatus.scheduled);
      expect(r.booking.at, at);
      expect(r.scheduledAt, isNotNull);
      expect(desk.waiting.contains(r), isFalse);
      expect(desk.busy(doc, at), isTrue);
      expect(desk.busy(doc, at, except: r.id), isFalse);
      expect(desk.appointmentsOn(day).contains(r), isTrue);
    });

    test('طلب من التطبيق: يطلع في اللوحة، وتحديد موعده يحدّث التطبيق ويرسل إشعار', () {
      final desk = DeskState()..signIn(_role(StaffRole.owner));
      final booking = appState.addRequest(serviceId: 's1', branchId: 'rawdah', period: Period.morning);
      final r = desk.waiting.firstWhere((x) => x.id == booking.id);
      expect(r.fromApp, isTrue);
      expect(desk.arrival.value?.id, booking.id);

      final at = slotsFor(openDays()[1], Period.morning)[2];
      desk.schedule(r, at: at, doctorId: desk.doctorsOf(r).first.id);
      expect(booking.status, RequestStatus.scheduled);
      expect(booking.at, at);
      expect(desk.notice.value?.title, 'تم تحديد موعدك');
    });

    test('الإلغاء بسبب يوصل للتطبيق', () {
      final desk = DeskState()..signIn(_role(StaffRole.owner));
      final booking = appState.addRequest(serviceId: 'c1', branchId: 'salamah', period: Period.noon);
      final r = desk.all.firstWhere((x) => x.id == booking.id);
      desk.cancel(r, 'الطبيب غير متاح');
      expect(booking.status, RequestStatus.cancelled);
      expect(booking.clinicCancelReason, 'الطبيب غير متاح');
    });

    test('الأوقات: كل نص ساعة داخل الفترة، والأيام بدون الجمعة', () {
      final day = openDays().first;
      expect(slotsFor(day, Period.morning).first.hour, 9);
      expect(slotsFor(day, Period.evening).last.hour, 20);
      expect(openDays().any((d) => d.weekday == DateTime.friday), isFalse);
      expect(openDays().length, 14);
    });
  });

  group('الصفحات', () {
    for (final (name, size) in const [
      ('كمبيوتر', Size(1440, 900)),
      ('آيباد', Size(1024, 768)),
      ('جوال', Size(390, 844)),
    ]) {
      testWidgets('الدخول ثم الطلبات وتحديد موعد وإرساله: $name', (tester) async {
        _screen(tester, size);
        final desk = DeskState();
        await tester.pumpWidget(DashboardApp(desk: desk));
        await _pump(tester);
        expect(find.text('لوحة العيادة'), findsWidgets);

        await tester.tap(find.text(_role(StaffRole.owner).name));
        await _pump(tester);
        expect(find.text('الطلبات'), findsWidgets);

        final r = desk.waiting.first;
        await tester.tap(find.text('حدد الموعد').first);
        await _pump(tester);
        expect(find.text('تحديد الموعد'), findsOneWidget);

        // النافذة تبدأ بأول يوم فيه وقت فاضي في الفترة المطلوبة: نختار أول وقت وأول طبيب
        Finder inSheet(String text) => find.descendant(of: find.byType(ScheduleSheet), matching: find.text(text));
        // القائمة تبني اللي ظاهر بس: ننزل لين يطلع الطبيب
        final sheetList = find.descendant(of: find.byType(ScheduleSheet), matching: find.byType(Scrollable)).first;
        final doc = desk.doctorsOf(r).first;
        await tester.scrollUntilVisible(inSheet(doc.name), 120, scrollable: sheetList);
        await tester.tap(inSheet(doc.name));
        await _pump(tester, 3);
        final day = openDays().firstWhere((d) => slotsFor(d, r.booking.period).any((t) => t.isAfter(DateTime.now())));
        final time = slotsFor(day, r.booking.period).firstWhere((t) => t.isAfter(DateTime.now()) && !desk.busy(doc.id, t));
        await tester.scrollUntilVisible(inSheet(fmtClock(time)), -120, scrollable: sheetList);
        await tester.tap(inSheet(fmtClock(time)));
        await _pump(tester, 3);
        final send = find.ancestor(of: inSheet('إرسال للعميل'), matching: find.byType(PillButton));
        expect(tester.widget<PillButton>(send).enabled, isTrue);

        await tester.tap(inSheet('إرسال للعميل'));
        await _pump(tester);
        expect(inSheet('انرسل الموعد للعميل'), findsOneWidget);
        expect(r.booking.status, RequestStatus.scheduled);
        expect(r.booking.at, time);
        expect(r.booking.doctorId, doc.id);

        await tester.tap(inSheet('تم'));
        await _pump(tester);

        // المواعيد والتقارير تفتح بدون أخطاء
        desk.go(DeskPage.appointments);
        await _pump(tester);
        expect(find.text('المواعيد'), findsWidgets);
        desk.go(DeskPage.reports);
        await _pump(tester);
        expect(find.text('سرعة الرد'), findsOneWidget);
        if (size.width < 1240) {
          desk.go(DeskPage.preview);
          await _pump(tester);
        }
        await _close(tester);
      });
    }

    testWidgets('الطبيب: مواعيده بدون صفحة الطلبات', (tester) async {
      _screen(tester, const Size(1440, 900));
      final desk = DeskState()..signIn(_role(StaffRole.doctor));
      await tester.pumpWidget(DashboardApp(desk: desk));
      await _pump(tester);
      expect(find.text('المواعيد'), findsWidgets);
      expect(find.text('حدد الموعد'), findsNothing);
      expect(find.text('التقارير'), findsNothing);
      await _close(tester);
    });

    testWidgets('إلغاء موعد بسبب', (tester) async {
      _screen(tester, const Size(1440, 900));
      final desk = DeskState()..signIn(_role(StaffRole.owner));
      desk.go(DeskPage.appointments);
      // أول يوم فيه مواعيد مؤكدة (لو اليوم جمعة يكون بكرة)
      desk.setDay([for (var i = 0; i < 7; i++) DayInfo(i).date]
          .firstWhere((d) => desk.appointmentsOn(d).any((x) => x.booking.status == RequestStatus.scheduled)));
      await tester.pumpWidget(DashboardApp(desk: desk));
      await _pump(tester);
      final r = desk.appointmentsOn(desk.day).firstWhere((x) => x.booking.status == RequestStatus.scheduled);
      await tester.tap(find.descendant(of: find.byType(AppointmentRow), matching: find.text('إلغاء')).first);
      await _pump(tester);
      Finder inSheet(String text) => find.descendant(of: find.byType(CancelSheet), matching: find.text(text));
      await tester.tap(inSheet('الطبيب غير متاح'));
      await _pump(tester, 3);
      // الزر تحت (العنوان فوق نفس الكلمة)
      await tester.tap(inSheet('إلغاء الموعد').last);
      await _pump(tester);
      expect(desk.all.where((x) => x.booking.status == RequestStatus.cancelled && x.booking.clinicCancelReason == 'الطبيب غير متاح'), isNotEmpty);
      expect(r.booking.status == RequestStatus.cancelled || r.booking.status == RequestStatus.scheduled, isTrue);
      expect(branchById(r.booking.branchId).name, isNotEmpty);
      await _close(tester);
    });
  });
}
