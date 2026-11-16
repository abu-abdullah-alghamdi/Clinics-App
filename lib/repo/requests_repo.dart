/// طبقة البيانات للطلبات والمواعيد: التطبيق ولوحة العيادة يكلمونها، وما يكلمون البيانات مباشرة.
///
/// لها نسختين: تجريبية ([MockRequestsRepo] في mock_backend.dart) تتصرف مثل السيرفر
/// (تأخير، وأخطاء، وقواعد)، ونسخة السيرفر الحقيقي لما يتركب. التبديل بينهم ما يلمس الشاشات.
library;

import '../data.dart';

/// نوع الخطأ اللي يرجع من السيرفر
enum RepoErrorKind {
  /// ما فيه اتصال
  offline,

  /// الوقت انحجز، أو الطلب تغيّر من جهاز ثاني
  conflict,

  /// الإجراء ما يناسب حالة الطلب، أو مو من صلاحية المستخدم
  notAllowed,

  /// الطلب ما عاد موجود
  notFound,

  unknown,
}

class RepoError implements Exception {
  const RepoError(this.kind, [this.detail]);

  final RepoErrorKind kind;

  /// رسالة أوضح من السيرفر (اختيارية)
  final String? detail;

  String get title => switch (kind) {
        RepoErrorKind.offline => 'ما فيه اتصال',
        RepoErrorKind.conflict => 'تغيّر الطلب',
        RepoErrorKind.notAllowed => 'ما تقدر تسوي هذا',
        RepoErrorKind.notFound => 'الطلب غير موجود',
        RepoErrorKind.unknown => 'صار خطأ',
      };

  String get message =>
      detail ??
      switch (kind) {
        RepoErrorKind.offline => 'تأكد من اتصالك بالإنترنت وحاول مرة ثانية',
        RepoErrorKind.conflict => 'الطلب تغيّر من جهاز ثاني. شوف آخر تحديث وحاول مرة ثانية',
        RepoErrorKind.notAllowed => 'حالة الطلب تغيّرت وما عاد ينفع هذا الإجراء',
        RepoErrorKind.notFound => 'يمكن انحذف أو انلغى من جهاز ثاني',
        RepoErrorKind.unknown => 'حاول مرة ثانية بعد شوي',
      };

  @override
  String toString() => 'RepoError($kind${detail == null ? '' : ': $detail'})';
}

/// طلب جديد من المريض
class NewRequest {
  const NewRequest({
    required this.serviceId,
    required this.branchId,
    this.doctorId,
    this.period = Period.evening,
    this.packageId,
    this.userPackageId,
    this.touchUpOf,
    this.recipientName,
    this.recipientPhone,
  });

  final String serviceId;
  final String branchId;
  final String? doctorId;
  final Period period;
  final String? packageId;
  final String? userPackageId;
  final String? touchUpOf;
  final String? recipientName;
  final String? recipientPhone;
}

/// الطلبات من جهة المريض (يشوف طلباته بس)
abstract class PatientRequests {
  /// آخر نسخة من طلباته (تتحدث مع كل تغيير)
  List<Booking> get current;

  /// يتنبّه مع كل تغيير، سواء منه أو من العيادة
  Stream<void> get changes;

  /// طلب واحد
  Future<Booking> create(NewRequest r, {required String patientName, required String patientPhone});

  /// طلبات السلة: تنرسل مع بعض بمرجع واحد، وكلها أو ولا شيء
  Future<List<Booking>> createMany(List<NewRequest> list, {required String patientName, required String patientPhone});

  Future<void> cancel(String id);

  /// يدفع في الفرع بدل التطبيق
  Future<void> payLater(String id);

  /// انخصم المبلغ من التطبيق (رقم العملية من بوابة الدفع)
  Future<void> markPaid(String id, String orderNumber);

  /// باقة اندفعت وصارت في "باقاتي"
  Future<void> confirmPackage(String id);

  /// حذف الحساب: تنحذف طلباته
  Future<void> deleteAll();
}

/// الطلبات من جهة العيادة (كل المرضى)
abstract class ClinicRequests {
  List<Booking> get current;
  Stream<void> get changes;

  /// تحديد الموعد أو تعديله. يرجع خطأ conflict لو الطبيب عنده موعد بنفس الوقت
  Future<void> schedule(String id, {required DateTime at, required String doctorId});

  Future<void> approve(String id);
  Future<void> confirmPayment(String id);
  Future<void> complete(String id);
  Future<void> noShow(String id);
  Future<void> cancel(String id, String reason);
}
