/// إعدادات وهوية العيادة: المصدر الموحد لكل ما يختلف من عيادة لعيادة.
///
/// كل عيادة لها ملف مستقل في `clinics/<id>/config.json`، ويوصل للتطبيق وقت البناء:
///
///   flutter run --release --dart-define-from-file=clinics/demo/config.json
///
/// القيم تنقرأ وقت البناء (ثابتة داخل التطبيق)، فنسخة كل عيادة ما تحتوي إلا ملفها.
///
/// - بدون ملف: التطبيق يشتغل بإعدادات demo (عيادتي) عشان التشغيل وقت التطوير يبقى زي ما هو.
/// - مع ملف: لازم يحتوي كل المفاتيح وبصيغة صحيحة. لو نقص مفتاح يوقف التشغيل برسالة واضحة،
///   بدل ما ياخذ القيمة الناقصة من demo وتطلع عيادة بهوية عيادة ثانية.
///
/// ملفات العيادات تنضمّن داخل التطبيق ويقدر أي أحد يقراها: ممنوع فيها أي سر
/// (مفاتيح دفع، كلمات مرور، توكنات). الأسرار مكانها السيرفر.
///
/// الهوية: الاسم، التواصل، الروابط، حرف الشعار، والألوان.
///
/// الألوان بصيغة 0xFFRRGGBB (مثل 0xFFE3FF3A) عشان تنقرأ وقت البناء كقيم ثابتة
/// (AppColors.accent في theme.dart)، فكل الواجهة تتلون بلون العيادة بدون أي تكلفة وقت التشغيل.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

@immutable
class ClinicConfig {
  const ClinicConfig({
    required this.id,
    required this.appName,
    required this.nameEn,
    required this.phone,
    required this.whatsapp,
    required this.shareLink,
    required this.storeUrl,
    required this.monogram,
    required this.accent,
    required this.onAccent,
    required this.iosBundleId,
    required this.androidAppId,
    required this.splashColor,
  });

  /// معرّف العيادة (نفس اسم مجلدها في clinics/)
  final String id;

  /// اسم العيادة/التطبيق اللي يشوفه المستخدم (في النصوص والمشاركة والتقويم)
  final String appName;

  /// اسم العيادة بالإنجليزي (للمتاجر والنسخة الإنجليزية مستقبلاً، ما يظهر في الواجهة الحين)
  final String nameEn;

  /// رقم الاتصال بالعيادة (بالصيغة الدولية: +966...)
  final String phone;

  /// رقم واتساب العيادة (بالصيغة الدولية، ممكن يختلف عن رقم الاتصال)
  final String whatsapp;

  /// الرابط اللي ينرسل مع مشاركة طبيب أو خدمة
  final String shareLink;

  /// صفحة التطبيق في المتجر (زر "تحديث من App Store")
  final String storeUrl;

  /// حرف الشعار (حرف أو حرفين) يطلع مكان الشعار لين تتوفر صورة شعار العيادة
  final String monogram;

  /// اللون المميز للعيادة (الأزرار الرئيسية، الاختيار، البطاقات المميزة)
  final Color accent;

  /// لون النص والأيقونات فوق اللون المميز (لازم يكون واضح فوقه)
  final Color onAccent;

  /// معرّف التطبيق في آيفون (Bundle ID)، مثل com.clinicsapp.clinicsApp
  final String iosBundleId;

  /// معرّف التطبيق في أندرويد (Application ID)، مثل com.clinicsapp.clinics_app
  final String androidAppId;

  /// لون خلفية شاشة البداية (قبل ما يفتح التطبيق)
  final Color splashColor;

  /// أقل تباين مسموح بين اللون المميز ولون النص فوقه (معيار WCAG للنص العادي)
  static const minContrast = 4.5;

  /// لون عيادتي المميز (الليموني) ولون النص فوقه
  static const demoAccent = 0xFFE3FF3A;
  static const demoOnAccent = 0xFF000000;

  /// رابط الاتصال
  Uri get callUri => Uri.parse('tel:$phone');

  /// رابط محادثة واتساب
  Uri get whatsappUri => Uri.parse('https://wa.me/${whatsapp.replaceAll('+', '')}');

  /// عيادتي (demo): الإعدادات وقت التطوير بدون ملف. لازم تطابق clinics/demo/config.json
  /// (فيه اختبار يتأكد من هذا)
  static const demo = ClinicConfig(
    id: 'demo',
    appName: 'عيادتي',
    nameEn: 'Eyadati',
    phone: '+966000000000',
    whatsapp: '+966000000000',
    shareLink: 'https://apps.apple.com/',
    storeUrl: 'https://apps.apple.com/',
    monogram: 'ع',
    accent: Color(demoAccent),
    onAccent: Color(demoOnAccent),
    iosBundleId: 'com.clinicsapp.clinicsApp',
    androidAppId: 'com.clinicsapp.clinics_app',
    splashColor: Color(0xFFFFFFFF),
  );

