// إعدادات العيادة (ClinicConfig) وملفات clinics/
library;

import 'dart:convert';
import 'dart:io';

import 'package:clinics_app/clinic_config.dart';
import 'package:clinics_app/main.dart';
import 'package:clinics_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// كلمات تدل على أسرار (مفاتيح دفع، كلمات مرور، توكنات)
const _secretHints = ['secret', 'password', 'passwd', 'token', 'private', 'api_key', 'apikey', 'sk_live', 'sk_test', '-----begin'];

Map<String, dynamic> _read(String path) => json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  setUpAll(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  test('demo بنفس القيم اللي كانت في التطبيق قبل الفصل', () {
    const demo = ClinicConfig.demo;
    expect(demo.id, 'demo');
    expect(demo.appName, 'Clinics App');
    expect(demo.nameEn, 'Clinics App');
    expect(demo.phone, '+966000000000');
    expect(demo.whatsapp, '+966000000000');
    expect(demo.shareLink, 'https://apps.apple.com/');
    expect(demo.storeUrl, 'https://apps.apple.com/');
    expect(demo.callUri.toString(), 'tel:+966000000000');
    expect(demo.whatsappUri.toString(), 'https://wa.me/966000000000');
    expect(demo.monogram, 'ع');
    expect(demo.accent, const Color(0xFFE3FF3A));
    expect(demo.onAccent, const Color(0xFF000000));
    // معرّفات التطبيق المثبت على الجوال (ما تتغير)
    expect(demo.iosBundleId, 'com.clinicsapp.clinicsApp');
    expect(demo.androidAppId, 'com.clinicsapp.clinics_app');
    expect(demo.splashColor, const Color(0xFFFFFFFF));
  });

  test('المعرّفات بالصيغة الصحيحة بس', () {
    Map<String, dynamic> withValue(String key, String value) => _read('clinics/demo/config.json')..[key] = value;
    expect(() => ClinicConfig.fromJson(withValue('CLINIC_ID', 'Noor')), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.fromJson(withValue('CLINIC_IOS_BUNDLE_ID', 'noor')), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.fromJson(withValue('CLINIC_ANDROID_APP_ID', 'com.clinicsapp.noor-app')), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.fromJson(withValue('CLINIC_SPLASH_COLOR', '#FFFFFF')), throwsA(isA<ClinicConfigError>()));
  });

  test('ألوان الواجهة نفس ألوان العيادة اللي انبنى لها التطبيق', () {
    expect(AppColors.accent, ClinicConfig.current.accent);
    expect(AppColors.onAccent, ClinicConfig.current.onAccent);
  });

  test('ملف clinics/demo/config.json يطابق demo', () {
    expect(ClinicConfig.fromJson(_read('clinics/demo/config.json')), ClinicConfig.demo);
  });

  test('التطبيق شغال بإعدادات demo (بملف أو بدون)', () {
    expect(ClinicConfig.current, ClinicConfig.demo);
    // في GitHub الاختبارات تشتغل بالملف: نتأكد إنه وصل فعلاً
    const expectFile = bool.fromEnvironment('EXPECT_CLINIC_FILE');
    if (expectFile) expect(ClinicConfig.fromFile, isTrue, reason: 'الاختبارات انطلقت بدون ملف العيادة');
  });

  test('كل عيادة في clinics/ ملفها كامل ومستقل', () {
    final dirs = Directory('clinics').listSync().whereType<Directory>().toList();
    expect(dirs, isNotEmpty);
    for (final dir in dirs) {
      final id = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final file = File('${dir.path}/config.json');
      expect(file.existsSync(), isTrue, reason: 'clinics/$id بدون config.json');
      final data = _read(file.path);
      // المعرّف نفس اسم المجلد (ما ينسخ ملف عيادة لعيادة ثانية بالغلط)
      expect(data['CLINIC_ID'], id, reason: 'CLINIC_ID في clinics/$id لازم يكون "$id"');
      // ولا مفتاح ناقص أو زيادة (مفتاح زيادة غالباً غلطة إملائية)
      expect(data.keys.toSet(), ClinicConfig.keys.toSet(), reason: 'مفاتيح clinics/$id');
      expect(() => ClinicConfig.fromJson(data), returnsNormally);
      // ملفات العيادات تنضمّن داخل التطبيق: ممنوع فيها أي سر
      final text = file.readAsStringSync().toLowerCase();
      for (final secret in _secretHints) {
        expect(text.contains(secret), isFalse, reason: 'clinics/$id/config.json فيه شي يشبه سر ("$secret")');
      }
    }
  });

  test('رقم التواصل والروابط بالصيغة الصحيحة بس', () {
    Map<String, dynamic> withValue(String key, String value) => _read('clinics/demo/config.json')..[key] = value;
    expect(() => ClinicConfig.fromJson(withValue('CLINIC_PHONE', '0551234567')), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.fromJson(withValue('CLINIC_WHATSAPP', '+9665 1234')), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.fromJson(withValue('CLINIC_SHARE_LINK', 'http://example.com')), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.fromJson(withValue('CLINIC_STORE_URL', 'apps.apple.com')), throwsA(isA<ClinicConfigError>()));
    expect(ClinicConfig.fromJson(withValue('CLINIC_WHATSAPP', '+966512345678')).whatsappUri.toString(), 'https://wa.me/966512345678');
  });

  test('ألوان العيادة: الصيغة الصحيحة بس (0xFFRRGGBB بدون شفافية)', () {
    expect(ClinicConfig.parseColor('0xFFE3FF3A'), const Color(0xFFE3FF3A));
    expect(ClinicConfig.parseColor('0xffe3ff3a'), const Color(0xFFE3FF3A));
    expect(() => ClinicConfig.parseColor('#E3FF3A'), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.parseColor('0x80E3FF3A'), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.parseColor('lime'), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.parseColor('0xFFE3FF3'), throwsA(isA<ClinicConfigError>()));
  });

  test('لون النص فوق اللون المميز لازم يكون واضح', () {
    Map<String, dynamic> colors(String accent, String on) => _read('clinics/demo/config.json')
      ..['CLINIC_ACCENT'] = accent
      ..['CLINIC_ON_ACCENT'] = on;
    // الليموني مع الأسود (Clinics App) والأزرق مع الأبيض: واضحين
    expect(() => ClinicConfig.fromJson(colors('0xFFE3FF3A', '0xFF000000')), returnsNormally);
    expect(() => ClinicConfig.fromJson(colors('0xFF1F4FD8', '0xFFFFFFFF')), returnsNormally);
    // الليموني مع الأبيض والأزرق مع الأسود: ما يبانون، يرفضها
    expect(() => ClinicConfig.fromJson(colors('0xFFE3FF3A', '0xFFFFFFFF')), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.fromJson(colors('0xFF1F4FD8', '0xFF000000')), throwsA(isA<ClinicConfigError>()));
    expect(ClinicConfig.contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
  });

  test('حرف الشعار: حرف أو حرفين بس', () {
    Map<String, dynamic> mono(String v) => _read('clinics/demo/config.json')..['CLINIC_MONOGRAM'] = v;
    expect(ClinicConfig.fromJson(mono('نو')).monogram, 'نو');
    expect(() => ClinicConfig.fromJson(mono('نور')), throwsA(isA<ClinicConfigError>()));
    expect(() => ClinicConfig.fromJson(mono(' ')), throwsA(isA<ClinicConfigError>()));
  });

  test('ملف ناقص يوقف (ما يكمّل من عيادة ثانية)', () {
    final data = _read('clinics/demo/config.json')..remove('CLINIC_PHONE');
    expect(() => ClinicConfig.fromJson(data), throwsA(isA<ClinicConfigError>()));
  });

  testWidgets('اسم التطبيق من إعدادات العيادة', (tester) async {
    // تبويب حسابي (الرئيسية تحتاج خطوط التطبيق الحقيقية عشان تنرسم بدون فيضان، وهذي في test_goldens)
    appState.setTab(3);
    await tester.pumpWidget(ClinicsApp(key: UniqueKey()));
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, ClinicConfig.current.appName);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
