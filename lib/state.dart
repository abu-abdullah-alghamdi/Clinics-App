import 'dart:async';

import 'package:flutter/widgets.dart';

import 'data.dart';
import 'extras.dart';
import 'native.dart';
import 'payments.dart';
import 'repo/mock_backend.dart';
import 'repo/requests_repo.dart';
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

/// خدمة (أو باقة) في السلة، والطبيب اللي اختاره لها
class CartEntry {
  CartEntry(this.serviceId, {this.packageId});

  final String serviceId;
  final String? packageId;

  /// null = الطبيب المتاح
  String? doctorId;

  Service get service => serviceById(serviceId);
  ServicePackage? get package => packageId == null ? null : packageById(packageId!);
  Doctor? get doctor => doctorId == null ? null : doctorById(doctorId!);

  /// المبلغ في الفرع المختار (الطبيب المتاح: أقل سعر)
  int priceIn(String? branchId) {
    final p = package;
    if (p != null) return p.price;
    final d = doctor;
    return d != null ? service.priceWith(d) : priceRange(service, branchId: branchId).min;
  }
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

/// إشعار وصل للمريض من العيادة (بعد الربط يجي من السيرفر)
class PatientNotice {
  PatientNotice(this.title, this.body, this.bookingId) : at = DateTime.now();
  final String title;
  final String body;
  final String bookingId;
  final DateTime at;
}

/// حالة التطبيق العامة
class AppState extends ChangeNotifier {
  /// الطلبات تجي من طبقة البيانات (تجريبية لين يتركب السيرفر)
  AppState({PatientRequests? requests}) : _requests = requests ?? MockPatientRequests() {
    _sync(announce: false);
    _sub = _requests.changes.listen((_) => _sync());
  }

  final PatientRequests _requests;
  late final StreamSubscription<void> _sub;

  @override
  void dispose() {
    _sub.cancel();
    notice.dispose();
    super.dispose();
  }

  /// آخر حالة شفناها لكل طلب (عشان نعرف وش تغيّر من العيادة)
  final Map<String, (RequestStatus, DateTime?)> _seen = {};

  /// آخر إشعار من العيادة (معاينة لوحة العيادة تعرضه مثل إشعار الجوال)
  final notice = ValueNotifier<PatientNotice?>(null);

  /// يحدّث الطلبات ويسوي اللي يلزم لما العيادة تغيّر شيء: التذكير، الإشعار، ورصيد الباقة
  void _sync({bool announce = true}) {
    final now = <String>{};
    for (final b in _requests.current) {
      now.add(b.id);
      final prev = _seen[b.id];
      _seen[b.id] = (b.status, b.at);
      if (prev == null || (prev.$1 == b.status && prev.$2 == b.at)) continue;
      switch (b.status) {
        case RequestStatus.scheduled:
          Reminders.schedule(b);
          if (announce) {
            final title = prev.$1 == RequestStatus.scheduled ? 'تغيّر موعدك' : 'تم تحديد موعدك';
            _notify(b, title, '${b.title}\n${fmtDay(b.at!)}، ${fmtClock(b.at!)}');
          }
        case RequestStatus.approved:
          if (announce) _notify(b, 'تمت الموافقة على طلبك', '${b.title}، تقدر تدفع الحين');
        case RequestStatus.cancelled:
          Reminders.cancel(b.id);
          // جلسة الباقة ترجع لرصيدها
          final up = packageOf(b.userPackageId);
          if (up != null && up.used > 0) up.used--;
          if (announce && b.cancelledByClinic) _notify(b, 'تم إلغاء طلبك', '${b.title}: ${b.clinicCancelReason}');
        case RequestStatus.completed || RequestStatus.noShow:
          Reminders.cancel(b.id);
        case RequestStatus.sent:
          break;
      }
    }
    _seen.removeWhere((id, _) => !now.contains(id));
    notifyListeners();
  }