  /// إعدادات العيادة اللي انبنى لها التطبيق
  static final ClinicConfig current = fromFile ? fromValues(_environment()) : demo;

  /// هل انبنى التطبيق بملف عيادة (--dart-define-from-file)؟
  static const bool fromFile = bool.hasEnvironment(_Keys.id);

  /// كل المفاتيح المطلوبة في ملف العيادة (ولا مفتاح غيرها)
  static const keys = [
    _Keys.id,
    _Keys.appName,
    _Keys.nameEn,
    _Keys.phone,
    _Keys.whatsapp,
    _Keys.shareLink,
    _Keys.storeUrl,
    _Keys.monogram,
    _Keys.accent,
    _Keys.onAccent,
    _Keys.iosBundleId,
    _Keys.androidAppId,
    _Keys.splashColor,
  ];

  /// القيم اللي وصلت وقت البناء (null = المفتاح مو موجود في الملف)
  static Map<String, String?> _environment() {
    // String.fromEnvironment لازم يكون ثابت بالاسم، فكل مفتاح مكتوب لحاله
    const has = {
      _Keys.id: bool.hasEnvironment(_Keys.id),
      _Keys.appName: bool.hasEnvironment(_Keys.appName),
      _Keys.nameEn: bool.hasEnvironment(_Keys.nameEn),
      _Keys.phone: bool.hasEnvironment(_Keys.phone),
      _Keys.whatsapp: bool.hasEnvironment(_Keys.whatsapp),
      _Keys.shareLink: bool.hasEnvironment(_Keys.shareLink),
      _Keys.storeUrl: bool.hasEnvironment(_Keys.storeUrl),
      _Keys.monogram: bool.hasEnvironment(_Keys.monogram),
      _Keys.accent: bool.hasEnvironment(_Keys.accent),
      _Keys.onAccent: bool.hasEnvironment(_Keys.onAccent),
      _Keys.iosBundleId: bool.hasEnvironment(_Keys.iosBundleId),
      _Keys.androidAppId: bool.hasEnvironment(_Keys.androidAppId),
      _Keys.splashColor: bool.hasEnvironment(_Keys.splashColor),
    };
    const values = {
      _Keys.id: String.fromEnvironment(_Keys.id),
      _Keys.appName: String.fromEnvironment(_Keys.appName),
      _Keys.nameEn: String.fromEnvironment(_Keys.nameEn),
      _Keys.phone: String.fromEnvironment(_Keys.phone),
      _Keys.whatsapp: String.fromEnvironment(_Keys.whatsapp),
      _Keys.shareLink: String.fromEnvironment(_Keys.shareLink),
      _Keys.storeUrl: String.fromEnvironment(_Keys.storeUrl),
      _Keys.monogram: String.fromEnvironment(_Keys.monogram),
      _Keys.accent: String.fromEnvironment(_Keys.accent),
      _Keys.onAccent: String.fromEnvironment(_Keys.onAccent),
      _Keys.iosBundleId: String.fromEnvironment(_Keys.iosBundleId),
      _Keys.androidAppId: String.fromEnvironment(_Keys.androidAppId),
      _Keys.splashColor: String.fromEnvironment(_Keys.splashColor),
    };
    return {for (final k in keys) k: has[k]! ? values[k] : null};
  }

  /// يبني الإعدادات من محتوى ملف عيادة (للاختبارات والأدوات)
  static ClinicConfig fromJson(Map<String, dynamic> json) =>
      fromValues({for (final k in keys) k: json[k] is String ? json[k] as String : null});

