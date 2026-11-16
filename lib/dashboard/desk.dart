/// لوحة العيادة: الطلبات والمواعيد والصلاحيات (بيانات تجريبية لين يتربط السيرفر)
///
/// طلبات المرضى التجريبية في اللوحة نفسها، وطلبات التطبيق (اللي في المعاينة) تجي من [appState]،
/// فأي طلب ينرسل من المعاينة يطلع هنا، وأي موعد يتحدد هنا يتحدث في المعاينة.
library;

import 'dart:math';

import 'package:flutter/widgets.dart';

import '../data.dart';
import '../extras.dart';
import '../main.dart' show appState;
import '../services_data.dart';

// ───────── الصلاحيات

enum StaffRole { owner, manager, reception, doctor }

extension StaffRoleInfo on StaffRole {
  String get label => switch (this) {
        StaffRole.owner => 'المالك',
        StaffRole.manager => 'مدير الفرع',
        StaffRole.reception => 'الاستقبال',
        StaffRole.doctor => 'طبيب',
      };

  /// تحديد المواعيد وتعديلها
  bool get canSchedule => this != StaffRole.doctor;

  /// الإلغاء وتأكيد الدفع في الفرع
  bool get canManage => this != StaffRole.doctor;

  bool get seesReports => this == StaffRole.owner || this == StaffRole.manager;

  /// كل الفروع (المالك)، وغيره فرعه بس
  bool get allBranches => this == StaffRole.owner;
}

class Staff {
  const Staff({required this.id, required this.name, required this.role, this.branchId, this.doctorId});

  final String id;
  final String name;
  final StaffRole role;

  /// فرع الموظف (null = كل الفروع)
  final String? branchId;

  /// حساب الطبيب: يشوف مواعيده بس
  final String? doctorId;

  String get scope {
    if (doctorId != null) return doctorById(doctorId!).role;
    if (branchId != null) return branchById(branchId!).name;
    return 'كل الفروع';
  }
}

/// حسابات تجريبية (تنضاف وتتعدل من اللوحة بعد ربط السيرفر)
const demoStaff = [
  Staff(id: 'u1', name: 'أنس الغامدي', role: StaffRole.owner),
  Staff(id: 'u2', name: 'سارة العمري', role: StaffRole.manager, branchId: 'rawdah'),
  Staff(id: 'u3', name: 'ريم الحربي', role: StaffRole.reception, branchId: 'rawdah'),
  Staff(id: 'u4', name: 'د. فهد الزهراني', role: StaffRole.doctor, doctorId: 'd2'),
];

// ───────── الطلب في اللوحة

class DeskRequest {
  DeskRequest(this.booking, {required String patient, required String phone, this.fromApp = false, this.scheduledAt})
      : _patient = patient,
        _phone = phone;

  final Booking booking;
  final String _patient;
  final String _phone;

  /// من التطبيق اللي في المعاينة (يتحدث فيه ويوصله إشعار)
  final bool fromApp;

  /// متى حددت العيادة الموعد (لسرعة الرد في التقارير)
  DateTime? scheduledAt;

  String get id => booking.id;

  /// اسم المريض (أو الشخص اللي انطلب له)
  String get patient {
    if (booking.recipientName != null) return booking.recipientName!;
    if (fromApp) return appState.name.isNotEmpty ? appState.name : 'مستخدم التطبيق';
    return _patient;
  }

  String get phone {
    if (booking.recipientPhone != null) return booking.recipientPhone!;
    if (fromApp) return appState.phone;
    return _phone;
  }

  /// ينتظر من العيادة: يحدد الموعد (أو يوافق على الباقة)
  bool get waiting => booking.status == RequestStatus.sent;

  /// مدفوع أو ما عليه مبلغ
  bool get settled => booking.paid || booking.free || booking.price == 0;
}

/// وقت متاح لموعد: كل نص ساعة داخل الفترة
List<DateTime> slotsFor(DateTime day, Period p) {
  final (from, to) = switch (p) {
    Period.morning => (9, 12),
    Period.noon => (12, 16),
    Period.evening => (16, 21),
  };
  return [
    for (var h = from; h < to; h++)
      for (final m in const [0, 30]) DateTime(day.year, day.month, day.day, h, m),
  ];
}

