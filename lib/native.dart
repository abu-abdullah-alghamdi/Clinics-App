/// ميزات الجوال: المشاركة، التقويم، والتذكير المحلي قبل الموعد
library;

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:url_launcher/url_launcher.dart';

import 'clinic_config.dart';
import 'data.dart';
import 'extras.dart';
import 'services_data.dart';

/// بداية الموعد ونهايته (الموعد اللي حددته العيادة)
DateTime bookingStart(Booking b) => b.at ?? DateTime.now();

DateTime bookingEnd(Booking b) => bookingStart(b).add(Duration(minutes: b.doctor?.duration ?? 30));

/// "مع د. فهد الزهراني" (أو فاضي لو الطبيب ما تحدد)
String withDoctor(Booking b) => b.doctor == null ? '' : ' مع ${b.doctor!.name}';

/// قائمة المشاركة الأصلية من آبل
Future<void> shareText(BuildContext context, String text) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    await SharePlus.instance.share(ShareParams(
      text: text,
      // على الآيباد القائمة تطلع كنافذة صغيرة فوق الزر
      sharePositionOrigin: box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null,
    ));
  } catch (_) {}
}

// اسم العيادة ورابط المشاركة من إعدادات العيادة (clinics/<id>/config.json)
String shareDoctorText(Doctor d) {
  final c = ClinicConfig.current;
  return '${d.name} · ${d.role}\nاطلب موعدك من تطبيق ${c.appName}\n${c.shareLink}';
}

String shareServiceText(Service s) {
  final offer = s.onOffer ? ' (خصم ${fmtNum(s.discount)}%)' : '';
  final c = ClinicConfig.current;
  return '${s.name}$offer · ${s.priceWords}\n${s.availabilityText}\nاطلبها من تطبيق ${c.appName}\n${c.shareLink}';
}

/// الوصف في موعد التقويم
String get calendarEventNote => 'موعد في ${ClinicConfig.current.appName}';

/// يفتح نافذة التقويم من آبل والموعد معبّى فيها (مع تذكير قبله بساعة).
/// يرجّع false لو الوصول للتقويم مقفل
Future<bool> addBookingToCalendar(Booking b) async {
  final branch = b.branch;
  try {
    return await Add2Calendar.addEvent2Cal(Event(
      title: '${b.title}${withDoctor(b)}',
      description: calendarEventNote,
      location: '${branch.name}، ${branch.area}',
      startDate: bookingStart(b),
      endDate: bookingEnd(b),
      iosParams: const IOSParams(reminder: Duration(hours: 1)),
    ));
  } catch (_) {
    return false;
  }
}

/// يفتح إعدادات التطبيق في الجوال (للتنبيهات والتقويم)
Future<void> openAppSettings() async {
  try {
    await launchUrl(Uri.parse('app-settings:'));
  } catch (_) {}
}

/// تذكير من الجوال نفسه قبل الموعد بساعة (يوصل حتى بدون إنترنت)
class Reminders {
  Reminders._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static AppLifecycleListener? _lifecycle;
  static const _askedKey = 'notifications_asked';

  /// true لو المستخدم قفل التنبيهات بعد ما سألناه (يطلع تنبيه في "مواعيدي")
  static final blocked = ValueNotifier<bool>(false);

  static IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
      await _plugin.initialize(const InitializationSettings(
        iOS: DarwinInitializationSettings(
          // نطلب الإذن وقت أول حجز، مو أول ما يفتح التطبيق
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ));
      _ready = true;
      // لو رجع من الإعدادات بعد ما فعّلها، يختفي التنبيه
      _lifecycle ??= AppLifecycleListener(onResume: refreshStatus);
      await refreshStatus();
    } catch (_) {
      _ready = false;
    }
  }

  /// يحدّث حالة التنبيهات (مقفلة أو لا) بدون ما يسأل المستخدم
  static Future<void> refreshStatus() async {
    if (!_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_askedKey) ?? false)) return;
      final options = await _ios?.checkPermissions();
      blocked.value = !(options?.isEnabled ?? true);
    } catch (_) {}
  }

  static int _id(String bookingId) => bookingId.hashCode & 0x7fffffff;

  /// يطلب إذن الإشعارات (أول مرة بس يطلع سؤال آبل)
  static Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      final granted = await _ios?.requestPermissions(alert: true, badge: true, sound: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_askedKey, true);
      blocked.value = granted == false;
    } catch (_) {}
  }

  /// يجدول التذكير (ويستبدل القديم لو الموعد تعدّل)
  static Future<void> schedule(Booking b) async {
    if (!_ready) return;
    final at = bookingStart(b).subtract(const Duration(hours: 1));
    if (!at.isAfter(DateTime.now())) return;
    try {
      await requestPermission();
      await _plugin.zonedSchedule(
        _id(b.id),
        'تذكير بموعدك',
        'موعدك بعد ساعة${withDoctor(b)} · ${b.branch.name}',
        tz.TZDateTime.from(at, tz.local),
        const NotificationDetails(iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  /// تنبيه بعد مدة قصيرة (تجربة لوحة العيادة: "تم تحديد موعدك" لين يتربط السيرفر)
  static Future<void> notifyLater(String key, String title, String body, Duration after) async {
    if (!_ready) return;
    try {
      await requestPermission();
      await _plugin.zonedSchedule(
        key.hashCode & 0x7fffffff,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(after),
        const NotificationDetails(iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  static Future<void> cancel(String bookingId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_id(bookingId));
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
