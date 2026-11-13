/// الخدمات والفروع (بيانات تجريبية، تُستبدل ببيانات العيادة الحقيقية قبل النشر)
library;

import 'package:flutter/material.dart';

import 'data.dart';
import 'theme.dart';

class Branch {
  const Branch(this.id, this.name, {this.area = '', this.phone = '', this.lat = 0, this.lng = 0});

  final String id;
  final String name;
  final String area;
  final String phone;
  final double lat;
  final double lng;

  /// أيام العمل: السبت إلى الخميس، من 9 الصباح إلى 9 المساء (الجمعة مغلق)
  static const hoursText = 'السبت – الخميس\n9:00 ص – 9:00 م';

  bool openAt(DateTime t) => t.weekday != DateTime.friday && t.hour >= 9 && t.hour < 21;

  /// رابط الاتجاهات في قوقل ماب (يفتح التطبيق لو مثبت، وإلا المتصفح)
  Uri get mapsUri => Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
}

// فروع تجريبية (العناوين والأرقام والمواقع تُستبدل بالحقيقية قبل النشر)
const branches = [
  Branch('rawdah', 'فرع الروضة', area: 'جدة، حي الروضة', phone: '+966000000001', lat: 21.5636, lng: 39.1607),
  Branch('salamah', 'فرع السلامة', area: 'جدة، حي السلامة', phone: '+966000000002', lat: 21.5915, lng: 39.1488),
  Branch('hamdaniyah', 'فرع الحمدانية', area: 'جدة، حي الحمدانية', phone: '+966000000003', lat: 21.7569, lng: 39.1913),
];

Branch branchById(String id) => branches.firstWhere((b) => b.id == id, orElse: () => branches.first);

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.tint,
    this.branchIds,
    this.discount = 0,
    this.consultantPrice,
    this.kashf = false,
    this.photoId,
  });

  /// نسبة الخصم (0 = بدون عرض)
  final int discount;

  /// سعر الخدمة مع الاستشاري (null = نفس السعر)
  final int? consultantPrice;

  /// كشف (أول زيارة للتخصص)
  final bool kashf;

  /// صورة خدمة ثانية (لو ما لها صورة خاصة)
  final String? photoId;

  int get finalPrice => _off(price);
  int _off(int p) => (p * (100 - discount) / 100).round();

  /// السعر مع طبيب معيّن (الاستشاري له سعر أعلى)
  int priceWith(Doctor d) => d.consultant && consultantPrice != null ? _off(consultantPrice!) : finalPrice;
  bool get onOffer => discount > 0;
  String get oldPriceText => '${fmtNum(price)} $riyalSign';

  final String id;
  final String name;

  /// السعر بالريال
  final int price;
  final double rating;
  final int reviews;

  /// لون يطلع مكان الصورة لين تتحمل
  final Color tint;

  /// صورة الخدمة كاملة (صفحة الخدمة) ومربعة مقصوصة على الوسط (القوائم)
  String get photo => 'assets/services/${photoId ?? id}.jpg';
  String get thumb => 'assets/services/${photoId ?? id}_thumb.jpg';

  /// null = متوفرة في جميع الفروع
  final List<String>? branchIds;

  bool get allBranches => branchIds == null;
  List<String> get availableIn => branchIds ?? branches.map((b) => b.id).toList();

  String get availabilityText => allBranches
      ? 'متوفرة في جميع الفروع'
      : 'متوفرة في: ${availableIn.map((id) => branchById(id).name).join('، ')}';

  String get priceText => '${fmtNum(finalPrice)} $riyalSign';

  /// السعر بالكلمة (للمشاركة خارج التطبيق، لأن جوال المستلم ممكن ما يعرض الرمز)
  String get priceWords => '${fmtNum(finalPrice)} ريال';
  String get ratingText => rating.toStringAsFixed(1);
}

/// خلفية صور بعض الخدمات بلون العيادة المميز
const _accent = AppColors.accent;
const _sky = Color(0xFFD7EEFF);
const _peach = Color(0xFFFFE3D3);