  /// يتحقق من كل القيم ويبني الإعدادات. أي نقص أو صيغة غلط = يوقف برسالة واضحة
  static ClinicConfig fromValues(Map<String, String?> v) {
    final missing = [
      for (final k in keys)
        if ((v[k] ?? '').trim().isEmpty) k,
    ];
    if (missing.isNotEmpty) throw ClinicConfigError('ملف العيادة ناقص: ${missing.join('، ')}');
    String s(String k) => v[k]!.trim();
    final accent = parseColor(s(_Keys.accent), _Keys.accent);
    final onAccent = parseColor(s(_Keys.onAccent), _Keys.onAccent);
    final ratio = contrastRatio(accent, onAccent);
    if (ratio < minContrast) {
      throw ClinicConfigError('${_Keys.onAccent} مو واضح فوق ${_Keys.accent}: التباين ${ratio.toStringAsFixed(1)} '
          'وأقل شي $minContrast. جرّب أسود 0xFF000000 أو أبيض 0xFFFFFFFF');
    }
    final monogram = s(_Keys.monogram);
    if (monogram.characters.length > 2) {
      throw ClinicConfigError('${_Keys.monogram} حرف أو حرفين بس، والموجود "$monogram"');
    }
    final id = s(_Keys.id);
    if (!RegExp(r'^[a-z][a-z0-9_]{1,30}$').hasMatch(id)) {
      throw ClinicConfigError('${_Keys.id} حروف إنجليزية صغيرة وأرقام و_ بس (مثل demo أو noor)، والموجود "$id"');
    }
    final iosId = s(_Keys.iosBundleId);
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)+$').hasMatch(iosId)) {
      throw ClinicConfigError('${_Keys.iosBundleId} لازم بصيغة com.company.app، والموجود "$iosId"');
    }
    final androidId = s(_Keys.androidAppId);
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$').hasMatch(androidId)) {
      throw ClinicConfigError('${_Keys.androidAppId} لازم بصيغة com.company.app (بدون -)، والموجود "$androidId"');
    }
    final nameEn = s(_Keys.nameEn);
    if (!RegExp(r"^[A-Za-z][A-Za-z0-9 &'.-]{1,40}$").hasMatch(nameEn)) {
      throw ClinicConfigError('${_Keys.nameEn} حروف إنجليزية (مثل Noor Clinic)، والموجود "$nameEn"');
    }
    return ClinicConfig(
      id: id,
      appName: s(_Keys.appName),
      nameEn: nameEn,
      phone: _phone(s(_Keys.phone), _Keys.phone),
      whatsapp: _phone(s(_Keys.whatsapp), _Keys.whatsapp),
      shareLink: _url(s(_Keys.shareLink), _Keys.shareLink),
      storeUrl: _url(s(_Keys.storeUrl), _Keys.storeUrl),
      monogram: monogram,
      accent: accent,
      onAccent: onAccent,
      iosBundleId: iosId,
      androidAppId: androidId,
      splashColor: parseColor(s(_Keys.splashColor), _Keys.splashColor),
    );
  }

  /// نسبة التباين بين لونين (1 = ما فيه فرق، 21 = أسود وأبيض) حسب معيار WCAG
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  static String _phone(String value, String key) {
    if (!RegExp(r'^\+\d{8,15}$').hasMatch(value)) {
      throw ClinicConfigError('$key لازم يكون رقم دولي مثل +966500000000، والموجود "$value"');
    }
    return value;
  }

  static String _url(String value, String key) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw ClinicConfigError('$key لازم يكون رابط يبدأ بـ https://، والموجود "$value"');
    }
    return value;
  }

  /// يحوّل "0xFFE3FF3A" للون. نفس الصيغة اللي ينقراها البناء (int.fromEnvironment)،
  /// ولازم يكون اللون كامل بدون شفافية (أول خانتين FF)
  static Color parseColor(String value, [String key = 'color']) {
    final v = value.trim();
    if (!RegExp(r'^0x[fF]{2}[0-9a-fA-F]{6}$').hasMatch(v)) {
      throw ClinicConfigError('$key لازم يكون لون بصيغة 0xFFRRGGBB (مثل 0xFFE3FF3A)، والموجود "$value"');
    }
    return Color(int.parse(v));
  }

  @override
  bool operator ==(Object other) =>
      other is ClinicConfig &&
      other.id == id &&
      other.appName == appName &&
      other.nameEn == nameEn &&
      other.phone == phone &&
      other.whatsapp == whatsapp &&
      other.shareLink == shareLink &&
      other.storeUrl == storeUrl &&
      other.monogram == monogram &&
      other.accent == accent &&
      other.onAccent == onAccent &&
      other.iosBundleId == iosBundleId &&
      other.androidAppId == androidAppId &&
      other.splashColor == splashColor;

  @override
  int get hashCode => Object.hash(id, appName, nameEn, phone, whatsapp, shareLink, storeUrl, monogram, accent, onAccent, iosBundleId, androidAppId, splashColor);

  @override
  String toString() => 'ClinicConfig($id, $appName)';
}

/// أسماء المفاتيح في ملف العيادة (clinics/<id>/config.json)
abstract final class _Keys {
  static const id = 'CLINIC_ID';
  static const appName = 'CLINIC_APP_NAME';
  static const nameEn = 'CLINIC_NAME_EN';
  static const phone = 'CLINIC_PHONE';
  static const whatsapp = 'CLINIC_WHATSAPP';
  static const shareLink = 'CLINIC_SHARE_LINK';
  static const storeUrl = 'CLINIC_STORE_URL';
  static const monogram = 'CLINIC_MONOGRAM';
  static const accent = 'CLINIC_ACCENT';
  static const onAccent = 'CLINIC_ON_ACCENT';
  static const iosBundleId = 'CLINIC_IOS_BUNDLE_ID';
  static const androidAppId = 'CLINIC_ANDROID_APP_ID';
  static const splashColor = 'CLINIC_SPLASH_COLOR';
}

/// خطأ في ملف إعدادات العيادة (يوقف التشغيل من البداية برسالة واضحة)
class ClinicConfigError extends Error {
  ClinicConfigError(this.message);

  final String message;

  @override
  String toString() => 'ClinicConfigError: $message';
}