  void _notify(Booking b, String title, String body) {
    notice.value = PatientNotice(title, body, b.id);
    // على الجوال: إشعار حقيقي بعد ثواني (بعد الربط يرسله السيرفر)
    Reminders.notifyLater('notice:${b.id}:${b.status.name}', title, body, const Duration(seconds: 5));
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

  /// طلبات المستخدم (آخر نسخة من طبقة البيانات)
  List<Booking> get bookings => _requests.current;

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

  /// حذف الحساب: يمسح بيانات المستخدم ومواعيده
  Future<void> deleteAccount() async {
    await _requests.deleteAll();
    Reminders.cancelAll();
    _accounts.remove(phone);
    _savedOrders.remove(phone);
    favDoctors.clear();
    favServices.clear();
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
    cart.clear();
    orders.clear();
    notifyListeners();
  }

  void toggleRemind() {
    remindOnWhatsapp = !remindOnWhatsapp;
    notifyListeners();
  }

  // ───────── السلة: خدمات (أو باقات) تنرسل مع بعض، وكل وحدة تصير طلب مستقل

  final List<CartEntry> cart = [];

  int get cartCount => cart.length;

  CartEntry? cartEntry(String serviceId, {String? packageId}) {
    for (final e in cart) {
      if (e.serviceId == serviceId && e.packageId == packageId) return e;
    }
    return null;
  }

  bool inCart(String serviceId, {String? packageId}) => cartEntry(serviceId, packageId: packageId) != null;

  /// يضيف للسلة (ولو موجودة ما تتكرر)
  void addToCart(String serviceId, {String? packageId}) {
    if (inCart(serviceId, packageId: packageId)) return;
    cart.add(CartEntry(serviceId, packageId: packageId));
    notifyListeners();
  }

  void removeFromCart(CartEntry e) {
    cart.remove(e);
    notifyListeners();
  }

  /// الطبيب لخدمة في السلة (null = الطبيب المتاح)
  void setCartDoctor(CartEntry e, String? doctorId) {
    e.doctorId = doctorId;
    notifyListeners();
  }

  /// يرسل كل اللي في السلة: كل خدمة طلب مستقل برقمه، وكلهم بمرجع إرسال واحد (كلها أو ولا شيء)
  Future<List<Booking>> sendCart({required String branchId, required Period period, String? recipientName, String? recipientPhone}) async {
    final sent = await _requests.createMany(
      [
        for (final e in cart)
          NewRequest(
            serviceId: e.serviceId,
            branchId: branchId,
            doctorId: e.doctorId,
            period: period,
            packageId: e.packageId,
            recipientName: recipientName,
            recipientPhone: recipientPhone,
          ),
      ],
      patientName: name,
      patientPhone: phone,
    );
    cart.clear();
    notifyListeners();
    return sent;
  }

  /// إرسال طلب للعيادة
  Future<Booking> addRequest({
    required String serviceId,
    required String branchId,
    String? doctorId,
    Period period = Period.evening,
    String? packageId,
    String? userPackageId,
    String? touchUpOf,
    String? recipientName,
    String? recipientPhone,
  }) async {
    final b = await _requests.create(
      NewRequest(
        serviceId: serviceId,
        branchId: branchId,
        doctorId: doctorId,
        period: period,
        packageId: packageId,
        userPackageId: userPackageId,
        touchUpOf: touchUpOf,
        recipientName: recipientName,
        recipientPhone: recipientPhone,
      ),
      patientName: name,
      patientPhone: phone,
    );
    // جلسة الباقة تنحجز من رصيدها، وترجع لو انلغى الطلب
    final up = packageOf(userPackageId);
    if (up != null && !up.done) up.used++;
    notifyListeners();
    return b;
  }

  /// يلغي الطلب أو الموعد (المريض). التذكير ورصيد الباقة يتعدلون مع التحديث
  Future<void> cancelRequest(String id) => _requests.cancel(id);

  /// يدفع في الفرع بدل التطبيق (والباقة تتفعل على طول)
  Future<void> payLater(String id) async {
    await _requests.payLater(id);
    final b = bookings.firstWhere((x) => x.id == id);
    if (b.isPackage) await _activatePackage(b);
  }

  /// الدفع من التطبيق: عملية دفع مربوطة بالطلب (والباقة تتفعل)
  Future<Order> payRequest(
    Booking b, {
    required PayMethod method,
    required String reference,
    String? cardLast4,
    int discount = 0,
    String? coupon,
  }) async {
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
    final approvedPackage = b.isPackage && b.status == RequestStatus.approved;
    await _requests.markPaid(b.id, o.number);
    orders.insert(0, o);
    if (approvedPackage) await _activatePackage(b);
    notifyListeners();
    return o;
  }

  /// الباقة تصير في "باقاتي" ويطلع طلب أول جلسة منها
  Future<void> _activatePackage(Booking b) async {
    final pkg = b.package;
    if (pkg == null) return;
    await _requests.confirmPackage(b.id);
    final up = UserPackage(
      id: 'up${DateTime.now().microsecondsSinceEpoch}',
      package: pkg,
      expires: DateTime(appToday.year, appToday.month + 6, appToday.day),
    );
    packages.insert(0, up);
    await addRequest(serviceId: b.serviceId, branchId: b.branchId, doctorId: b.doctorId, period: b.period, userPackageId: up.id);
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
