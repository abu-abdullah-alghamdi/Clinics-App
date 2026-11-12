// صور مرجعية لشاشات التطبيق الحالية (عيادة demo).
//
// الهدف: نتأكد إن أي تعديل في البنية (فصل الهوية، دعم أكثر من عيادة) ما يغيّر
// التصميم أو تجربة الاستخدام بدون قصد.
//
// تشتغل على GitHub بتاريخ ثابت (الأحد 8 نوفمبر 2026) عشان التواريخ في الشاشات ما تتغير يومياً.
// المقارنة تسمح بفرق بسيط جداً (أقل من 0.5% من البكسلات) عشان اختلاف الجهاز أو النظام
// ما يوقف العمل، وأي تغيير حقيقي في التصميم يوقفه ويطلع صورة الفرق.
//
// ملاحظة: أزرار آبل الزجاجية وشريط التبويبات الأصلي (iOS 26) ما تنرسم في الاختبار،
// فتطلع بدلها النسخة البديلة المرسومة في فلاتر. المقارنة تغطي كل اللي نرسمه نحن.
library;

import 'dart:convert';

import 'package:clinics_app/data.dart';
import 'package:clinics_app/main.dart';
import 'package:clinics_app/screens/clinic_demo_screen.dart';
import 'package:clinics_app/screens/otp_screen.dart';
import 'package:clinics_app/screens/payment_screen.dart';
import 'package:clinics_app/screens/phone_screen.dart';
import 'package:clinics_app/screens/profile_screen.dart';
import 'package:clinics_app/screens/request_screen.dart';
import 'package:clinics_app/screens/service_screen.dart';
import 'package:clinics_app/services_data.dart';
import 'package:clinics_app/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نسبة البكسلات المسموح تختلف (0.5%)
const _tolerance = 0.005;

/// مقارنة تتحمل الفروق البسيطة جداً
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= _tolerance) {
      if (!result.passed) {
        debugPrint('golden ${golden.pathSegments.last}: فرق بسيط ${(result.diffPercent * 100).toStringAsFixed(3)}% (مقبول)');
      }
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

/// يحمّل خطوط التطبيق (IBM Plex، رمز الريال، الأيقونات) بدل الخط المربعات الافتراضي في الاختبار
Future<void> _loadFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load((font as Map<String, dynamic>)['asset'] as String));
    }
    await loader.load();
  }
}

/// مقاس iPhone 15 Pro (393 × 852) مع منطقة الساعة وأسفل الشاشة
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 2, 852 * 2);
  tester.view.devicePixelRatio = 2;
  tester.view.padding = const FakeViewPadding(top: 59 * 2, bottom: 34 * 2);
  tester.view.viewPadding = const FakeViewPadding(top: 59 * 2, bottom: 34 * 2);
  addTearDown(tester.view.reset);
}

/// يحمّل الصور الظاهرة فعلياً (في الاختبار ما تتحمل لحالها)
Future<void> _precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate().toList()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
}

