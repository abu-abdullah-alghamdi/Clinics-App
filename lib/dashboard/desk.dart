/// لوحة العيادة: الطلبات والمواعيد والصلاحيات
///
/// الطلبات تجي من طبقة البيانات (requests_repo.dart)، وهي نفسها اللي يستخدمها التطبيق،
/// فأي طلب ينرسل من معاينة التطبيق يطلع هنا، وأي موعد يتحدد هنا يتحدث فيه.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data.dart';
import '../extras.dart';
import '../main.dart' show appState;
import '../repo/mock_backend.dart';
import '../repo/requests_repo.dart';
import '../services_data.dart';

// ───────── الصلاحيات

/// مستخدمين بس: إدارة العيادة (كل الصلاحيات) والاستقبال
enum StaffRole { admin, reception }

extension StaffRoleInfo on StaffRole {
  String get label => switch (this) {
        StaffRole.admin => 'إدارة العيادة',
        StaffRole.reception => 'الاستقبال',
      };

  /// تحديد المواعيد وتعديلها
  bool get canSchedule => true;

  /// الإلغاء وتأكيد الدفع في الفرع
  bool get canManage => true;

  bool get seesReports => this == StaffRole.admin;

  /// معاينة التطبيق (صفحة مستقلة)
  bool get seesPreview => this == StaffRole.admin;

  /// فلتر الفروع
  bool get allBranches => true;
}

class Staff {
  const Staff({required this.id, required this.email, required this.name, required this.role});

  final String id;
  final String email;
  final String name;
  final StaffRole role;
}

/// حسابات تجريبية لين يتربط السيرفر (هناك تنحفظ كلمات المرور مشفّرة، مو في التطبيق)
const demoStaff = [
  Staff(id: 'u1', email: 'a@noor.com', name: 'الاستقبال', role: StaffRole.reception),
  Staff(id: 'u2', email: 'a1@noor.com', name: 'إدارة العيادة', role: StaffRole.admin),
];

const _demoPassword = '1234';

/// الدخول بالبريد وكلمة المرور (بيانات تجريبية)
Staff? findStaff(String email, String password) {
  final e = email.trim().toLowerCase();
  if (password != _demoPassword) return null;
  for (final s in demoStaff) {
    if (s.email == e) return s;
  }
  return null;
}

// ───────── الطلب في اللوحة

/// طلب كما تشوفه العيادة (فوق بيانات السيرفر)
class DeskRequest {
  DeskRequest(this.booking);

  final Booking booking;

  String get id => booking.id;

  /// من المريض اللي في معاينة التطبيق (مستخدم هذا الجهاز)
  bool get fromApp => booking.patientId == mePatient;

  /// متى حددت العيادة الموعد (لسرعة الرد في التقارير)
  DateTime? get scheduledAt => booking.scheduledAt;

  /// اسم المريض (أو الشخص اللي انطلب له)
  String get patient {
    final b = booking;
    if (b.recipientName != null) return b.recipientName!;
    final n = b.patientName?.trim() ?? '';
    if (n.isNotEmpty) return n;
    if (fromApp && appState.name.trim().isNotEmpty) return appState.name.trim();
    return 'مستخدم التطبيق';
  }

  String get phone {
    final b = booking;
    if (b.recipientPhone != null) return b.recipientPhone!;
    final p = b.patientPhone ?? '';
    if (p.isNotEmpty) return p;
    return fromApp ? appState.phone : '';
  }

  /// ينتظر من العيادة: يحدد الموعد (أو يوافق على الباقة)
  bool get waiting => booking.status == RequestStatus.sent;

  /// مدفوع أو ما عليه مبلغ
  bool get settled => booking.paid || booking.free || booking.price == 0;
}

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

// ───────── حالة اللوحة

enum DeskPage { requests, appointments, reports, preview }