const services = [
  Service(
    id: 'c1',
    name: 'كشف أسنان',
    price: 150,
    consultantPrice: 250,
    rating: 4.8,
    reviews: 186,
    tint: _sky,
    kashf: true,
    photoId: 's4',
  ),
  Service(
    id: 's1',
    name: 'تنظيف الأسنان',
    price: 200,
    consultantPrice: 250,
    rating: 4.8,
    reviews: 124,
    tint: _sky,
  ),
  Service(
    id: 's2',
    name: 'تبييض الأسنان',
    price: 900,
    consultantPrice: 1100,
    rating: 4.7,
    reviews: 88,
    tint: _accent,
    branchIds: ['rawdah', 'salamah'],
  ),
  Service(
    id: 's4',
    name: 'فحص شامل للأسنان',
    price: 150,
    consultantPrice: 200,
    rating: 4.8,
    reviews: 210,
    tint: _peach,
    discount: 30,
  ),
  Service(
    id: 's5',
    name: 'كشف تقويم',
    price: 300,
    rating: 4.9,
    reviews: 97,
    tint: _accent,
    branchIds: ['rawdah'],
    kashf: true,
  ),
  Service(
    id: 'c3',
    name: 'كشف جلدية',
    price: 200,
    rating: 4.7,
    reviews: 118,
    tint: _peach,
    kashf: true,
    photoId: 's6',
  ),
  Service(
    id: 's6',
    name: 'تنظيف البشرة',
    price: 300,
    rating: 4.6,
    reviews: 73,
    tint: _peach,
    branchIds: ['salamah', 'hamdaniyah'],
  ),
  Service(
    id: 'c4',
    name: 'كشف ليزر',
    price: 150,
    rating: 4.8,
    reviews: 52,
    tint: _sky,
    branchIds: ['salamah', 'hamdaniyah'],
    kashf: true,
    photoId: 's7',
  ),
  Service(
    id: 's7',
    name: 'جلسة ليزر',
    price: 400,
    rating: 4.7,
    reviews: 64,
    tint: _sky,
    branchIds: ['salamah'],
  ),
];

Service serviceById(String id) => services.firstWhere((s) => s.id == id);

/// صورة الخدمة المربعة بزوايا دائرية
class ServiceImage extends StatelessWidget {
  const ServiceImage({super.key, required this.service, this.size = 92});

  final Service service;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: service.tint, borderRadius: BorderRadius.circular(size * 0.28)),
          child: Image.asset(
            service.thumb,
            fit: BoxFit.cover,
            // نحمّل الصورة بحجم المربع بس عشان الذاكرة والسرعة
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          ),
        ),
      );
}

/// المبلغ برمز الريال (بدون كسور إذا رقم صحيح، وإلا برقمين بعد الفاصلة)
String money(num v) {
  final whole = v == v.roundToDouble();
  return '${whole ? v.round().toString() : v.toStringAsFixed(2)} $riyalSign';
}

/// المبلغ بالكلمة لقارئ الشاشة
String spokenMoney(num v) {
  final whole = v == v.roundToDouble();
  return '${whole ? v.round().toString() : v.toStringAsFixed(2)} ريال';
}

/// تقييم مستخدم لخدمة (name = null يعني مستخدم مجهول)
class Review {
  const Review({this.name, required this.stars, required this.daysAgo, required this.text});

  final String? name;
  final int stars;
  final int daysAgo;
  final String text;

  String get displayName => name ?? 'مستخدم مجهول';
  bool get anonymous => name == null;
}

/// "قبل 3 أيام" ...
String agoText(int d) {
  if (d <= 0) return 'اليوم';
  if (d == 1) return 'أمس';
  if (d == 2) return 'قبل يومين';
  if (d <= 10) return 'قبل ${fmtNum(d)} أيام';
  if (d < 30) return 'قبل ${fmtNum(d)} يوم';
  if (d < 60) return 'قبل شهر';
  if (d < 90) return 'قبل شهرين';
  return 'قبل ${fmtNum(d ~/ 30)} شهور';
}

