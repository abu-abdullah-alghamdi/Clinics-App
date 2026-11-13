import 'package:flutter/widgets.dart';

import 'data.dart';
import 'extras.dart';
import 'native.dart';
import 'payments.dart';
import 'services_data.dart';

/// المعلومات الشخصية للمستخدم
class Profile {
  const Profile({required this.name, required this.phone});

  final String name;
  final String phone;
}

/// عنصر في عملية الدفع (خدمة أو باقة)
class OrderItem {
  const OrderItem(this.service, {this.package, int? price}) : _price = price;

  final Service service;

  /// باقة جلسات بدل الجلسة الوحدة
  final ServicePackage? package;

  /// السعر حسب الطبيب (null = سعر الخدمة)
  final int? _price;

  int get total => _price ?? package?.price ?? service.finalPrice;

  /// الاسم للعرض: الخدمة، والباقة في سطر تحتها
  String get label => package != null ? '${service.name}\n${package!.name}' : service.name;
}

/// عملية دفع من التطبيق
class Order {
  const Order({
    required this.number,
    required this.items,
    required this.branchId,
    required this.subtotal,
    required this.method,
    required this.date,
    required this.reference,
    this.cardLast4,
    this.discount = 0,
    this.coupon,
    this.recipientName,
    this.recipientPhone,
  });

  final String number;
  final List<OrderItem> items;
  final String branchId;
  final int subtotal;
  final PayMethod method;
  final DateTime date;
  final String reference;

  /// آخر 4 أرقام من البطاقة (لو الدفع ببطاقة)
  final String? cardLast4;

  /// خصم كود الخصم (بالريال) والكود نفسه
  final int discount;
  final String? coupon;

  /// الطلب لشخص ثاني: العيادة تتواصل معه وتحدد الموعد
  final String? recipientName;
  final String? recipientPhone;

  bool get forOther => recipientName != null;

  int get total => subtotal - discount;

  /// طريقة الدفع للعرض: "مدى ···· 4821"
  String get methodText => cardLast4 == null ? method.label : '${method.label} ···· $cardLast4';
}

/// حالة التطبيق العامة
class AppState extends ChangeNotifier {
  /// يبدأ بطلبات تجريبية (بعيد عن يوم الجمعة): موعد حددته العيادة، طلب مرسل، وزيارتين مكتملة
  AppState() {
    DateTime day(int offset, int hour, [int minute = 0]) {
      var o = offset;
      if (DayInfo(o).closed) o += offset < 0 ? -1 : 1;
      final d = DayInfo(o).date;
      return DateTime(d.year, d.month, d.day, hour, minute);
    }

    bookings.addAll([
      Booking(id: 'seed1', number: '2401', serviceId: 's5', branchId: 'rawdah', doctorId: 'd2', status: RequestStatus.scheduled, at: day(3, 17, 30)),
      Booking(id: 'seed2', number: '2402', serviceId: 's1', branchId: 'salamah', period: Period.morning),
      Booking(id: 'seed3', number: '2403', serviceId: 's7', branchId: 'salamah', doctorId: 'd3', userPackageId: 'seedp', status: RequestStatus.completed, at: day(-3, 18)),
      Booking(id: 'seed4', number: '2404', serviceId: 'c3', branchId: 'hamdaniyah', doctorId: 'd4', status: RequestStatus.completed, at: day(-9, 17)),
    ]);
  }

  /// يزيد مع كل تغيير (نستخدمه عشان التبويب الظاهر بس يعيد رسم نفسه)
  int version = 0;

  @override
  void notifyListeners() {
    version++;
    super.notifyListeners();
  }

  // المستخدم
  String name = '';
  String phone = '';
  bool loggedIn = false;
  bool remindOnWhatsapp = true;
  Profile? profile;

  /// الحسابات المسجلة على هذا الجهاز (للتجربة، بدل الخادم): رقم الجوال ← المعلومات
  final Map<String, Profile> _accounts = {};

  bool hasAccount(String phone) => _accounts.containsKey(phone);

  /// طلبات كل حساب (ترجع لما يسجّل دخوله مرة ثانية)
  final Map<String, List<Order>> _savedOrders = {};

  // التبويب الحالي في الشريط العائم:
  // 0 الرئيسية، 1 مواعيدي، 2 الأطباء، 3 حسابي، 4 الخدمات
  int tab = 0;

