/// البيانات الثابتة وأدوات التنسيق
library;

const _arDigits = '٠١٢٣٤٥٦٧٨٩';

/// رمز الريال السعودي (يطلع من خط SaudiRiyal المدمج، على يسار الرقم)
const riyalSign = '\u20C1';

/// تنسيق الأرقام للعرض (التطبيق يعرض الأرقام بالإنجليزي: 0123456789)
String fmtNum(Object value) => value.toString();

/// يحوّل أي أرقام عربية يكتبها المستخدم (٠١٢…) إلى إنجليزية
String normalizeDigits(String value) => value.replaceAllMapped(
      RegExp('[٠-٩]'),
      (m) => _arDigits.indexOf(m[0]!).toString(),
    );

const monthNames = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

// DateTime.weekday: 1 = الاثنين ... 7 = الأحد
const _dayLong = {
  1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس',
  5: 'الجمعة', 6: 'السبت', 7: 'الأحد',
};
const _dayShort = {
  1: 'اثنين', 2: 'ثلاثاء', 3: 'أربعاء', 4: 'خميس',
  5: 'جمعة', 6: 'سبت', 7: 'أحد',
};

/// يوم التطبيق المرجعي (يُحسب مرة وحدة عند التشغيل)
final DateTime appToday = () {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}();

class DayInfo {
  DayInfo(this.offset) : date = DateTime(appToday.year, appToday.month, appToday.day + offset);

  final int offset;
  final DateTime date;

  bool get closed => date.weekday == DateTime.friday;
  String get label => offset == 0
      ? 'اليوم'
      : offset == 1
          ? 'غداً'
          : offset == -1
              ? 'أمس'
              : _dayLong[date.weekday]!;
  String get short => offset == 0 ? 'اليوم' : _dayShort[date.weekday]!;
  String get dayNum => fmtNum(date.day);
  String get month => monthNames[date.month - 1];
  String get full => '$label ${fmtNum(date.day)} $month';
}

/// الوقت بالدقائق بعد الساعة 4:00 مساءً
String fmtTime(int minutesAfter4pm) {
  final total = 16 * 60 + minutesAfter4pm;
  var h = (total ~/ 60) % 12;
  if (h == 0) h = 12;
  final mm = (total % 60).toString().padLeft(2, '0');
  return '${fmtNum(h)}:${fmtNum(mm)} م';
}

/// الساعة من تاريخ فعلي: "4:58 م"
String fmtClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${fmtNum(h)}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
}

/// مدة متبقية مختصرة: "ساعة و 20 دقيقة"، "45 دقيقة"
String fmtRemaining(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final hours = h == 1 ? 'ساعة' : (h == 2 ? 'ساعتين' : '${fmtNum(h)} ساعات');
  if (h == 0) return '${fmtNum(m)} دقيقة';
  return m == 0 ? hours : '$hours و ${fmtNum(m)} دقيقة';
}

String fmtRange(int start, int duration) => 'من ${fmtTime(start)} إلى ${fmtTime(start + duration)}';

const categories = {
  'dental': 'كشف وعلاج الأسنان',
  'ortho': 'استشارة تقويم',
  'derma': 'استشارة جلدية',
  'laser': 'جلسة ليزر',
};

const List<({String? id, String label})> categoryFilters = [
  (id: null, label: 'الكل'),
  (id: 'dental', label: 'أسنان'),
  (id: 'ortho', label: 'تقويم'),
  (id: 'derma', label: 'جلدية'),
  (id: 'laser', label: 'ليزر'),
];

class Doctor {
  const Doctor({
    required this.id,
    required this.n1,
    required this.n2,
    required this.role,
    required this.cats,
    required this.years,
    required this.image,
    required this.about,
    required this.patients,
    required this.yearsCount,
    required this.rating,
    required this.reviews,
    this.consultant = false,
  });

  final String id;
  final String n1;
  final String n2;
  final String role;
  final List<String> cats;
  final String years;
  final String image;
  final String about;

  /// أرقام تجريبية للعرض (تُستبدل بالأرقام الحقيقية قبل النشر)
  final int patients;
  final int yearsCount;
  final double rating;
  final int reviews;

  /// استشاري (سعره أعلى من الأخصائي في نفس الخدمة)
  final bool consultant;

  String get ratingText => rating.toStringAsFixed(1);

  String get name => '$n1 $n2';
}

int firstOpenDay({bool fromToday = true}) {
  for (var i = fromToday ? 0 : 1; i < 14; i++) {
    if (!DayInfo(i).closed) return i;
  }
  return 1;
}

