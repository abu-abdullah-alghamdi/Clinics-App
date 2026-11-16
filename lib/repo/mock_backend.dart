/// السيرفر التجريبي: قاعدة بيانات في الذاكرة بنفس قواعد السيرفر الحقيقي
///
/// كل عملية تاخذ وقت مثل الشبكة، وتفشل لو "الاتصال مقطوع" ([MockBackend.offline])،
/// وتتأكد من حالة الطلب قبل ما تغيّره (مثل السيرفر بالضبط). التطبيق ولوحة العيادة
/// يشوفون نفس البيانات، فأي تغيير من وحدة يوصل للثانية لحظياً.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data.dart';
import '../services_data.dart';
import 'requests_repo.dart';

/// مستخدم هذا الجهاز (لين يتربط السيرفر بحساب المريض)
const mePatient = 'me';

class MockBackend {
  MockBackend._() {
    _seedMine();
    _seedClinic();
  }

  static final instance = MockBackend._();

  /// تأخير الشبكة لكل عملية (صفر في الاختبارات)
  static Duration latency = const Duration(milliseconds: 450);

  /// محاكاة انقطاع الاتصال (من معاينة الحالات)
  static final offline = ValueNotifier<bool>(false);

  final List<Booking> _rows = [];

  // متزامن: التطبيق واللوحة يتحدثون قبل ما ترجع العملية
  final _changes = StreamController<void>.broadcast(sync: true);

  Stream<void> get changes => _changes.stream;
  List<Booking> get rows => List.unmodifiable(_rows);

  int _seq = 4;
  int _groupSeq = 0;