/// أيام الدوام القادمة (بدون الجمعة)
List<DateTime> openDays({int count = 14}) => [
      for (var i = 0; i < count + 3; i++)
        if (!DayInfo(i).closed) DayInfo(i).date,
    ].take(count).toList();

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "قبل 12 دقيقة"، "قبل 3 ساعات"، "أمس"
String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'الآن';
  if (d.inMinutes < 60) return 'قبل ${fmtNum(d.inMinutes)} دقيقة';
  if (d.inHours < 24) {
    final h = d.inHours;
    return h == 1 ? 'قبل ساعة' : (h == 2 ? 'قبل ساعتين' : 'قبل ${fmtNum(h)} ساعات');
  }
  final days = d.inDays;
  return days == 1 ? 'أمس' : 'قبل ${fmtNum(days)} أيام';
}

/// إشعار وصل لجوال المريض (يطلع في المعاينة)
class PatientNotice {
  PatientNotice(this.title, this.body) : at = DateTime.now();
  final String title;
  final String body;
  final DateTime at;
}

// ───────── حالة اللوحة

enum DeskPage { requests, appointments, reports, preview }

class DeskState extends ChangeNotifier {
  DeskState() {
    _seed();
    _syncApp(announce: false);
    appState.addListener(_syncApp);
  }

  Staff? staff;

  /// الصفحة الحالية
  DeskPage page = DeskPage.requests;

  void go(DeskPage p) {
    page = p;
    notifyListeners();
  }

  /// اليوم المعروض في المواعيد
  DateTime day = appToday;

  void setDay(DateTime d) {
    day = d;
    notifyListeners();
  }

  void signIn(Staff s) {
    staff = s;
    branchFilter = null;
    page = s.role == StaffRole.doctor ? DeskPage.appointments : DeskPage.requests;
    notifyListeners();
  }

  void signOut() {
    staff = null;
    notifyListeners();
  }

  final List<DeskRequest> _mock = [];

  /// طلبات التطبيق (نحفظ الغلاف عشان ما يضيع وقت تحديد الموعد)
  final Map<String, DeskRequest> _app = {};

  /// آخر طلب وصل من التطبيق (يطلع تنبيه "طلب جديد")
  final arrival = ValueNotifier<DeskRequest?>(null);

  /// آخر إشعار انرسل لجوال المريض (يطلع في المعاينة)
  final notice = ValueNotifier<PatientNotice?>(null);

  /// يضيف طلبات التطبيق الجديدة (والطلبات الأولية فيه ما تنبّه)
  void _syncApp({bool announce = true}) {
    for (final b in appState.bookings) {
      if (_app.containsKey(b.id)) continue;
      final r = DeskRequest(b, patient: '', phone: '', fromApp: true);
      _app[b.id] = r;
      if (announce && r.waiting) arrival.value = r;
    }
    notifyListeners();
  }

  /// كل الطلبات (بدون فلترة الصلاحية)
  List<DeskRequest> get all => [..._app.values, ..._mock];

  /// اللي يشوفه الموظف الحالي حسب صلاحيته
  List<DeskRequest> get visible {
    final s = staff;
    if (s == null) return const [];
    return all.where((r) {
      final b = r.booking;
      if (s.doctorId != null) return b.doctorId == s.doctorId && b.status != RequestStatus.sent;
      if (s.branchId != null) return b.branchId == s.branchId;
      return true;
    }).toList();
  }

  /// فلتر الفرع للمالك (null = كل الفروع)
  String? branchFilter;

  void setBranchFilter(String? id) {
    branchFilter = id;
    notifyListeners();
  }

  List<DeskRequest> get scoped =>
      branchFilter == null ? visible : visible.where((r) => r.booking.branchId == branchFilter).toList();

  /// الطلبات اللي تنتظر تحديد موعد: الأقدم أول
  List<DeskRequest> get waiting => scoped.where((r) => r.waiting).toList()
    ..sort((a, b) => a.booking.createdAt.compareTo(b.booking.createdAt));

  /// مواعيد يوم
  List<DeskRequest> appointmentsOn(DateTime day) => scoped
      .where((r) => r.booking.at != null && sameDay(r.booking.at!, day))
      .where((r) => r.booking.status != RequestStatus.sent)
      .toList()
    ..sort((a, b) => a.booking.at!.compareTo(b.booking.at!));

