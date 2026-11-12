// الشريط العائم وقت فتح الصفحات
//
// أول إطار من أي صفحة جديدة، فلاتر (Hero) يخليها مخفية عشان يقيس عناصرها، وفي هالإطار
// حركة الصفحة تقول إنها "خلصت". كان الشريط ينخفي فيه إطار واحد ويرجع = رمشة.
library;

import 'package:clinics_app/main.dart';
import 'package:clinics_app/screens/privacy_screen.dart';
import 'package:clinics_app/screens/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('الشريط ما يختفي في أول إطار من صفحة جديدة (بدون رمشة)', (tester) async {
    appState.setTab(3);
    await tester.pumpWidget(ClinicsApp(key: UniqueKey(), showOnboarding: false));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    NavBarState bar() => TabBarRoutes.instance.view(reduceMotion: false);
    expect(bar().visible, isTrue, reason: 'الشريط ظاهر قبل فتح الصفحة');

    tester.state<NavigatorState>(find.byType(Navigator).first).push(iosRoute(const PrivacyScreen()));
    // الحالة اللي ينرسم فيها أول إطار (الصفحة مخفية للقياس)
    expect(bar().visible, isTrue, reason: 'الشريط اختفى في إطار القياس (أول إطار من الصفحة)');
    // أول 3 إطارات: الصفحة توها تبدأ تدخل، والشريط لازم يبقى ظاهر
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      expect(bar().visible, isTrue, reason: 'الشريط اختفى في الإطار ${i + 1} من فتح الصفحة');
      expect(bar().opacity, 1);
    }

    // بعد ما تكمل الصفحة تغطي الشاشة، الشريط يختفي
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(bar().visible, isFalse, reason: 'الشريط تحت الصفحة بعد ما تكمل');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