class DeskState extends ChangeNotifier {
  /// الطلبات من طبقة البيانات (تجريبية لين يتركب السيرفر)
  DeskState({ClinicRequests? requests}) : _requests = requests ?? MockClinicRequests() {
    _sync(announce: false);
    _sub = _requests.changes.listen((_) => _sync());
  }

  final ClinicRequests _requests;
  late final StreamSubscription<void> _sub;

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

  /// يرجّع false لو البيانات غلط
  bool login(String email, String password) {
    final s = findStaff(email, password);
    if (s == null) return false;
    signIn(s);
    return true;
  }

  void signIn(Staff s) {
    staff = s;
    branchFilter = null;
    page = DeskPage.requests;
    notifyListeners();
  }

  void signOut() {
    staff = null;
    notifyListeners();
  }

  /// غلاف لكل طلب (يبقى نفسه مع التحديثات)
  final Map<String, DeskRequest> _wrap = {};

  /// آخر طلب جديد وصل (يطلع تنبيه "طلب جديد")
  final arrival = ValueNotifier<DeskRequest?>(null);

  void _sync({bool announce = true}) {
    final ids = <String>{};
    for (final b in _requests.current) {
      ids.add(b.id);
      if (_wrap.containsKey(b.id)) continue;
      final r = _wrap[b.id] = DeskRequest(b);
      if (announce && r.waiting) arrival.value = r;
    }
    _wrap.removeWhere((id, _) => !ids.contains(id));
    notifyListeners();
  }

  /// كل الطلبات (بدون فلترة)
  List<DeskRequest> get all => _wrap.values.toList();

  /// اللي يشوفه الموظف الحالي (المستخدمين الاثنين يشوفون كل الفروع)
  List<DeskRequest> get visible => staff == null ? const [] : all;

  /// فلتر الفرع (null = كل الفروع)
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

  /// الطبيب مشغول في هذا الوقت؟ (للعرض بس، والسيرفر يتأكد وقت الحفظ)
  bool busy(String doctorId, DateTime at, {String? except}) => all.any((r) =>
      r.id != except &&
      r.booking.doctorId == doctorId &&
      r.booking.status == RequestStatus.scheduled &&
      r.booking.at == at);

  /// أطباء الخدمة في فرع الطلب
  List<Doctor> doctorsOf(DeskRequest r) => doctorsFor(r.booking.service, r.booking.branchId);

  // ───────── الإجراءات (كلها تنتظر السيرفر، ولو فشلت يرجع [RepoError])

  /// تحديد الموعد وإرساله للعميل (يتحدث في تطبيقه ويوصله إشعار)
  Future<void> schedule(DeskRequest r, {required DateTime at, required String doctorId}) =>
      _requests.schedule(r.id, at: at, doctorId: doctorId);

  /// موافقة على طلب باقة (بعدها يدفع المريض من التطبيق)
  Future<void> approve(DeskRequest r) => _requests.approve(r.id);

  Future<void> complete(DeskRequest r) => _requests.complete(r.id);

  Future<void> noShow(DeskRequest r) => _requests.noShow(r.id);

  Future<void> confirmPayment(DeskRequest r) => _requests.confirmPayment(r.id);

  Future<void> cancel(DeskRequest r, String reason) => _requests.cancel(r.id, reason);

  // ───────── التقارير

  /// كل الطلبات في نطاق الموظف خلال آخر [days] يوم
  List<DeskRequest> since(int days) {
    final from = appToday.subtract(Duration(days: days - 1));
    return scoped.where((r) => !r.booking.createdAt.isBefore(from)).toList();
  }

  @override
  void dispose() {
    _sub.cancel();
    arrival.dispose();
    super.dispose();
  }
}

/// يوفّر حالة اللوحة لكل الصفحات
class DeskScope extends InheritedNotifier<DeskState> {
  const DeskScope({super.key, required DeskState desk, required super.child}) : super(notifier: desk);

  static DeskState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DeskScope>()!.notifier!;
  static DeskState read(BuildContext context) => context.getInheritedWidgetOfExactType<DeskScope>()!.notifier!;
}
