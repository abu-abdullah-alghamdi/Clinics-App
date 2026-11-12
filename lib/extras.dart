/// بيانات الخدمات الإضافية: التقسيط، أكواد الخصم، الباقات، التقييم
/// (بيانات تجريبية لين يتربط نظام العيادة)
library;

import 'data.dart';
import 'services_data.dart';

// ───────── التقسيط (تابي وتمارا)

/// أقل مبلغ يطلع معه التقسيط
const installmentMin = 300;

/// عدد الدفعات
const installmentCount = 4;

/// تواريخ الدفعات: اليوم وبعدها كل شهر
List<DateTime> installmentDates() =>
    [for (var i = 0; i < installmentCount; i++) DateTime(appToday.year, appToday.month + i, appToday.day)];

/// "اليوم" أو "8 ديسمبر"
String installmentLabel(int index, DateTime d) => index == 0 ? 'اليوم' : '${fmtNum(d.day)} ${monthNames[d.month - 1]}';

// ───────── أكواد الخصم

/// الكود ← نسبة الخصم
const coupons = {'SMILE20': 20, 'WELCOME10': 10};

// ───────── باقات الجلسات

class ServicePackage {
  const ServicePackage({required this.id, required this.serviceId, required this.sessions, required this.price});

  final String id;
  final String serviceId;
  final int sessions;
  final int price;

  Service get service => serviceById(serviceId);
  int get perSession => (price / sessions).round();
  int get savePercent => ((1 - price / (service.finalPrice * sessions)) * 100).round();
  String get name => 'باقة ${fmtNum(sessions)} جلسات';
}

const servicePackages = [
  ServicePackage(id: 'p7_3', serviceId: 's7', sessions: 3, price: 1100),
  ServicePackage(id: 'p7_6', serviceId: 's7', sessions: 6, price: 1900),
  ServicePackage(id: 'p6_3', serviceId: 's6', sessions: 3, price: 800),
];

List<ServicePackage> packagesFor(String serviceId) => servicePackages.where((p) => p.serviceId == serviceId).toList();

ServicePackage packageById(String id) => servicePackages.firstWhere((p) => p.id == id);

/// باقة اشتراها المستخدم
class UserPackage {
  UserPackage({required this.id, required this.package, this.used = 0, required this.expires});

  final String id;
  final ServicePackage package;
  int used;
  final DateTime expires;

  int get left => package.sessions - used;
  bool get done => left <= 0;
}

// ───────── التقييم بعد الزيارة

const ratingWords = ['سيئة', 'مقبولة', 'جيدة', 'جيدة جداً', 'ممتازة'];
const ratingGood = ['التعامل', 'الالتزام بالوقت', 'النظافة', 'الشرح والتوضيح', 'النتيجة'];
const ratingBad = ['الانتظار', 'التعامل', 'النظافة', 'السعر', 'النتيجة'];

// ───────── قائمة الانتظار

const waitRanges = ['أي وقت', '4 - 6 م', '6 - 8 م'];