/// ينتظر الحركات والانتقالات تخلص والصور تتحمل
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _precache(tester);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// يفتح التطبيق، يجهّز الحالة، ويفتح الصفحة المطلوبة (لو فيه)، ويقارنها بالصورة المرجعية
Future<void> _shot(
  WidgetTester tester,
  String name, {
  int tab = 0,
  bool onboarding = false,
  Route<void> Function()? open,
  Future<void> Function(WidgetTester tester)? then,
}) async {
  _phone(tester);
  appState.setTab(tab);
  await tester.pumpWidget(ClinicsApp(key: UniqueKey(), showOnboarding: onboarding));
  await _settle(tester);
  if (open != null) {
    tester.state<NavigatorState>(find.byType(Navigator).first).push(open());
    await _settle(tester);
  }
  if (then != null) {
    await then(tester);
    await _settle(tester);
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  // نقفل التطبيق عشان المؤقتات (مثل البنر المتحرك) تتوقف
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// موعد حددته العيادة بكرة 5:30 م (لصفحة الدفع)
Booking _scheduled(String serviceId, String doctorId) {
  final d = DayInfo(1).date;
  return Booking(
    id: 'g-$serviceId',
    number: '2499',
    serviceId: serviceId,
    branchId: 'rawdah',
    doctorId: doctorId,
    status: RequestStatus.scheduled,
    at: DateTime(d.year, d.month, d.day, 17, 30),
  );
}

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
    goldenFileComparator = _TolerantComparator((goldenFileComparator as LocalFileComparator).basedir.resolve('screens_test.dart'));
  });

  test('التاريخ ثابت (الأحد 8 نوفمبر 2026)', () {
    // لو فشل: الصور المرجعية تنولد وتنقارن بتاريخ مختلف، والتواريخ في الشاشات بتختلف
    expect([appToday.year, appToday.month, appToday.day], [2026, 11, 8]);
    // الساعة مثبتة على 12 الظهر وقت التشغيل (يتأكد إن التثبيت شغال فعلاً)
    expect(DateTime.now().difference(DateTime(2026, 11, 8, 12)).inMinutes.abs(), lessThan(60));
  });

  // ─── التبويبات
  testWidgets('الرئيسية', (t) => _shot(t, '01_home', tab: 0), variant: ios);
  testWidgets('مواعيدي', (t) => _shot(t, '02_appointments', tab: 1), variant: ios);
  testWidgets('الأطباء', (t) => _shot(t, '03_doctors', tab: 2), variant: ios);
  testWidgets('الخدمات', (t) => _shot(t, '04_services', tab: 4), variant: ios);
  testWidgets('حسابي (زائر)', (t) => _shot(t, '05_account_guest', tab: 3), variant: ios);

  // ─── الصفحات
  testWidgets('صفحة الخدمة', (t) => _shot(t, '06_service', open: () => iosRoute(ServiceScreen(service: serviceById('s1')))), variant: ios);
  testWidgets('صفحة خدمة فيها باقات وتقسيط',
      (t) => _shot(t, '07_service_packages', open: () => iosRoute(ServiceScreen(service: serviceById('s7')))), variant: ios);
  testWidgets('طلب موعد مع طبيب', (t) => _shot(t, '08_doctor_request', open: () => iosModal(RequestScreen(doctor: doctorById('d2')))), variant: ios);
  testWidgets('طلب خدمة', (t) => _shot(t, '09_service_request', open: () => iosModal(RequestScreen(service: serviceById('s1')))), variant: ios);
  testWidgets('تم إرسال الطلب', (t) {
    final b = Booking(id: 'g-sent', number: '2498', serviceId: 's1', branchId: 'salamah', period: Period.morning);
    return _shot(t, '10_request_sent', open: () => iosRoute(RequestSentScreen(request: b)));
  }, variant: ios);
  testWidgets('الدفع', (t) => _shot(t, '11_payment', open: () => iosRoute(PaymentScreen(request: _scheduled('s2', 'd1')))), variant: ios);
  testWidgets('لوحة العيادة', (t) => _shot(t, '12_clinic_demo', open: () => iosRoute(const ClinicDemoScreen())), variant: ios);
  testWidgets('رقم الجوال', (t) => _shot(t, '13_phone', open: () => iosRoute(const PhoneScreen(inside: true))), variant: ios);
  testWidgets('رمز التحقق', (t) => _shot(t, '17_otp', open: () => iosRoute(const OtpScreen(national: '551234567', inside: true))), variant: ios);
  testWidgets('رمز التحقق غير صحيح', (t) {
    return _shot(t, '18_otp_wrong',
        open: () => iosRoute(const OtpScreen(national: '551234567', inside: true)),
        then: (t) => t.enterText(find.byType(TextField), '1234'));
  }, variant: ios);
  testWidgets('اسمك (عميل جديد)', (t) {
    return _shot(t, '19_name',
        open: () => iosRoute(const ProfileScreen(phone: '0551234567', inside: true)),
        then: (t) => t.enterText(find.byType(TextField), 'أنس الغامدي'));
  }, variant: ios);
  testWidgets('معلوماتي الشخصية', (t) {
    return _shot(t, '20_profile_edit',
        open: () => iosRoute(const ProfileScreen(phone: '0551234567', initial: Profile(name: 'أنس الغامدي', phone: '0551234567'))));
  }, variant: ios);
  testWidgets('الصفحات التعريفية', (t) => _shot(t, '14_onboarding', onboarding: true), variant: ios);

  // ─── بعد تسجيل الدخول (آخر شي عشان باقي الشاشات تبقى بحالة الزائر)
  testWidgets('حسابي (مسجّل)', (t) async {
    appState.saveProfile(const Profile(name: 'أنس الغامدي', phone: '0551234567'));
    await _shot(t, '15_account_logged_in', tab: 3);
  }, variant: ios);
  testWidgets('الدفع بعد التسجيل (بدون ضريبة)', (t) {
    return _shot(t, '16_payment_logged_in',
        open: () => iosRoute(PaymentScreen(request: _scheduled('s1', 'd1'))));
  }, variant: ios);
}
