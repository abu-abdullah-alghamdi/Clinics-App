// ألوان هوية العيادة على الشاشات.
//
// يفتح شاشات التطبيق الرئيسية ويفحص كل نص وأيقونة مرسومة:
// - أي نص أو أيقونة فوق اللون المميز (أو بلونه) لازم يكون واضح (تباين 4.5 أو أكثر).
// - اللون المميز يظهر فعلاً في الشاشات.
// - مع ملف عيادة ثانية (test/fixtures/clinic_test.json، أزرق مع أبيض): ما يبقى ولا أثر لليموني Clinics App.
//
// في GitHub يشتغل مرتين: بملف Clinics App، وبملف عيادة الاختبار:
//   flutter test test/clinic_colors_test.dart \
//     --dart-define-from-file=test/fixtures/clinic_test.json \
//     --dart-define=CLINIC_FIXTURE=test/fixtures/clinic_test.json
library;

import 'dart:convert';

import 'package:clinics_app/clinic_config.dart';
import 'package:clinics_app/data.dart';
import 'package:clinics_app/main.dart';
import 'package:clinics_app/screens/booking_screen.dart';
import 'package:clinics_app/screens/cart_screen.dart';
import 'package:clinics_app/screens/payment_screen.dart';
import 'package:clinics_app/screens/phone_screen.dart';
import 'package:clinics_app/screens/service_screen.dart';
import 'package:clinics_app/services_data.dart';
import 'package:clinics_app/state.dart';
import 'package:clinics_app/states.dart';
import 'package:clinics_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fixture = String.fromEnvironment('CLINIC_FIXTURE');

/// ليموني Clinics App (بدون الشفافية)
const _demoRgb = ClinicConfig.demoAccent & 0x00FFFFFF;

int _rgb(Color c) => c.toARGB32() & 0x00FFFFFF;

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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 2, 852 * 2);
  tester.view.devicePixelRatio = 2;
  tester.view.padding = const FakeViewPadding(top: 59 * 2, bottom: 34 * 2);
  tester.view.viewPadding = const FakeViewPadding(top: 59 * 2, bottom: 34 * 2);
  addTearDown(tester.view.reset);
}

/// لون خلفية العنصر (لو له خلفية)
Color? _bgOf(Widget w) {
  Decoration? d;
  if (w is Container) {
    d = w.decoration;
    if (w.color != null) return w.color;
  } else if (w is AnimatedContainer) {
    d = w.decoration;
  } else if (w is DecoratedBox) {
    d = w.decoration;
  } else if (w is ColoredBox) {
    return w.color;
  } else if (w is Material && w.type != MaterialType.transparency) {
    return w.color;
  }
  return d is BoxDecoration ? d.color : null;
}

/// كل الألوان في نص (النص نفسه والأجزاء اللي داخله)
List<Color> _textColors(InlineSpan span) {
  final out = <Color>[];
  span.visitChildren((s) {
    final c = s.style?.color;
    if (c != null) out.add(c);
    return true;
  });
  return out;
}

class _Scan {
  final backgrounds = <Color>[];
  final foregrounds = <Color>[];
  final problems = <String>[];
  var checked = 0;
}