/// نبذة كل خدمة (نص تجريبي)
const serviceAbout = {
  'c1': 'كشف عند طبيب الأسنان: فحص الأسنان واللثة، وتشخيص الحالة، وخطة علاج واضحة بالخطوات والتكلفة',
  'c3': 'كشف عند طبيب الجلدية: تقييم البشرة أو الشعر وتشخيص المشكلة، وخطة علاج مناسبة لحالتك',
  'c4': 'كشف قبل جلسات الليزر: تقييم نوع البشرة والشعر، وتحديد الجهاز وعدد الجلسات المناسبة',
  's1': 'تنظيف عميق للأسنان وإزالة الجير والتصبغات السطحية باستخدام أجهزة الموجات فوق الصوتية، مع تلميع نهائي ونصائح للعناية اليومية. ينصح فيه كل 6 أشهر للحفاظ على صحة اللثة',
  's2': 'تبييض احترافي في العيادة بجلسة وحدة تقريباً ساعة، بمواد آمنة على المينا تحت إشراف الطبيب. النتيجة تختلف حسب لون الأسنان الأساسي، ويعطيك الطبيب تعليمات للحفاظ على النتيجة',
  's4': 'فحص كامل للفم والأسنان واللثة مع أشعة عند الحاجة، ويطلع لك تقرير واضح بالحالة وخطة علاج مقترحة بالأولويات والتكلفة',
  's5': 'كشف عند استشاري التقويم: تقييم الإطباق والفكين، وشرح خيارات التقويم المناسبة (الشفاف أو التقليدي) والمدة المتوقعة والتكلفة',
  's6': 'تنظيف بشرة عميق يشمل التقشير وإزالة الرؤوس السوداء والترطيب، ويُختار نوع الجلسة حسب نوع بشرتك بعد تقييم سريع',
  's7': 'جلسة ليزر لإزالة الشعر بأجهزة حديثة مناسبة لأغلب أنواع البشرة، والسعر للمنطقة الوحدة. تحتاج عادة من 6 إلى 8 جلسات لنتيجة واضحة',
};

/// تقييمات تجريبية لكل خدمة (تُستبدل بتقييمات المرضى الحقيقية قبل النشر)
const serviceReviews = {
  's1': [
    Review(name: 'سارة م', stars: 5, daysAgo: 3, text: 'التنظيف كان سريع وما حسيت بألم، والطبيبة شرحت لي كل خطوة'),
    Review(stars: 4, daysAgo: 12, text: 'خدمة ممتازة، بس الانتظار كان أطول من الموعد بشوي'),
    Review(name: 'عبدالله ع', stars: 5, daysAgo: 40, text: 'أسناني صارت أنظف بشكل واضح، أنصح فيه'),
  ],
  's2': [
    Review(name: 'ريم ح', stars: 5, daysAgo: 6, text: 'النتيجة فرقت كثير من أول جلسة، والحساسية كانت خفيفة'),
    Review(stars: 4, daysAgo: 25, text: 'حلو بس توقعت درجة أفتح شوي'),
    Review(name: 'خالد س', stars: 5, daysAgo: 70, text: 'تعامل راقي وتعليمات واضحة بعد الجلسة'),
  ],
  's4': [
    Review(stars: 5, daysAgo: 1, text: 'الفحص كان شامل وعطوني تقرير مفصل بكل شي'),
    Review(name: 'نوف ا', stars: 5, daysAgo: 9, text: 'سعره مناسب جداً مقابل اللي تاخذه'),
    Review(name: 'ماجد ت', stars: 4, daysAgo: 50, text: 'مفيد، وخطة العلاج كانت واضحة ومرتبة'),
  ],
  's5': [
    Review(name: 'لمى ع', stars: 5, daysAgo: 5, text: 'الاستشاري شرح الخيارات بدون ما يضغط علي، وفهمت كل شي'),
    Review(stars: 5, daysAgo: 28, text: 'استشارة مفيدة وطلعت بخطة واضحة ومدة متوقعة'),
  ],
  's6': [
    Review(name: 'هيا ب', stars: 5, daysAgo: 4, text: 'بشرتي صارت أنعم من أول جلسة'),
    Review(stars: 4, daysAgo: 15, text: 'حلوة الجلسة، بس فيه احمرار خفيف يوم كامل'),
    Review(name: 'شهد ر', stars: 4, daysAgo: 60, text: 'الأخصائية لطيفة وتعطي نصايح مفيدة'),
  ],
  's7': [
    Review(name: 'أمل ج', stars: 5, daysAgo: 7, text: 'الجهاز ممتاز والألم بسيط جداً'),
    Review(stars: 4, daysAgo: 21, text: 'النتيجة بدت تبين من الجلسة الثالثة'),
  ],
};

