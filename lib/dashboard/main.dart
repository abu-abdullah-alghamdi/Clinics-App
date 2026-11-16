import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/widgets.dart';

import 'dashboard_app.dart';

/// لوحة العيادة (ويب): flutter run -d chrome -t lib/dashboard/main.dart
void main() {
  // على الويب ما فيه عناصر آبل الأصلية: كل عناصر المكتبة تطلع بالبديل المرسوم
  // ignore: invalid_use_of_visible_for_testing_member
  PlatformVersion.debugForceFallbacks = true;
  runApp(const DashboardApp());
}