  /// كل عملية: تأخير الشبكة، ثم الاتصال، ثم التنفيذ، ثم تنبيه الكل
  Future<T> _call<T>(T Function() op) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (offline.value) throw const RepoError(RepoErrorKind.offline);
    final result = op();
    _changes.add(null);
    return result;
  }

  Booking _find(String id, {String? patient}) {
    for (final b in _rows) {
      if (b.id == id && (patient == null || b.patientId == patient)) return b;
    }
    throw const RepoError(RepoErrorKind.notFound);
  }

  void _require(bool ok, [String? detail]) {
    if (!ok) throw RepoError(RepoErrorKind.notAllowed, detail);
  }

  // ───────── المريض

  Booking _create(NewRequest r, String patient, String name, String phone, {String? groupRef}) {
    final sv = services.where((s) => s.id == r.serviceId).firstOrNull;
    _require(sv != null, 'الخدمة غير متاحة');
    _require(branchesFor(sv!).any((b) => b.id == r.branchId), 'الخدمة غير متاحة في هذا الفرع');
    if (r.doctorId != null) _require(doctorsFor(sv, r.branchId).any((d) => d.id == r.doctorId), 'الطبيب ما يقدم الخدمة في هذا الفرع');
    final b = Booking(
      id: 'r${DateTime.now().microsecondsSinceEpoch}${++_seq}',
      number: requestNumber(_seq),
      groupRef: groupRef,
      serviceId: r.serviceId,
      branchId: r.branchId,
      doctorId: r.doctorId,
      period: r.period,
      kind: r.packageId != null ? RequestKind.package : RequestKind.visit,
      packageId: r.packageId,
      userPackageId: r.userPackageId,
      touchUpOf: r.touchUpOf,
      recipientName: r.recipientName,
      recipientPhone: r.recipientPhone,
      patientId: patient,
      patientName: name,
      patientPhone: phone,
    );
    _rows.add(b);
    return b;
  }

  Future<Booking> create(NewRequest r, String patient, String name, String phone) => _call(() => _create(r, patient, name, phone));

  Future<List<Booking>> createMany(List<NewRequest> list, String patient, String name, String phone) => _call(() {
        _require(list.isNotEmpty);
        final group = list.length > 1 ? groupNumber(++_groupSeq) : null;
        final made = <Booking>[];
        try {
          for (final r in list) {
            made.add(_create(r, patient, name, phone, groupRef: group));
          }
        } catch (_) {
          // كلها أو ولا شيء
          _rows.removeWhere(made.contains);
          rethrow;
        }
        return made;
      });

  Future<void> cancelByPatient(String id, String patient) => _call(() {
        final b = _find(id, patient: patient);
        _require(b.active);
        b.status = RequestStatus.cancelled;
      });

  Future<void> payLater(String id, String patient) => _call(() {
        final b = _find(id, patient: patient);
        _require(b.active && !b.paid && !b.free);
        b.payLater = true;
      });

  Future<void> markPaid(String id, String patient, String orderNumber) => _call(() {
        final b = _find(id, patient: patient);
        _require(b.status != RequestStatus.cancelled && !b.paid);
        b
          ..orderNumber = orderNumber
          ..payLater = false;
      });

  Future<void> confirmPackage(String id, String patient) => _call(() {
        final b = _find(id, patient: patient);
        _require(b.isPackage && (b.status == RequestStatus.approved || b.status == RequestStatus.sent));
        b.status = RequestStatus.completed;
      });

  Future<void> deleteAll(String patient) => _call(() => _rows.removeWhere((b) => b.patientId == patient));

  // ───────── العيادة

  /// الطبيب عنده موعد مؤكد بنفس الوقت
  bool busy(String doctorId, DateTime at, {String? except}) =>
      _rows.any((b) => b.id != except && b.doctorId == doctorId && b.status == RequestStatus.scheduled && b.at == at);

  Future<void> schedule(String id, DateTime at, String doctorId) => _call(() {
        final b = _find(id);
        _require(b.status == RequestStatus.sent || b.status == RequestStatus.scheduled);
        _require(!b.isPackage, 'طلب الباقة يحتاج موافقة بدل الموعد');
        _require(doctorsFor(b.service, b.branchId).any((d) => d.id == doctorId), 'الطبيب ما يقدم الخدمة في هذا الفرع');
        if (busy(doctorId, at, except: id)) {
          throw const RepoError(RepoErrorKind.conflict, 'الطبيب عنده موعد ثاني بنفس الوقت. اختر وقت ثاني');
        }
        b
          ..status = RequestStatus.scheduled
          ..at = at
          ..doctorId = doctorId
          ..scheduledAt ??= DateTime.now();
      });

  Future<void> approve(String id) => _call(() {
        final b = _find(id);
        _require(b.isPackage && b.status == RequestStatus.sent);
        b
          ..status = RequestStatus.approved
          ..scheduledAt ??= DateTime.now();
      });

  Future<void> confirmPayment(String id) => _call(() {
        final b = _find(id);
        _require(b.status != RequestStatus.cancelled && !b.paid && !b.free);
        b
          ..orderNumber = 'branch'
          ..payLater = false;
      });

  Future<void> complete(String id) => _call(() {
        final b = _find(id);
        _require(b.status == RequestStatus.scheduled);
        b.status = RequestStatus.completed;
      });

  Future<void> noShow(String id) => _call(() {
        final b = _find(id);
        _require(b.status == RequestStatus.scheduled);
        b.status = RequestStatus.noShow;
      });

  Future<void> cancelByClinic(String id, String reason) => _call(() {
        final b = _find(id);
        _require(b.active);
        _require(reason.trim().isNotEmpty, 'اكتب سبب الإلغاء');
        b
          ..clinicCancelReason = reason.trim()
          ..status = RequestStatus.cancelled;
      });

  // ───────── بيانات تجريبية

  /// طلبات مستخدم الجهاز (بعيد عن يوم الجمعة): موعد حددته العيادة، طلب مرسل، وزيارتين مكتملة
  void _seedMine() {
    DateTime day(int offset, int hour, [int minute = 0]) {
      var o = offset;
      if (DayInfo(o).closed) o += offset < 0 ? -1 : 1;
      final d = DayInfo(o).date;
      return DateTime(d.year, d.month, d.day, hour, minute);
    }

    _rows.addAll([
      Booking(id: 'seed1', number: requestNumber(1), serviceId: 's5', branchId: 'rawdah', doctorId: 'd2', status: RequestStatus.scheduled, at: day(3, 17, 30)),
      Booking(id: 'seed2', number: requestNumber(2), serviceId: 's1', branchId: 'salamah', period: Period.morning),
      Booking(id: 'seed3', number: requestNumber(3), serviceId: 's7', branchId: 'salamah', doctorId: 'd3', userPackageId: 'seedp', status: RequestStatus.completed, at: day(-3, 18)),
      Booking(id: 'seed4', number: requestNumber(4), serviceId: 'c3', branchId: 'hamdaniyah', doctorId: 'd4', status: RequestStatus.completed, at: day(-9, 17)),
    ]);
  }

  /// مرضى ثانيين بطلبات ومواعيد على آخر شهر والأيام الجاية (تشوفهم العيادة)
  void _seedClinic() {
    final rnd = Random(11);
    const names = [
      'نوف الشهري', 'عبدالله القرني', 'هيا المطيري', 'خالد الدوسري', 'لمى الزهراني', 'فيصل العنزي',
      'جود الحارثي', 'تركي السبيعي', 'شهد البقمي', 'ماجد الشمري', 'رهف الغامدي', 'سعود العتيبي',
      'دانة القحطاني', 'بندر الحربي', 'غلا الجهني', 'عمر باوزير', 'ريناد الأحمدي', 'نواف المالكي',
      'أسيل بخاري', 'يزيد الثبيتي', 'لين الصاعدي', 'مشاري العمري', 'سديم الرشيدي', 'حمد الشهراني',
    ];
    var seq = 100;
    var n = 0;

    Booking make({
      required DateTime created,
      required RequestStatus status,
      DateTime? at,
      int? responseMinutes,
      bool paid = false,
      bool payLater = false,
    }) {
      final sv = services[rnd.nextInt(services.length)];
      final branchesOk = branchesFor(sv);
      final br = branchesOk[rnd.nextInt(branchesOk.length)];
      final docs = doctorsFor(sv, br.id);
      final doc = rnd.nextInt(3) == 0 ? null : docs[rnd.nextInt(docs.length)];
      final p = n++;
      final b = Booking(
        id: 'm$p',
        number: requestNumber(++seq, created),
        serviceId: sv.id,
        branchId: br.id,
        doctorId: status == RequestStatus.sent ? doc?.id : (doc ?? docs.first).id,
        period: Period.values[rnd.nextInt(3)],
        status: status,
        at: at,
        createdAt: created,
        patientId: 'p$p',
        patientName: names[p % names.length],
        patientPhone: '+9665${10000000 + rnd.nextInt(89999999)}',
        scheduledAt: responseMinutes == null ? null : created.add(Duration(minutes: responseMinutes)),
      );
      if (paid) b.orderNumber = 'O-$seq';
      b.payLater = payLater;
      return b;
    }

    DateTime createdOn(int dayOffset) =>
        DateTime(appToday.year, appToday.month, appToday.day + dayOffset, 9 + rnd.nextInt(12), rnd.nextInt(60));

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
        final b = make(
          created: createdOn(d - 1 - rnd.nextInt(2)),
          status: status,
          at: slot(d, Period.values[rnd.nextInt(3)]),
          responseMinutes: 4 + rnd.nextInt(170),
          paid: status == RequestStatus.completed && rnd.nextBool(),
        );
        if (status == RequestStatus.completed && !b.paid) b.orderNumber = 'branch';
        if (status == RequestStatus.cancelled) b.clinicCancelReason = 'طلب المريض الإلغاء';
        _rows.add(b);
      }
    }

    // القادمة: مواعيد محددة اليوم والأيام الجاية (بدون موعدين لنفس الطبيب بنفس الوقت)
    for (var d = 0; d < 6; d++) {
      final count = d == 0 ? 5 : 2 + rnd.nextInt(3);
      for (var i = 0; i < count; i++) {
        final b = make(
          created: createdOn(d - 1 - rnd.nextInt(2)),
          status: RequestStatus.scheduled,
          at: slot(d, Period.values[rnd.nextInt(3)]),
          responseMinutes: 5 + rnd.nextInt(90),
          paid: rnd.nextInt(3) == 0,
          payLater: rnd.nextBool(),
        );
        if (!busy(b.doctorId!, b.at!)) _rows.add(b);
      }
    }

    // الجديدة: تنتظر تحديد موعد
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      _rows.add(make(created: now.subtract(Duration(minutes: 3 + i * i * 9 + rnd.nextInt(6))), status: RequestStatus.sent));
    }
  }
}