  /// عمليات الدفع من التطبيق
  final List<Order> orders = [];

  // المفضلة (تشتغل للزائر أيضاً)
  final Set<String> favDoctors = {};
  final Set<String> favServices = {};

  void toggleFavDoctor(String id) {
    if (!favDoctors.remove(id)) favDoctors.add(id);
    notifyListeners();
  }

  void toggleFavService(String id) {
    if (!favServices.remove(id)) favServices.add(id);
    notifyListeners();
  }

  final List<Booking> bookings = [];

  // ───────── الخدمات الإضافية

  /// تقييم الزيارات: رقم الموعد ← عدد النجوم
  final Map<String, int> ratings = {};

  void rateVisit(String bookingId, int stars) {
    ratings[bookingId] = stars;
    notifyListeners();
  }

  /// آخر زيارة مكتملة ما تقيّمت
  Booking? get toRate {
    for (final b in sorted) {
      if (b.status == RequestStatus.completed && !b.isPackage && !ratings.containsKey(b.id)) return b;
    }
    return null;
  }

  /// باقات الجلسات (تبدأ بباقة تجريبية عشان تبان الصفحة)
  final List<UserPackage> packages = [
    UserPackage(id: 'seedp', package: packageById('p7_6'), used: 2, expires: DateTime(appToday.year, appToday.month + 6, appToday.day)),
  ];

  UserPackage? packageOf(String? id) {
    for (final p in packages) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// طلب شغال لجلسة من الباقة (ما يطلب جلسة ثانية لين تخلص اللي قبلها)
  Booking? activeSessionOf(String userPackageId) {
    for (final b in bookings) {
      if (b.userPackageId == userPackageId && b.active) return b;
    }
    return null;
  }

  /// طلب الرتوش لجلسة ليزر (لو انطلب)
  Booking? touchUpFor(String bookingId) {
    for (final b in bookings) {
      if (b.touchUpOf == bookingId && b.status != RequestStatus.cancelled) return b;
    }
    return null;
  }

  /// الأيام الباقية لطلب الرتوش (null = ما تنطلب: مو ليزر، أو انطلبت، أو خلصت المدة)
  int? touchUpDaysLeft(Booking b) {
    final at = b.at;
    if (b.status != RequestStatus.completed || b.touchUpOf != null || at == null || !hasTouchUp(b.service)) return null;
    if (touchUpFor(b.id) != null) return null;
    final end = DateTime(at.year, at.month, at.day + touchUpDays);
    final left = (end.difference(appToday).inHours / 24).ceil();
    return left > 0 ? left : null;
  }

  /// آخر عمليات البحث
  final List<String> recentSearches = ['تبييض', 'د. فهد', 'ليزر'];

  void addRecentSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    recentSearches
      ..remove(t)
      ..insert(0, t);
    if (recentSearches.length > 6) recentSearches.removeLast();
    notifyListeners();
  }

  String get firstName {
    final parts = name.trim().split(' ');
    return parts.isEmpty ? '' : parts.first;
  }

  String get initial => firstName.isNotEmpty ? firstName.characters.first : 'أ';

  /// ترتيب "مواعيدي": المواعيد المحددة (الأقرب أول)، بعدها الطلبات المرسلة (الأحدث أول)، وبعدها السابقة (الأحدث أول)
  List<Booking> get sorted {
    int group(Booking b) => b.status == RequestStatus.scheduled ? 0 : (b.active ? 1 : 2);
    DateTime timeOf(Booking b) => b.at ?? b.createdAt;
    final list = [...bookings];
    list.sort((a, b) {
      final g = group(a).compareTo(group(b));
      if (g != 0) return g;
      return group(a) == 0 ? timeOf(a).compareTo(timeOf(b)) : timeOf(b).compareTo(timeOf(a));
    });
    return list;
  }

  /// المواعيد اللي حددتها العيادة
  List<Booking> get upcoming => sorted.where((b) => b.status == RequestStatus.scheduled).toList();

  /// الطلبات اللي تنتظر العيادة (أو موافقة الباقة)
  List<Booking> get pending => sorted.where((b) => b.status == RequestStatus.sent || b.status == RequestStatus.approved).toList();

