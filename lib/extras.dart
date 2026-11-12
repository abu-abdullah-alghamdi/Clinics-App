/// بيانات الخدمات الإضافية: التقسيط، أكواد الخصم، الباقات، الملف الطبي، التأمين، التقييم
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

// ───────── الملف الطبي

class Prescription {
  const Prescription(this.name, this.dose);

  final String name;
  final String dose;
}

class MedFile {
  const MedFile(this.name, this.size);

  final String name;
  final String size;
}

class Visit {
  const Visit({
    required this.id,
    required this.doctorId,
    required this.title,
    required this.daysAgo,
    required this.branchId,
    required this.summary,
    this.prescriptions = const [],
    this.files = const [],
  });

  final String id;
  final String doctorId;
  final String title;
  final int daysAgo;
  final String branchId;
  final String summary;
  final List<Prescription> prescriptions;
  final List<MedFile> files;

  Doctor get doctor => doctorById(doctorId);
  DateTime get date => appToday.subtract(Duration(days: daysAgo));
  String get dateText => '${fmtNum(date.day)} ${monthNames[date.month - 1]} ${fmtNum(date.year)}';
}

const bloodType = 'O+';
const allergies = 'البنسلين';

const medicalVisits = [
  Visit(
    id: 'v1',
    doctorId: 'd2',
    title: 'استشارة تقويم',
    daysAgo: 7,
    branchId: 'rawdah',
    summary: 'ازدحام بسيط في الفك السفلي، ينصح بالتقويم الشفاف لمدة 9 أشهر تقريباً',
    prescriptions: [
      Prescription('غسول فم كلورهيكسيدين', 'مرتين يومياً لمدة أسبوع'),
      Prescription('باراسيتامول 500', 'عند الحاجة'),
    ],
    files: [MedFile('أشعة بانوراما', 'PDF · 2.4 MB')],
  ),
  Visit(
    id: 'v2',
    doctorId: 'd1',
    title: 'تنظيف الأسنان',
    daysAgo: 27,
    branchId: 'rawdah',
    summary: 'تم التنظيف وإزالة الجير، اللثة سليمة. ينصح بالتنظيف كل 6 أشهر',
    files: [MedFile('تقرير الزيارة', 'PDF · 0.3 MB')],
  ),
  Visit(
    id: 'v3',
    doctorId: 'd4',
    title: 'استشارة جلدية',
    daysAgo: 96,
    branchId: 'hamdaniyah',
    summary: 'جفاف بسيط في البشرة، روتين ترطيب يومي ومراجعة عند الحاجة',
    prescriptions: [Prescription('كريم مرطب', 'مرتين يومياً')],
  ),
];

// ───────── التأمين

class InsuranceCard {
  const InsuranceCard({required this.company, required this.member, required this.tier, required this.expiry, required this.copay});

  final String company;
  final String member;
  final String tier;
  final String expiry;

  /// نسبة التحمل على المريض
  final int copay;
}

class Coverage {
  const Coverage(this.label, this.covered, this.note);

  final String label;
  final bool covered;
  final String note;
}

const demoInsurance = InsuranceCard(company: 'شركة التأمين', member: '8820 4471 0093', tier: 'VIP', expiry: '12/2027', copay: 20);

const coverageList = [
  Coverage('الكشف والاستشارات', true, 'تدفع 20%'),
  Coverage('تنظيف الأسنان', true, 'مرتين بالسنة'),
  Coverage('الحشوات والعلاج', true, 'تدفع 20%'),
  Coverage('التبييض والتجميل', false, 'غير مشمول'),
];

/// سعر الكشف رقم (من نص السعر)
int priceValue(Doctor d) => int.tryParse(d.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