/// طلبات المريض من السيرفر التجريبي
class MockPatientRequests implements PatientRequests {
  MockPatientRequests([this.patient = mePatient]);

  final String patient;
  MockBackend get _db => MockBackend.instance;

  @override
  List<Booking> get current => _db.rows.where((b) => b.patientId == patient).toList();

  @override
  Stream<void> get changes => _db.changes;

  @override
  Future<Booking> create(NewRequest r, {required String patientName, required String patientPhone}) =>
      _db.create(r, patient, patientName, patientPhone);

  @override
  Future<List<Booking>> createMany(List<NewRequest> list, {required String patientName, required String patientPhone}) =>
      _db.createMany(list, patient, patientName, patientPhone);

  @override
  Future<void> cancel(String id) => _db.cancelByPatient(id, patient);

  @override
  Future<void> payLater(String id) => _db.payLater(id, patient);

  @override
  Future<void> markPaid(String id, String orderNumber) => _db.markPaid(id, patient, orderNumber);

  @override
  Future<void> confirmPackage(String id) => _db.confirmPackage(id, patient);

  @override
  Future<void> deleteAll() => _db.deleteAll(patient);
}

/// طلبات كل المرضى (لوحة العيادة) من السيرفر التجريبي
class MockClinicRequests implements ClinicRequests {
  MockBackend get _db => MockBackend.instance;

  @override
  List<Booking> get current => _db.rows;

  @override
  Stream<void> get changes => _db.changes;

  @override
  Future<void> schedule(String id, {required DateTime at, required String doctorId}) => _db.schedule(id, at, doctorId);

  @override
  Future<void> approve(String id) => _db.approve(id);

  @override
  Future<void> confirmPayment(String id) => _db.confirmPayment(id);

  @override
  Future<void> complete(String id) => _db.complete(id);

  @override
  Future<void> noShow(String id) => _db.noShow(id);

  @override
  Future<void> cancel(String id, String reason) => _db.cancelByClinic(id, reason);
}