  /// الطبيب مشغول في هذا الوقت؟ (موعد ثاني مؤكد بنفس الوقت)
  bool busy(String doctorId, DateTime at, {String? except}) => all.any((r) =>
      r.id != except &&
      r.booking.doctorId == doctorId &&
      r.booking.status == RequestStatus.scheduled &&
      r.booking.at == at);

  /// أطباء الخدمة في فرع الطلب
  List<Doctor> doctorsOf(DeskRequest r) => doctorsFor(r.booking.service, r.booking.branchId);

  // ───────── الإجراءات

  /// تحديد الموعد وإرساله للعميل (يتحدث في تطبيقه ويوصله إشعار)
  void schedule(DeskRequest r, {required DateTime at, required String doctorId}) {
    final b = r.booking;
    final first = b.status == RequestStatus.sent;
    if (r.fromApp) {
      appState.clinicSchedule(b.id, at: at, doctorId: doctorId);
    } else {
      b
        ..status = RequestStatus.scheduled
        ..at = at
        ..doctorId = doctorId;
    }
    r.scheduledAt ??= DateTime.now();
    if (r.fromApp) {
      notice.value = PatientNotice(
        first ? 'تم تحديد موعدك' : 'تغيّر موعدك',
        '${b.title} ${fmtDay(at)} الساعة ${fmtClock(at)} مع ${doctorById(doctorId).name}، ${b.branch.name}',
      );
    }
    notifyListeners();
  }

  /// موافقة على طلب باقة (بعدها يدفع المريض من التطبيق)
  void approve(DeskRequest r) {
    if (r.fromApp) {
      appState.clinicApprove(r.id);
      notice.value = PatientNotice('تمت الموافقة على طلبك', '${r.booking.title}: ${r.booking.packageName ?? ''}، تقدر تدفع الحين');
    } else {
      r.booking.status = RequestStatus.approved;
    }
    r.scheduledAt ??= DateTime.now();
    notifyListeners();
  }

  void complete(DeskRequest r) {
    r.fromApp ? appState.clinicComplete(r.id) : r.booking.status = RequestStatus.completed;
    notifyListeners();
  }

  void noShow(DeskRequest r) {
    r.fromApp ? appState.clinicNoShow(r.id) : r.booking.status = RequestStatus.noShow;
    notifyListeners();
  }

  void confirmPayment(DeskRequest r) {
    if (r.fromApp) {
      appState.clinicConfirmPayment(r.id);
    } else {
      r.booking
        ..orderNumber ??= 'branch'
        ..payLater = false;
    }
    notifyListeners();
  }

  void cancel(DeskRequest r, String reason) {
    if (r.fromApp) {
      appState.cancelByClinic(r.id, reason);
      notice.value = PatientNotice('تم إلغاء طلبك', '${r.booking.title}: $reason');
    } else {
      r.booking
        ..clinicCancelReason = reason
        ..status = RequestStatus.cancelled;
    }
    notifyListeners();
  }

  // ───────── التقارير

  /// كل الطلبات في نطاق الموظف خلال آخر [days] يوم
  List<DeskRequest> since(int days) {
    final from = appToday.subtract(Duration(days: days - 1));
    return scoped.where((r) => !r.booking.createdAt.isBefore(from)).toList();
  }

  // ───────── بيانات تجريبية: مرضى بطلبات ومواعيد على آخر شهر والأيام الجاية

