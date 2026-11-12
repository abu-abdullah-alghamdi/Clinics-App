// هوية العيادة ونصوصها تجي من ملف إعداداتها، بدون تعديل الكود.
//
// يشتغل بطريقتين:
// 1. مع باقي الاختبارات (بملف demo أو بدون): يتأكد إن عيادتي تطلع بنفس النصوص بالضبط قبل الفصل.
// 2. بملف عيادة ثانية للاختبار (test/fixtures/clinic_test.json) — في GitHub:
//      flutter test test/clinic_identity_test.dart \
//        --dart-define-from-file=test/fixtures/clinic_test.json \
//        --dart-define=CLINIC_FIXTURE=test/fixtures/clinic_test.json
//    ويتأكد إن كل بيانات الهوية تغيّرت في التطبيق حسب الملف، وما بقى أي أثر لعيادتي.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clinics_app/clinic_config.dart';
import 'package:clinics_app/data.dart';
import 'package:clinics_app/main.dart';
import 'package:clinics_app/native.dart';
import 'package:clinics_app/screens/visit_extras.dart';
import 'package:clinics_app/services_data.dart';
import 'package:clinics_app/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ملف عيادة الاختبار (فاضي = الاختبار يشتغل على عيادتي)
const _fixture = String.fromEnvironment('CLINIC_FIXTURE');

/// خطوط التطبيق الحقيقية (عشان الصفحة تنرسم بمقاسها الصحيح)
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

void main() {
  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  final c = ClinicConfig.current;

  if (_fixture.isEmpty) {
    // ─── عيادتي: نفس النصوص بالضبط اللي كانت مكتوبة في الكود
    test('عيادتي: النصوص والروابط نفس ما كانت قبل الفصل', () {
      expect(c, ClinicConfig.demo);
      final d = doctorById('d1');
      expect(shareDoctorText(d), '${d.name} · ${d.role}\nاحجز موعدك من تطبيق عيادتي\nhttps://apps.apple.com/');
      final s = serviceById('s1');
      final offer = s.onOffer ? ' (خصم ${fmtNum(s.discount)}%)' : '';
      expect(shareServiceText(s), '${s.name}$offer · ${s.priceWords}\n${s.availabilityText}\nاحجزها من تطبيق عيادتي\nhttps://apps.apple.com/');
      expect(calendarEventNote, 'موعد في عيادتي');
      expect(forceUpdateMessage, 'هذي النسخة من عيادتي ما عاد تشتغل، حدّث التطبيق عشان تكمل حجوزاتك');
      expect(clinicCallUri.toString(), 'tel:+966000000000');
      expect(clinicWhatsappUri.toString(), 'https://wa.me/966000000000');
      expect(c.monogram, 'ع');
    });
  } else {
    // ─── عيادة ثانية من ملف إعداداتها
    final file = ClinicConfig.fromJson(json.decode(File(_fixture).readAsStringSync()) as Map<String, dynamic>);

    test('الإعدادات جت من ملف عيادة الاختبار، مو من عيادتي', () {
      expect(ClinicConfig.fromFile, isTrue);
      expect(c, file);
      expect(c, isNot(ClinicConfig.demo));
      expect(c.appName, isNot(ClinicConfig.demo.appName));
    });

    test('المشاركة والتقويم باسم العيادة ورابطها من الملف', () {
      final doctor = shareDoctorText(doctorById('d1'));
      final service = shareServiceText(serviceById('s1'));
      for (final text in [doctor, service]) {
        expect(text, contains(file.appName));
        expect(text, contains(file.shareLink));
        expect(text, isNot(contains(ClinicConfig.demo.appName)));
      }
      expect(calendarEventNote, 'موعد في ${file.appName}');
    });

    test('الاتصال وواتساب بأرقام العيادة من الملف', () {
      expect(clinicCallUri.toString(), 'tel:${file.phone}');
      expect(clinicWhatsappUri.toString(), 'https://wa.me/${file.whatsapp.substring(1)}');
      // واتساب ممكن يكون رقم غير رقم الاتصال
      expect(file.whatsapp, isNot(file.phone));
    });
  }

  // ─── على الشاشة: صفحة التحديث الإجباري واسم التطبيق (بالطريقتين)
  testWidgets('اسم العيادة على الشاشة من إعداداتها', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 59 * 2, bottom: 34 * 2);
    tester.view.viewPadding = const FakeViewPadding(top: 59 * 2, bottom: 34 * 2);
    addTearDown(tester.view.reset);
    RemoteConfig.updateRequired = true;
    addTearDown(() => RemoteConfig.updateRequired = false);

    await tester.pumpWidget(ClinicsApp(key: UniqueKey()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, c.appName);
    expect(find.text(forceUpdateMessage), findsOneWidget);
    // حرف الشعار بلون العيادة
    expect(find.text(c.monogram), findsOneWidget);
    expect(forceUpdateMessage, contains(c.appName));
    if (_fixture.isNotEmpty) expect(find.textContaining(ClinicConfig.demo.appName), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