/// تخصص كل خدمة
const serviceCat = {
  'c1': 'dental',
  'c3': 'derma',
  'c4': 'laser',
  's1': 'dental',
  's2': 'dental',
  's4': 'dental',
  's5': 'ortho',
  's6': 'derma',
  's7': 'laser',
};

extension ServiceDetails on Service {
  String get cat => serviceCat[id] ?? '';
  String get about => serviceAbout[id] ?? '';
  List<Review> get reviewList => serviceReviews[id] ?? const [];
}

List<Service> servicesIn(String? cat) => cat == null ? services : services.where((x) => x.cat == cat).toList();

/// الخدمة اللي عليها العرض في الصفحة الرئيسية
Service get offerService => services.firstWhere((x) => x.onOffer, orElse: () => services.first);

/// الأكثر طلباً: أكثر الخدمات تقييمات
List<Service> get popularServices => ([...services]..sort((a, b) => b.reviews.compareTo(a.reviews))).take(4).toList();

/// الفروع اللي يداوم فيها كل طبيب
const doctorBranches = {
  'd1': ['rawdah', 'salamah', 'hamdaniyah'],
  'd2': ['rawdah', 'salamah'],
  'd3': ['salamah', 'hamdaniyah'],
  'd4': ['hamdaniyah', 'rawdah'],
};

List<Branch> branchesOf(String doctorId) =>
    [for (final id in doctorBranches[doctorId] ?? const <String>[]) branchById(id)];

/// الأطباء اللي يقدمون الخدمة في فرع معيّن
List<Doctor> doctorsFor(Service sv, String branchId) => doctors
    .where((d) => (doctorBranches[d.id] ?? const <String>[]).contains(branchId))
    .where((d) => d.cats.contains(sv.cat))
    .toList();

/// الفروع اللي تتوفر فيها الخدمة ومعها طبيب يقدمها (ولو فيه طبيب محدد: الفروع اللي يداوم فيها)
List<Branch> branchesFor(Service sv, {Doctor? doctor}) => branches
    .where((b) => sv.availableIn.contains(b.id))
    .where((b) => doctor == null ? doctorsFor(sv, b.id).isNotEmpty : doctorsFor(sv, b.id).any((d) => d.id == doctor.id))
    .toList();

/// الخدمات اللي يقدمها الطبيب (الكشف أول)
List<Service> servicesOf(Doctor d) => [
      ...services.where((x) => x.kashf && d.cats.contains(x.cat) && branchesFor(x, doctor: d).isNotEmpty),
      ...services.where((x) => !x.kashf && d.cats.contains(x.cat) && branchesFor(x, doctor: d).isNotEmpty),
    ];

/// أقل وأعلى سعر للخدمة مع الأطباء اللي يقدمونها (للطبيب المتاح)
({int min, int max}) priceRange(Service sv, {String? branchId}) {
  final docs = [
    for (final b in branchesFor(sv))
      if (branchId == null || b.id == branchId) ...doctorsFor(sv, b.id),
  ];
  if (docs.isEmpty) return (min: sv.finalPrice, max: sv.finalPrice);
  final prices = docs.map(sv.priceWith).toList()..sort();
  return (min: prices.first, max: prices.last);
}

/// نص السعر: المبلغ مع الطبيب، ومع "الطبيب المتاح" أقل مبلغ
String priceLabel(Service sv, {Doctor? doctor, String? branchId}) {
  if (doctor != null) return money(sv.priceWith(doctor));
  final r = priceRange(sv, branchId: branchId);
  return money(r.min);
}

extension BookingDetails on Booking {
  Branch get branch => branchById(branchId);
  Service get service => serviceById(serviceId);
}