  void _seed() {
    final rnd = Random(11);
    const names = [
      'نوف الشهري', 'عبدالله القرني', 'هيا المطيري', 'خالد الدوسري', 'لمى الزهراني', 'فيصل العنزي',
      'جود الحارثي', 'تركي السبيعي', 'شهد البقمي', 'ماجد الشمري', 'رهف الغامدي', 'سعود العتيبي',
      'دانة القحطاني', 'بندر الحربي', 'غلا الجهني', 'عمر باوزير', 'ريناد الأحمدي', 'نواف المالكي',
      'أسيل بخاري', 'يزيد الثبيتي', 'لين الصاعدي', 'مشاري العمري', 'سديم الرشيدي', 'حمد الشهراني',
    ];
    var seq = 100;
    var n = 0;

    String phone() => '+9665${(10000000 + rnd.nextInt(89999999))}';

    DeskRequest make({
      required int dayOffset,
      required RequestStatus status,
      DateTime? at,
      int? responseMinutes,
      bool paid = false,
      bool payLater = false,
      int hour = -1,
    }) {
      final sv = services[rnd.nextInt(services.length)];
      final branchesOk = branchesFor(sv);
      final br = branchesOk[rnd.nextInt(branchesOk.length)];
      final docs = doctorsFor(sv, br.id);
      final doc = rnd.nextInt(3) == 0 ? null : docs[rnd.nextInt(docs.length)];
      final period = Period.values[rnd.nextInt(3)];
      final created = DateTime(appToday.year, appToday.month, appToday.day + dayOffset, hour >= 0 ? hour : 9 + rnd.nextInt(12), rnd.nextInt(60));
      final b = Booking(
        id: 'm${n++}',
        number: requestNumber(++seq, created),
        serviceId: sv.id,
        branchId: br.id,
        doctorId: status == RequestStatus.sent ? doc?.id : (doc ?? docs.first).id,
        period: period,
        status: status,
        at: at,
        createdAt: created,
      );
      if (paid) b.orderNumber = 'O-$seq';
      b.payLater = payLater;
      return DeskRequest(
        b,
        patient: names[n % names.length],
        phone: phone(),
        scheduledAt: responseMinutes == null ? null : created.add(Duration(minutes: responseMinutes)),
      );
    }

    DateTime slot(int dayOffset, Period p) {
      var o = dayOffset;
      while (DayInfo(o).closed) {
        o += dayOffset < 0 ? -1 : 1;
      }
      final s = slotsFor(DayInfo(o).date, p);
      return s[rnd.nextInt(s.length)];
    }

    // السابقة: مكتملة وغياب وملغية خلال آخر 30 يوم
    for (var d = -30; d < 0; d++) {
      final count = 1 + rnd.nextInt(3);
      for (var i = 0; i < count; i++) {
        final roll = rnd.nextInt(10);
        final status = roll < 7 ? RequestStatus.completed : (roll < 9 ? RequestStatus.noShow : RequestStatus.cancelled);
        final r = make(
          dayOffset: d - 1 - rnd.nextInt(2),
          status: status,
          at: slot(d, Period.values[rnd.nextInt(3)]),
          responseMinutes: 4 + rnd.nextInt(170),
          paid: status == RequestStatus.completed && rnd.nextBool(),
        );
        if (status == RequestStatus.completed && !r.booking.paid) r.booking.orderNumber = 'branch';
        if (status == RequestStatus.cancelled) r.booking.clinicCancelReason = 'طلب المريض الإلغاء';
        _mock.add(r);
      }
    }

    // القادمة: مواعيد محددة اليوم والأيام الجاية
    for (var d = 0; d < 6; d++) {
      final count = d == 0 ? 5 : 2 + rnd.nextInt(3);
      for (var i = 0; i < count; i++) {
        _mock.add(make(
          dayOffset: d - 1 - rnd.nextInt(2),
          status: RequestStatus.scheduled,
          at: slot(d, Period.values[rnd.nextInt(3)]),
          responseMinutes: 5 + rnd.nextInt(90),
          paid: rnd.nextInt(3) == 0,
          payLater: rnd.nextBool(),
        ));
      }
    }

    // الجديدة: تنتظر تحديد موعد (من اليوم وأمس)
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      final r = make(dayOffset: 0, status: RequestStatus.sent, hour: 0);
      final created = now.subtract(Duration(minutes: 3 + i * i * 9 + rnd.nextInt(6)));
      _mock.add(DeskRequest(
        Booking(
          id: r.booking.id,
          number: r.booking.number,
          serviceId: r.booking.serviceId,
          branchId: r.booking.branchId,
          doctorId: r.booking.doctorId,
          period: r.booking.period,
          createdAt: created,
        ),
        patient: r.patient,
        phone: r.phone,
      ));
    }
  }

  @override
  void dispose() {
    appState.removeListener(_syncApp);
    arrival.dispose();
    notice.dispose();
    super.dispose();
  }
}

/// يوفّر حالة اللوحة لكل الصفحات
class DeskScope extends InheritedNotifier<DeskState> {
  const DeskScope({super.key, required DeskState desk, required super.child}) : super(notifier: desk);

  static DeskState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DeskScope>()!.notifier!;
  static DeskState read(BuildContext context) => context.getInheritedWidgetOfExactType<DeskScope>()!.notifier!;
}
