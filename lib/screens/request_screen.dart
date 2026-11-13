import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../extras.dart';
import '../main.dart';
import '../native.dart';
import '../services_data.dart';
import '../state.dart';
import '../states.dart';
import '../theme.dart';
import '../widgets.dart';
import 'login_gate.dart';
import 'phone_screen.dart';
import 'services_tab.dart';

/// يفتح طلب موعد كنافذة كاملة من تحت: من خدمة، أو من طبيب، أو طلب باقة، أو جلسة من باقة مدفوعة
void openRequest(BuildContext context, {Service? service, Doctor? doctor, ServicePackage? package, UserPackage? userPackage}) {
  Navigator.of(context).push(iosModal(RequestScreen(
    service: service ?? userPackage?.package.service,
    doctor: doctor,
    package: package,
    userPackage: userPackage,
  )));
}

/// طلب موعد بدون تاريخ ووقت: الخدمة ← الفرع ← الطبيب (أو الطبيب المتاح) ← الفترة.
/// العيادة تتواصل مع المريض وتحدد الموعد من لوحة التحكم
class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key, this.service, this.doctor, this.package, this.userPackage})
      : assert(service != null || doctor != null);

  final Service? service;

  /// الطلب من صفحة الطبيب: الطبيب ثابت ويختار الخدمة
  final Doctor? doctor;

  /// طلب شراء باقة جلسات
  final ServicePackage? package;

  /// جلسة من باقة مدفوعة
  final UserPackage? userPackage;

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  late Service _service;
  String? _branch;

  /// null = الطبيب المتاح
  String? _doctor;
  Period _period = Period.evening;

  bool _forOther = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _more = false;

  Doctor? get _fixed => widget.doctor;

  /// الطلب لشخص ثاني متاح للزيارات بس (مو الباقات)
  bool get _canForOther => widget.package == null && widget.userPackage == null;
  bool get _other => _forOther && _canForOther;

  @override
  void initState() {
    super.initState();
    final d = _fixed;
    final options = d == null ? const <Service>[] : servicesOf(d);
    _pickService(widget.service ?? (options.isNotEmpty ? options.first : services.first));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _pickService(Service sv) {
    _service = sv;
    final avail = branchesFor(sv, doctor: _fixed);
    if (!avail.any((b) => b.id == _branch)) _branch = avail.isNotEmpty ? avail.first.id : null;
    _pickBranch();
  }

  void _pickBranch() {
    final d = _fixed;
    if (d != null) {
      _doctor = d.id;
      return;
    }
    final docs = _branch == null ? const <Doctor>[] : doctorsFor(_service, _branch!);
    if (!docs.any((x) => x.id == _doctor)) _doctor = null;
  }

  bool get _otherReady => _name.text.trim().length >= 2 && nationalNumber(_phone.text) != null;
  bool get _ready => _branch != null && (!_other || _otherReady);

  /// المبلغ للعرض حسب الاختيار
  String get _price {
    if (widget.userPackage != null) return 'من باقتك';
    final p = widget.package;
    if (p != null) return money(p.price);
    return priceLabel(_service, doctor: _doctor == null ? null : doctorById(_doctor!), branchId: _branch);
  }

  Future<void> _send() async {
    if (!_ready) return;
    FocusScope.of(context).unfocus();
    if (!await requireLogin(context, title: 'سجّل دخولك لإرسال الطلب')) return;
    if (!mounted) return;
    final s = AppScope.read(context);
    final other = _other;
    final phone = other ? '0${nationalNumber(_phone.text)}' : null;
    // عنده طلب شغال لنفس الخدمة: يشوفه أو يرسل طلب جديد
    if (widget.userPackage == null) {
      final dup = s.duplicateOf(_service.id, recipientPhone: phone);
      if (dup != null) {
        final go = await showDuplicateSheet(context, existing: dup);
        if (!mounted) return;
        if (go == false) {
          s.setTab(1);
          Navigator.of(context).popUntil((r) => r.isFirst);
          return;
        }
        if (go != true) return;
      }
    }
    HapticFeedback.mediumImpact();
    final b = s.addRequest(
      serviceId: _service.id,
      branchId: _branch!,
      doctorId: _doctor,
      period: _period,
      packageId: widget.package?.id,
      userPackageId: widget.userPackage?.id,
      recipientName: other ? _name.text.trim() : null,
      recipientPhone: phone,
    );
    Navigator.of(context).pushReplacement(iosRoute(RequestSentScreen(request: b)));
  }

  Widget _title(String text) => px(Padding(
        padding: const EdgeInsets.fromLTRB(6, 20, 6, 10),
        child: Semantics(header: true, child: Text(text, style: ts(20, weight: FontWeight.w500))),
      ));

  Widget _input(TextEditingController c, String hint, {TextInputType? keyboard, List<String>? autofill, bool ltr = false}) => TextField(
        controller: c,
        keyboardType: keyboard,
        autofillHints: autofill,
        textDirection: ltr ? TextDirection.ltr : null,
        textAlign: TextAlign.start,
        inputFormatters: ltr ? const [WesternDigits()] : null,
        style: ts(17),
        decoration: pillInput(hint),
        onChanged: (_) => setState(() {}),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = _fixed;
    final avail = branchesFor(_service, doctor: d);
    final docs = d != null || _branch == null ? const <Doctor>[] : doctorsFor(_service, _branch!);
    final title = widget.package != null
        ? 'طلب الباقة'
        : widget.userPackage != null
            ? 'طلب جلسة'
            : 'طلب موعد';
    final price = _price;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: FloatingBar(
                title: title,
                leading: const BackCircle(close: true),
                trailing: [
                  if (d != null)
                    Builder(
                      builder: (ctx) => AppleIconButton(
                        symbol: 'square.and.arrow.up',
                        fallback: CupertinoIcons.share,
                        label: 'مشاركة الطبيب',
                        onTap: () => shareText(ctx, shareDoctorText(d)),
                      ),
                    ),
                ],
                body: ListView(
                  padding: EdgeInsets.fromLTRB(0, FloatingBar.safeTop(context) + FloatingBar.belowBar, 0, 20),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    const SizedBox(height: 14),
                    if (d != null) ...[
                      // صفحة الطبيب: البطاقة والأرقام والنبذة
                      px(CutCard(
                        image: d.image,
                        corner: FavButton(
                          active: s.favDoctors.contains(d.id),
                          name: d.name,
                          size: GlassCircle.barSize,
                          glass: true,
                          onTap: () => s.toggleFavDoctor(d.id),
                        ),
                        imageWidth: 166,
                        textWidth: 185,
                        padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),
                        children: [
                          Text('${d.n1}\n${d.n2}', style: ts(30, height: 1.2)),
                          const SizedBox(height: 6),
                          Text(d.role, style: ts(15, color: AppColors.body)),
                          const SizedBox(height: 10),
                          DoctorRatingLine(doctor: d),
                          const SizedBox(height: 12),
                          Text(d.years, style: ts(15, color: AppColors.body)),
                          const SizedBox(height: 4),
                          Text(money(_service.priceWith(d)), style: ts(26)),
                        ],
                      )),
                      const SizedBox(height: 10),
                      px(DoctorStats(doctor: d)),
                      const SizedBox(height: 10),
                      px(_about(d)),
                      _title('الخدمة'),
                      px(Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final x in servicesOf(d))
                            FilterPill(label: x.name, selected: _service.id == x.id, onTap: () => setState(() => _pickService(x))),
                        ],
                      )),
                    ] else
                      px(_ServiceSummary(service: _service, package: widget.package, userPackage: widget.userPackage)),
                    _title('الفرع'),
                    px(Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final b in avail)
                          FilterPill(
                            label: b.name,
                            selected: _branch == b.id,
                            onTap: () => setState(() {
                              _branch = b.id;
                              _pickBranch();
                            }),
                          ),
                      ],
                    )),
                    if (d == null) ...[
                      _title('الطبيب'),
                      px(_Choice(
                        leading: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                          child: const Icon(CupertinoIcons.person_2_fill, size: 24, color: AppColors.onAccent),
                        ),
                        title: 'الطبيب المتاح',
                        trailing: widget.userPackage != null || widget.package != null ? null : priceLabel(_service, branchId: _branch),
                        selected: _doctor == null,
                        onTap: () => setState(() => _doctor = null),
                      )),
                      for (final x in docs)
                        px(Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _Choice(
                            leading: DoctorAvatar(doctor: x, size: 52),
                            title: x.name,
                            subtitle: x.role,
                            trailing: widget.userPackage != null || widget.package != null ? null : money(_service.priceWith(x)),
                            selected: _doctor == x.id,
                            onTap: () => setState(() => _doctor = x.id),
                          ),
                        )),
                    ],
                    _title('الفترة'),
                    px(SegmentedPill(
                      options: [for (final p in Period.values) p.label],
                      selected: _period.index,
                      onChanged: (i) => setState(() => _period = Period.values[i]),
                    )),
                    if (_canForOther) ...[
                      _title('الطلب لـ'),
                      px(SegmentedPill(
                        options: const ['لي', 'لشخص ثاني'],
                        selected: _forOther ? 1 : 0,
                        onChanged: (i) => setState(() => _forOther = i == 1),
                      )),
                      if (_forOther) ...[
                        const SizedBox(height: 10),
                        px(_input(_name, 'الاسم', keyboard: TextInputType.name, autofill: const [AutofillHints.name])),
                        const SizedBox(height: 8),
                        px(_input(_phone, '05x xxx xxxx', keyboard: TextInputType.phone, ltr: true)),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            BottomAction(
              price: widget.userPackage != null ? null : price,
              child: PillButton(
                label: 'إرسال الطلب',
                height: 50,
                fontSize: 17,
                enabled: _ready,
                onTap: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _about(Doctor d) {
    final about = _more || d.about.length <= 95 ? d.about : '${d.about.substring(0, 95)}…';
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('عن الطبيب', style: ts(20, weight: FontWeight.w500)),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: motion(context, 250),
            alignment: Alignment.topCenter,
            child: Text(about, style: ts(14, color: AppColors.body, height: 1.85)),
          ),
          GestureDetector(
            onTap: () => setState(() => _more = !_more),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_more ? 'عرض أقل' : 'اقرأ المزيد', style: ts(15, weight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// ملخص الخدمة أعلى الطلب: الصورة والاسم والتقييم (أو الباقة)
class _ServiceSummary extends StatelessWidget {
  const _ServiceSummary({required this.service, this.package, this.userPackage});

  final Service service;
  final ServicePackage? package;
  final UserPackage? userPackage;

  @override
  Widget build(BuildContext context) {
    final sv = service;
    final up = userPackage;
    final sub = package != null
        ? package!.name
        : up != null
            ? '${up.package.name}\nالجلسة ${fmtNum(up.used + 1)}'
            : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(32)),
      child: Row(
        children: [
          ServiceImage(service: sv, size: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sv.name, style: ts(20, weight: FontWeight.w600)),
                if (sub != null) Text(sub, style: ts(14, color: AppColors.body)),
                const SizedBox(height: 4),
                Semantics(
                  label: 'التقييم ${sv.ratingText} من 5، ${fmtNum(sv.reviews)} تقييم',
                  child: ExcludeSemantics(child: RatingRow(rating: sv.ratingText, reviews: sv.reviews)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// خيار في قائمة (الطبيب المتاح أو طبيب معيّن): صورة، اسم، سطر، المبلغ، ودائرة الاختيار
class _Choice extends StatelessWidget {
  const _Choice({required this.leading, required this.title, this.subtitle, this.trailing, required this.selected, required this.onTap});

  final Widget leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: [title, if (subtitle != null) subtitle!, if (trailing != null) trailing!].join('، '),
        child: AnimatedContainer(
          duration: motion(context, 200),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 16, 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.ink : Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              ExcludeSemantics(child: leading),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ts(16, weight: FontWeight.w600)),
                    if (subtitle != null) Text(subtitle!, style: ts(13, color: AppColors.body)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                Text(trailing!, style: ts(14, weight: FontWeight.w600)),
                const SizedBox(width: 10),
              ],
              SelectDot(selected: selected),
            ],
          ),
        ),
      );
}

/// النجمة والتقييم وعدد التقييمات تحت اسم الطبيب
class DoctorRatingLine extends StatelessWidget {
  const DoctorRatingLine({super.key, required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'التقييم ${doctor.ratingText} من 5، ${fmtNum(doctor.reviews)} تقييم',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 22, color: Color(0xFFFFC107)),
              const SizedBox(width: 4),
              Text(doctor.ratingText, style: ts(16, weight: FontWeight.w600)),
              const SizedBox(width: 4),
              Flexible(child: Text('(${fmtNum(doctor.reviews)} تقييم)', style: ts(14, color: AppColors.body))),
            ],
          ),
        ),
      );
}

/// صف الأرقام: المرضى، سنوات الخبرة، التقييم، التقييمات
class DoctorStats extends StatelessWidget {
  const DoctorStats({super.key, required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.person_rounded, '${fmtNum(doctor.patients)}+', 'المرضى', '${fmtNum(doctor.patients)} مريض وأكثر'),
      (Icons.verified_rounded, '${fmtNum(doctor.yearsCount)}+', 'سنوات الخبرة', '${fmtNum(doctor.yearsCount)} سنوات خبرة وأكثر'),
      (Icons.star_rounded, doctor.ratingText, 'التقييم', 'التقييم ${doctor.ratingText}'),
      (Icons.chat_bubble_rounded, '${fmtNum(doctor.reviews)}+', 'التقييمات', '${fmtNum(doctor.reviews)} تقييم وأكثر'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 22, 10, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(40),
        border: highContrast(context) ? Border.all(color: AppColors.ink, width: 1.5) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, value, label, spoken) in items)
            Expanded(
              child: Semantics(
                label: spoken,
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        child: Icon(icon, size: 28, color: AppColors.onAccent),
                      ),
                      const SizedBox(height: 10),
                      Text(value, textDirection: TextDirection.ltr, textAlign: TextAlign.center, style: ts(20, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(label, textAlign: TextAlign.center, maxLines: 2, style: ts(13, color: AppColors.body, height: 1.4)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// طلب الرتوش لجلسة ليزر مكتملة: يختار الفترة ويرسل (نفس الطبيب والفرع، بدون مبلغ)
Future<void> requestTouchUp(BuildContext context, Booking session) async {
  if (!await requireLogin(context, title: 'سجّل دخولك لإرسال الطلب')) return;
  if (!context.mounted) return;
  final s = AppScope.read(context);
  var period = session.period;
  final sent = await showGlassSheet<Booking>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text('رتوش ${session.service.name}', style: ts(22, weight: FontWeight.w500))),
            Text('${session.branch.name}${withDoctor(session)}', style: ts(14, color: AppColors.faint)),
            const SizedBox(height: 16),
            Text('الفترة', style: ts(16, weight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(999)),
              child: SegmentedPill(
                options: [for (final p in Period.values) p.label],
                selected: period.index,
                onChanged: (i) => setSheet(() => period = Period.values[i]),
              ),
            ),
            const SizedBox(height: 16),
            PillButton(
              label: 'إرسال الطلب',
              height: 50,
              fontSize: 17,
              onTap: () {
                HapticFeedback.mediumImpact();
                final b = s.addRequest(
                  serviceId: session.serviceId,
                  branchId: session.branchId,
                  doctorId: session.doctorId,
                  period: period,
                  touchUpOf: session.id,
                );
                Navigator.of(ctx).pop(b);
              },
            ),
          ],
        ),
      ),
    ),
  );
  if (sent != null && context.mounted) Navigator.of(context).push(iosRoute(RequestSentScreen(request: sent)));
}

/// تم إرسال الطلب: العيادة تتواصل مع المريض وتحدد الموعد
class RequestSentScreen extends StatefulWidget {
  const RequestSentScreen({super.key, required this.request});

  final Booking request;

  @override
  State<RequestSentScreen> createState() => _RequestSentScreenState();
}

class _RequestSentScreenState extends State<RequestSentScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  void _goTab(int tab) {
    AppScope.read(context).setTab(tab);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.request;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: motion(context, 600),
                              curve: Curves.elasticOut,
                              builder: (context, v, child) => Transform.scale(scale: 0.4 + 0.6 * v, child: child),
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded, size: 60, color: AppColors.onAccent),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Semantics(
                            header: true,
                            child: Text('تم إرسال طلبك بنجاح إلى العيادة', textAlign: TextAlign.center, style: ts(28, height: 1.3)),
                          ),
                          const SizedBox(height: 6),
                          Text('سيتم التواصل معك', textAlign: TextAlign.center, style: ts(17, color: AppColors.body)),
                          const SizedBox(height: 22),
                          receiptCard([
                            receiptRow('الطلب', b.title),
                            if (b.packageName != null) receiptRow('الباقة', b.packageName!),
                            receiptRow('الطبيب', b.doctor?.name ?? 'الطبيب المتاح'),
                            receiptRow('الفرع', b.branch.name),
                            receiptRow('الفترة', b.period.label),
                            if (b.forOther) receiptRow('لـ', b.recipientName!),
                            receiptRow('المبلغ', b.priceText),
                            receiptRow('رقم الطلب', '#${b.number}'),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PillButton(label: 'عرض مواعيدي', height: 50, onTap: () => _goTab(1)),
                const SizedBox(height: 10),
                PillButton(label: 'الرئيسية', height: 50, bg: AppColors.white, weight: FontWeight.w400, onTap: () => _goTab(0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