  /// عملية الدفع للطلب (لو دفع من التطبيق)
  Order? orderFor(Booking b) {
    for (final o in orders) {
      if (o.number == b.orderNumber) return o;
    }
    return null;
  }

  /// طلب شغال لنفس الخدمة ولنفس الشخص (للتنبيه قبل الطلب المكرر)
  Booking? duplicateOf(String serviceId, {String? recipientPhone}) {
    for (final b in bookings) {
      if (b.active && b.serviceId == serviceId && b.recipientPhone == recipientPhone && b.touchUpOf == null) return b;
    }
    return null;
  }

  int get completedCount => bookings.where((b) => b.status == RequestStatus.completed && !b.isPackage).length;

  // فلتر التخصص في صفحة الأطباء
  String? doctorCat;

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  void openDoctors([String? cat]) {
    doctorCat = cat;
    tab = 2;
    notifyListeners();
  }

  void setDoctorCat(String? cat) {
    doctorCat = cat;
    notifyListeners();
  }

  // فلتر صفحة الخدمات (null = الكل)
  String? serviceCatFilter;

  void openServices([String? cat]) {
    serviceCatFilter = cat;
    tab = 4;
    notifyListeners();
  }

  void setServiceCat(String? cat) {
    serviceCatFilter = cat;
    notifyListeners();
  }

  /// دخول رقم مسجّل من قبل (يرجّع معلوماته)
  void login(String nationalNumber) {
    phone = '0$nationalNumber';
    profile = _accounts[phone];
    if (profile != null) name = profile!.name;
    orders
      ..clear()
      ..addAll(_savedOrders[phone] ?? const []);
    loggedIn = true;
    notifyListeners();
  }

  /// حفظ المعلومات الشخصية (أول تسجيل أو تعديل) وتسجيل الدخول
  void saveProfile(Profile p) {
    profile = p;
    name = p.name;
    phone = p.phone;
    _accounts[p.phone] = p;
    loggedIn = true;
    notifyListeners();
  }

  void logout() {
    if (phone.isNotEmpty) _savedOrders[phone] = [...orders];
    _signOut();
  }

  /// حذف الحساب: يمسح بيانات المستخدم ومواعيده من التطبيق
  void deleteAccount() {
    Reminders.cancelAll();
    _accounts.remove(phone);
    _savedOrders.remove(phone);
    favDoctors.clear();
    favServices.clear();
    bookings.clear();
    ratings.clear();
    packages.clear();
    recentSearches.clear();
    _signOut();
  }

  /// يرجّع التطبيق لوضع الزائر (مشتركة بين الخروج وحذف الحساب)
  void _signOut() {
    name = '';
    phone = '';
    profile = null;
    loggedIn = false;
    tab = 0;
    orders.clear();
    notifyListeners();
  }

  void toggleRemind() {
    remindOnWhatsapp = !remindOnWhatsapp;
    notifyListeners();
  }

  int _seq = 0;

  Booking _find(String id) => bookings.firstWhere((x) => x.id == id);

  /// إرسال طلب للعيادة
  Booking addRequest({
    required String serviceId,
    required String branchId,
    String? doctorId,
    Period period = Period.evening,
    String? packageId,
    String? userPackageId,
    String? touchUpOf,
    String? recipientName,
    String? recipientPhone,
  }) {
    _seq++;
    final b = Booking(
      id: 'r${DateTime.now().microsecondsSinceEpoch}$_seq',
      number: '${2404 + _seq}',
      serviceId: serviceId,
      branchId: branchId,
      doctorId: doctorId,
      period: period,
      kind: packageId != null ? RequestKind.package : RequestKind.visit,
      packageId: packageId,
      userPackageId: userPackageId,
      touchUpOf: touchUpOf,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
    );
    // جلسة الباقة تنحجز من رصيدها، وترجع لو انلغى الطلب
    final up = packageOf(userPackageId);
    if (up != null && !up.done) up.used++;
    bookings.add(b);
    notifyListeners();
    return b;
  }

  /// يلغي الطلب أو الموعد (المريض)
  void cancelRequest(String id) {
    final b = _find(id);
    _cancel(b);
    notifyListeners();
  }

  void _cancel(Booking b) {
    b.status = RequestStatus.cancelled;
    final up = packageOf(b.userPackageId);
    if (up != null && up.used > 0) up.used--;
    Reminders.cancel(b.id);
  }