/// يفحص الشاشة الظاهرة
_Scan _scan(WidgetTester tester) {
  final scan = _Scan();
  for (final e in tester.allElements) {
    final w = e.widget;
    final bg = _bgOf(w);
    if (bg != null) scan.backgrounds.add(bg);
    if (w is! RichText) continue;
    final colors = _textColors(w.text);
    scan.foregrounds.addAll(colors);
    // أقرب خلفية مصمتة تحت النص
    Color? under;
    e.visitAncestorElements((a) {
      final c = _bgOf(a.widget);
      if (c != null && (c.a * 255).round() == 255) {
        under = c;
        return false;
      }
      return true;
    });
    final base = under ?? AppColors.bg;
    for (final fg in colors) {
      if ((fg.a * 255).round() == 0) continue;
      // نفحص ألوان الهوية بس: نص فوق اللون المميز، أو نص بلون الهوية
      final identity = base == AppColors.accent || fg == AppColors.accent || fg == AppColors.accentOnInk;
      if (!identity) continue;
      scan.checked++;
      final ratio = ClinicConfig.contrastRatio(Color.alphaBlend(fg, base), base);
      if (ratio < ClinicConfig.minContrast) {
        final text = w.text.toPlainText();
        scan.problems.add('"${text.length > 30 ? text.substring(0, 30) : text}" لون ${fg.toARGB32().toRadixString(16)} '
            'فوق ${base.toARGB32().toRadixString(16)}: تباين ${ratio.toStringAsFixed(2)}');
      }
    }
  }
  return scan;
}

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  test('ألوان الواجهة من ملف العيادة', () {
    expect(AppColors.accent, ClinicConfig.current.accent);
    expect(AppColors.onAccent, ClinicConfig.current.onAccent);
    if (_fixture.isEmpty) {
      // Clinics App: نفس الألوان بالضبط
      expect(AppColors.accent, const Color(0xFFE3FF3A));
      expect(AppColors.onAccent, const Color(0xFF000000));
      expect(AppColors.accentOnInk, AppColors.accent);
      expect(AppColors.onAccentSoft, const Color(0xB8000000));
      expect(AppColors.onOnAccent, const Color(0xFFFFFFFF));
    } else {
      expect(_rgb(AppColors.accent), isNot(_demoRgb));
    }
  });

  /// الشاشات اللي نفحصها: التبويبات، وصفحات فيها اللون المميز
  final screens = <String, ({int tab, Route<void> Function()? open, void Function()? setup})>{
    'الرئيسية': (tab: 0, open: null, setup: null),
    'مواعيدي (فاضية)': (tab: 1, open: null, setup: null),
    'الأطباء': (tab: 2, open: null, setup: null),
    'حسابي': (tab: 3, open: null, setup: null),
    'الخدمات (والسلة فيها خدمة)': (tab: 4, open: null, setup: () => appState.addToCart('s1')),
    'صفحة خدمة': (tab: 0, open: () => iosRoute(ServiceScreen(service: serviceById('s1'))), setup: null),
    'حجز موعد مع طبيب': (tab: 2, open: () => iosModal(BookingScreen(doctor: doctorById('d2'))), setup: null),
    'رقم الجوال': (tab: 3, open: () => iosRoute(const PhoneScreen(inside: true)), setup: null),
    'السلة': (tab: 4, open: () => iosRoute(const CartScreen()), setup: () => appState.addToCart('s1')),
    'الدفع': (tab: 4, open: () => iosRoute(PaymentScreen(branchId: 'rawdah', items: [OrderItem(serviceById('s2'), 1)])), setup: null),
    'التحديث الإجباري (حرف الشعار)': (tab: 0, open: null, setup: () => RemoteConfig.updateRequired = true),
  };

  var accentSeen = 0;

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('ألوان الهوية واضحة: $name', (tester) async {
      _phone(tester);
      screen.setup?.call();
      addTearDown(() {
        RemoteConfig.updateRequired = false;
        appState.cart.clear();
      });
      appState.setTab(screen.tab);
      await tester.pumpWidget(ClinicsApp(key: UniqueKey()));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final open = screen.open;
      if (open != null) {
        tester.state<NavigatorState>(find.byType(Navigator).first).push(open());
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      final scan = _scan(tester);
      // النصوص والأيقونات فوق اللون المميز (أو بلونه) واضحة
      expect(scan.problems, isEmpty, reason: scan.problems.join('\n'));
      // ولا أثر لليموني Clinics App لما العيادة غيرها
      if (_fixture.isNotEmpty) {
        final lime = [...scan.backgrounds, ...scan.foregrounds].where((c) => _rgb(c) == _demoRgb).toList();
        expect(lime, isEmpty, reason: 'ليموني Clinics App باقي في "$name"');
      }
      accentSeen += scan.backgrounds.where((c) => c == AppColors.accent).length;
      debugPrint('$name: فحص ${scan.checked} نص/أيقونة بألوان الهوية');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }, variant: ios);
  }

  test('اللون المميز ظهر فعلاً في الشاشات', () {
    expect(accentSeen, greaterThan(10));
  });
}