const doctors = [
  Doctor(
    id: 'd1',
    n1: 'د. ريم',
    n2: 'العتيبي',
    role: 'أخصائية طب أسنان عام',
    cats: ['dental'],
    years: 'خبرة +8 سنوات',
    image: 'assets/doctors/reem.png',
    about:
        'أخصائية طب أسنان عام، تهتم بالوقاية والعلاج التجميلي للأسنان مثل الحشوات التجميلية والتنظيف العميق. تحرص على شرح الخطة العلاجية بوضوح وتجربة مريحة قدر الإمكان، وتتعامل مع الأطفال والكبار',
    patients: 640,
    yearsCount: 8,
    rating: 4.9,
    reviews: 96,
  ),
  Doctor(
    id: 'd2',
    n1: 'د. فهد',
    n2: 'الزهراني',
    role: 'استشاري تقويم الأسنان',
    cats: ['ortho', 'dental'],
    years: 'خبرة +12 سنة',
    image: 'assets/doctors/fahd.png',
    about:
        'استشاري تقويم الأسنان، متخصص في التقويم الشفاف والتقليدي وتصحيح إطباق الفك. يبدأ مع كل مريض بتقييم كامل وخطة علاج واضحة المدة والمراحل، مع متابعة دورية حتى نهاية العلاج',
    patients: 1200,
    yearsCount: 12,
    rating: 4.8,
    reviews: 210,
    consultant: true,
  ),
  Doctor(
    id: 'd3',
    n1: 'د. نورة',
    n2: 'القحطاني',
    role: 'أخصائية جلدية وليزر',
    cats: ['derma', 'laser'],
    years: 'خبرة +6 سنوات',
    image: 'assets/doctors/noura.png',
    about:
        'أخصائية الأمراض الجلدية والتجميل، تعالج حب الشباب والتصبغات ومشاكل البشرة، وتشرف على جلسات الليزر. تهتم بوضع خطة مناسبة لنوع البشرة مع روتين عناية منزلي سهل',
    patients: 480,
    yearsCount: 6,
    rating: 4.9,
    reviews: 135,
  ),
  Doctor(
    id: 'd4',
    n1: 'د. سلطان',
    n2: 'الغامدي',
    role: 'أخصائي جلدية',
    cats: ['derma'],
    years: 'خبرة +5 سنوات',
    image: 'assets/doctors/sultan.png',
    about:
        'أخصائي جلدية، يعالج الأكزيما والصدفية وتساقط الشعر والالتهابات الجلدية. يركز على التشخيص الدقيق والمتابعة المنتظمة لضمان أفضل نتيجة',
    patients: 350,
    yearsCount: 5,
    rating: 4.7,
    reviews: 72,
  ),
];

Doctor doctorById(String id) => doctors.firstWhere((d) => d.id == id, orElse: () => doctors.first);

/// فترة الزيارة اللي يفضّلها المريض (العيادة تحدد الوقت حسب جدولها)
enum Period { morning, noon, evening }

extension PeriodText on Period {
  String get label => switch (this) {
        Period.morning => 'صباحاً',
        Period.noon => 'ظهراً',
        Period.evening => 'مساءً',
      };

  /// ساعة مقترحة داخل الفترة (للوحة العيادة التجريبية)
  int get hour => switch (this) {
        Period.morning => 10,
        Period.noon => 13,
        Period.evening => 17,
      };
}

/// حالة الطلب:
/// sent أرسله المريض ← approved وافقت العيادة على الباقة ← scheduled حددت العيادة الموعد
/// ← completed مكتمل / noShow لم يحضر / cancelled ملغي
enum RequestStatus { sent, approved, scheduled, completed, noShow, cancelled }

/// زيارة (خدمة أو كشف) أو شراء باقة جلسات
enum RequestKind { visit, package }

/// "الأحد 15 نوفمبر" (أو اليوم / غداً / أمس)
String fmtDay(DateTime t) {
  final d = DateTime(t.year, t.month, t.day);
  return DayInfo((d.difference(appToday).inHours / 24).round()).full;
}

/// طلب موعد من المريض للعيادة (بدون تاريخ ووقت: العيادة تتواصل معه وتحدد الموعد من لوحة التحكم)
class Booking {
  Booking({
    required this.id,
    required this.number,
    required this.serviceId,
    required this.branchId,
    this.doctorId,
    this.period = Period.evening,
    this.kind = RequestKind.visit,
    this.packageId,
    this.userPackageId,
    this.touchUpOf,
    this.recipientName,
    this.recipientPhone,
    this.status = RequestStatus.sent,
    this.at,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;

  /// رقم الطلب
  final String number;
  final String serviceId;
  final String branchId;

  /// null = الطبيب المتاح (العيادة تحدده مع الموعد)
  String? doctorId;
  final Period period;
  final RequestKind kind;

  /// الباقة المطلوب شراؤها (لطلب الباقة)
  final String? packageId;

  /// جلسة من باقة مدفوعة (بدون مبلغ)
  final String? userPackageId;

  /// رتوش لجلسة ليزر سابقة (بدون مبلغ)
  final String? touchUpOf;

  /// الطلب لشخص ثاني
  final String? recipientName;
  final String? recipientPhone;

  RequestStatus status;

  /// الموعد اللي حددته العيادة
  DateTime? at;
  final DateTime createdAt;

  /// سبب الإلغاء لو العيادة ألغته
  String? clinicCancelReason;

  /// اختار يدفع في الفرع
  bool payLater = false;

  /// رقم عملية الدفع لو دفع من التطبيق
  String? orderNumber;

  bool get cancelledByClinic => clinicCancelReason != null;
  bool get isPackage => kind == RequestKind.package;
  bool get forOther => recipientName != null;
  bool get paid => orderNumber != null;

  /// جلسة باقة أو رتوش: ما عليها مبلغ
  bool get free => userPackageId != null || touchUpOf != null;

  /// لسا شغال (ما اكتمل ولا انلغى)
  bool get active => status == RequestStatus.sent || status == RequestStatus.approved || status == RequestStatus.scheduled;
  bool get past => !active;
  Doctor? get doctor => doctorId == null ? null : doctorById(doctorId!);
}