  /// يدفع في الفرع بدل التطبيق (والباقة تتفعل على طول)
  void payLater(String id) {
    final b = _find(id);
    b.payLater = true;
    if (b.isPackage) _activatePackage(b);
    notifyListeners();
  }

  /// الدفع من التطبيق: عملية دفع مربوطة بالطلب (والباقة تتفعل)
  Order payRequest(
    Booking b, {
    required PayMethod method,
    required String reference,
    String? cardLast4,
    int discount = 0,
    String? coupon,
  }) {
    final o = Order(
      number: '${10240 + orders.length + 1}',
      items: [OrderItem(b.service, package: b.package, price: b.price)],
      branchId: b.branchId,
      subtotal: b.price,
      method: method,
      date: DateTime.now(),
      reference: reference,
      cardLast4: cardLast4,
      discount: discount,
      coupon: coupon,
      recipientName: b.recipientName,
      recipientPhone: b.recipientPhone,
    );
    orders.insert(0, o);
    b
      ..orderNumber = o.number
      ..payLater = false;
    if (b.isPackage && b.status == RequestStatus.approved) _activatePackage(b);
    notifyListeners();
    return o;
  }

  /// الباقة تصير في "باقاتي" ويطلع طلب أول جلسة منها
  void _activatePackage(Booking b) {
    final pkg = b.package;
    if (pkg == null) return;
    b.status = RequestStatus.completed;
    final up = UserPackage(
      id: 'up${DateTime.now().microsecondsSinceEpoch}',
      package: pkg,
      expires: DateTime(appToday.year, appToday.month + 6, appToday.day),
    );
    packages.insert(0, up);
    addRequest(serviceId: b.serviceId, branchId: b.branchId, doctorId: b.doctorId, period: b.period, userPackageId: up.id);
  }

  // ───────── لوحة العيادة (تجريبية لين تتربط لوحة التحكم)

  /// العيادة حددت الموعد (والطبيب لو كان "الطبيب المتاح")
  void clinicSchedule(String id, {required DateTime at, required String doctorId}) {
    final b = _find(id);
    b
      ..status = RequestStatus.scheduled
      ..at = at
      ..doctorId = doctorId;
    notifyListeners();
    // تذكير من الجوال قبل الموعد بساعة
    Reminders.schedule(b);
  }

  /// العيادة وافقت على طلب الباقة (بعدها يدفع)
  void clinicApprove(String id) {
    _find(id).status = RequestStatus.approved;
    notifyListeners();
  }

  /// العيادة أكدت إن المبلغ اندفع في الفرع
  void clinicConfirmPayment(String id) {
    final b = _find(id);
    b.orderNumber ??= 'branch';
    b.payLater = false;
    notifyListeners();
  }

  void clinicComplete(String id) {
    _find(id).status = RequestStatus.completed;
    Reminders.cancel(id);
    notifyListeners();
  }

  void clinicNoShow(String id) {
    _find(id).status = RequestStatus.noShow;
    Reminders.cancel(id);
    notifyListeners();
  }

  /// العيادة ألغت الطلب أو الموعد
  void cancelByClinic(String id, String reason) {
    final b = _find(id);
    b.clinicCancelReason = reason;
    _cancel(b);
    notifyListeners();
  }
}

/// يوفّر الحالة لكل الشاشات ويعيد بنائها عند التغيير
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  /// يرجّع الحالة ويعيد رسم الويدجت لما تتغير.
  /// داخل التبويبات: يعيد الرسم بس إذا التبويب ظاهر (شوف [TabScope]).
  static AppState of(BuildContext context) {
    final tab = context.dependOnInheritedWidgetOfExactType<TabScope>();
    if (tab != null) return tab.state;
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  }

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// يغلّف كل تبويب في الشريط العائم: التبويبات المخفية ما تعيد رسم نفسها مع كل تغيير،
/// وأول ما يظهر التبويب يتحدث بآخر البيانات.
class TabScope extends InheritedWidget {
  const TabScope({super.key, required this.state, required this.active, required this.version, required super.child});

  final AppState state;
  final bool active;
  final int version;

  @override
  bool updateShouldNotify(TabScope oldWidget) => active && (version != oldWidget.version || !oldWidget.active);
}
