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

// ───────── الرتوش بعد جلسات الليزر

/// كل جلسة ليزر لها رتوش وحدة خلال هذي المدة من تاريخ الجلسة
const touchUpDays = 14;

/// جلسة ليزر (مو كشف) تجي معها رتوش
bool hasTouchUp(Service sv) => sv.cat == 'laser' && !sv.kashf;

// ───────── تفاصيل الطلب

extension RequestDetails on Booking {
  ServicePackage? get package => packageId == null ? null : packageById(packageId!);

  /// اسم الطلب: الخدمة، أو رتوش الخدمة (والباقة سطر لحالها: packageName)
  String get title => touchUpOf != null ? 'رتوش ${service.name}' : service.name;

  /// اسم الباقة لطلب الباقة (يطلع تحت اسم الخدمة)
  String? get packageName => package?.name;

  /// المبلغ المطلوب (0 لجلسة الباقة والرتوش)
  int get price {
    if (free) return 0;
    final p = package;
    if (p != null) return p.price;
    final d = doctor;
    return d != null ? service.priceWith(d) : priceRange(service, branchId: branchId).min;
  }

  /// نص المبلغ للعرض
  String get priceText {
    if (userPackageId != null) return 'من باقتك';
    if (touchUpOf != null) return 'بدون مبلغ';
    if (package != null) return money(package!.price);
    return priceLabel(service, doctor: doctor, branchId: branchId);
  }
}
