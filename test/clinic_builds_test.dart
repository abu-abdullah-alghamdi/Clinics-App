// بناء تطبيق مستقل لكل عيادة: المعرّفات والأسماء والأيقونات وشاشة البداية
//
// يتأكد إن:
// - كل عيادة معرّفاتها واسمها مختلفة عن غيرها، وعيادتي بنفس معرّفات التطبيق المثبت.
// - كل عيادة أصولها (الأيقونات وشاشة البداية) في مجلدها، وما فيه أيقونة مشتركة ممكن تتسرب لعيادة ثانية.
// - مشروع آيفون وأندرويد ياخذون كل هذا من ملف العيادة، ولا قيمة مكتوبة بيد.
//
// البناء الفعلي لعيادتين (بالتوازي وورا بعض) في GitHub: .github/workflows/build.yml
library;

import 'dart:convert';
import 'dart:io';

import 'package:clinics_app/clinic_config.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) => json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _read(String path) => File(path).readAsStringSync();

final _ids = Directory('clinics').listSync().whereType<Directory>().map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last).toList()
  ..sort();

ClinicConfig _clinic(String id) => ClinicConfig.fromJson(_json('clinics/$id/config.json'));

const _androidDensities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

void main() {
  test('عيادتي بنفس معرّفات واسم التطبيق المثبت', () {
    final demo = _clinic('demo');
    expect(demo.iosBundleId, 'com.clinicsapp.clinicsApp');
    expect(demo.androidAppId, 'com.clinicsapp.clinics_app');
    expect(demo.appName, 'عيادتي');
  });

  test('كل عيادة معرّفاتها واسمها لها لحالها', () {
    final seen = <String, Map<String, String>>{'ios': {}, 'android': {}, 'name': {}};
    for (final id in _ids) {
      final c = _clinic(id);
      for (final (kind, value) in [('ios', c.iosBundleId), ('android', c.androidAppId), ('name', c.appName)]) {
        expect(seen[kind]!.containsKey(value), isFalse, reason: '$kind "$value" مكرر بين ${seen[kind]![value]} و$id');
        seen[kind]![value] = id;
      }
    }
  });

  group('أصول كل عيادة في مجلدها', () {
    for (final id in _ids) {
      test(id, () {
        final c = _clinic(id);
        final catalog = 'clinics/$id/ios/$id.clinic.xcassets';
        expect(File('clinics/$id/icon.png').existsSync(), isTrue, reason: 'الأيقونة الأصلية');
        // آيفون: الأيقونة وشاشة البداية بأسماء ثابتة داخل مجلد العيادة
        for (final asset in ['Contents.json', 'AppIcon.appiconset/Contents.json', 'LaunchImage.imageset/Contents.json']) {
          expect(File('$catalog/$asset').existsSync(), isTrue, reason: '$catalog/$asset');
        }
        final icons = (_json('$catalog/AppIcon.appiconset/Contents.json')['images'] as List)
            .map((i) => (i as Map)['filename'])
            .whereType<String>()
            .toList();
        expect(icons, isNotEmpty);
        for (final f in icons) {
          expect(File('$catalog/AppIcon.appiconset/$f').existsSync(), isTrue, reason: 'أيقونة آيفون $f');
        }
        // لون شاشة البداية = لون العيادة في ملفها
        final color = (((_json('$catalog/LaunchBackground.colorset/Contents.json')['colors'] as List).first as Map)['color'] as Map);
        final comp = color['components'] as Map;
        int ch(String k) => (double.parse(comp[k] as String) * 255).round();
        expect(Color.fromARGB(255, ch('red'), ch('green'), ch('blue')), c.splashColor);
        // أندرويد
        for (final d in _androidDensities) {
          expect(File('clinics/$id/android/res/mipmap-$d/ic_launcher.png').existsSync(), isTrue, reason: 'أيقونة أندرويد $d');
        }
      });
    }
  });

  test('ما فيه أيقونة مشتركة ممكن تتسرب لعيادة ثانية', () {
    expect(Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset').existsSync(), isFalse);
    for (final d in _androidDensities) {
      expect(File('android/app/src/main/res/mipmap-$d/ic_launcher.png').existsSync(), isFalse, reason: 'أيقونة عامة في main/res ($d)');
    }
  });

  group('آيفون ياخذ العيادة من إعداداتها', () {
    final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');

    test('المعرّف والأصول من إعدادات العيادة، ولا معرّف مكتوب بيد', () {
      expect(RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = "\$\(CLINIC_IOS_BUNDLE_ID\)";').allMatches(pbx).length, 3);
      for (final id in _ids) {
        expect(pbx, isNot(contains('PRODUCT_BUNDLE_IDENTIFIER = ${_clinic(id).iosBundleId};')));
        // أصول كل عيادة مسجلة في المشروع من مجلدها
        expect(pbx, contains('path = ../clinics/$id/ios/$id.clinic.xcassets; sourceTree = SOURCE_ROOT;'));
      }
      expect(pbx, contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'));
    });

    test('فحص العيادة أول خطوة في البناء', () {
      final phases = RegExp(r'buildPhases = \(\s*([0-9A-F]{24}) /\* ([^*]+) \*/').allMatches(pbx).map((m) => m.group(2)!.trim()).toList();
      expect(phases, contains('Check Clinic'));
      expect(pbx, contains(r'$SRCROOT/scripts/check_clinic.sh'));
      expect(File('ios/scripts/check_clinic.sh').existsSync(), isTrue);
    });

    test('الاسم تحت الأيقونة من إعدادات العيادة', () {
      final plist = _read('ios/Runner/Info.plist');
      expect(plist, contains('<key>CFBundleDisplayName</key>\n\t<string>\$(CLINIC_DISPLAY_NAME)</string>'));
      expect(_read('ios/Runner/Base.lproj/LaunchScreen.storyboard'), contains('<color key="backgroundColor" name="LaunchBackground"/>'));
    });

    test('ترتيب الإعدادات: الافتراضية، ثم المختارة، ثم ملف العيادة من فلاتر', () {
      for (final cfg in ['Debug', 'Release']) {
        final lines = _read('ios/Flutter/$cfg.xcconfig').split('\n').where((l) => l.startsWith('#include')).toList();
        expect(lines, ['#include "ClinicDefault.xcconfig"', '#include? "ClinicSelected.xcconfig"', '#include "Generated.xcconfig"', '#include? "Signing.xcconfig"']);
      }
    });

    test('الإعدادات الافتراضية = عيادتي، وكل عيادة ما ينبني إلا أصولها', () {
      final demo = _clinic('demo');
      final x = _read('ios/Flutter/ClinicDefault.xcconfig');
      expect(x, contains('CLINIC_ID = demo\n'));
      expect(x, contains('CLINIC_IOS_BUNDLE_ID = ${demo.iosBundleId}\n'));
      expect(x, contains('CLINIC_DISPLAY_NAME = ${demo.appName}\n'));
      expect(x, contains('EXCLUDED_SOURCE_FILE_NAMES = *.clinic.xcassets\n'));
      expect(x, contains(r'INCLUDED_SOURCE_FILE_NAMES = $(CLINIC_ID).clinic.xcassets'));
    });

    test('إعدادات العيادة المختارة والتوقيع ما ترتفع لـ GitHub', () {
      final ignore = _read('ios/.gitignore');
      expect(ignore, contains('Flutter/ClinicSelected.xcconfig'));
      expect(ignore, contains('Flutter/Signing.xcconfig'));
    });
  });

  group('أندرويد ياخذ العيادة من ملفها', () {
    final gradle = _read('android/app/build.gradle.kts');

    test('المعرّف والاسم ولون البداية والأيقونة من ملف العيادة', () {
      expect(gradle, contains('applicationId = clinicValue("CLINIC_ANDROID_APP_ID")'));
      expect(gradle, contains('resValue("string", "app_name", clinicValue("CLINIC_APP_NAME")'));
      expect(gradle, contains('resValue("color", "clinic_splash"'));
      expect(gradle, contains('res.srcDir(clinicDir.resolve("android/res"))'));
      for (final id in _ids) {
        expect(gradle, isNot(contains('applicationId = "${_clinic(id).androidAppId}"')));
      }
      expect(_read('android/app/src/main/AndroidManifest.xml'), contains('android:label="@string/app_name"'));
      for (final f in ['drawable', 'drawable-v21']) {
        expect(_read('android/app/src/main/res/$f/launch_background.xml'), contains('@color/clinic_splash'));
      }
    });

    test('نسخة المتجر ما تنبني بدون ملف عيادة', () {
      expect(gradle, contains('clinicFromFile == null && gradle.startParameter.taskNames.any { it.contains("bundle", ignoreCase = true) }'));
    });
  });
}
