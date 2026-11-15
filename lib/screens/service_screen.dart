import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../extras.dart';
import '../main.dart';
import '../native.dart';
import '../pay_widgets.dart';
import '../services_data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart_screen.dart';
import 'request_screen.dart';
import 'services_tab.dart';

/// خدمة في البطاقات: الخدمة، والباقة المختارة لها (لو جاية من قسم الباقات)
typedef ServiceItem = ({Service service, ServicePackage? package});

/// يفتح بطاقة الخدمة من تحت، ويقدر يسحب يمين ويسار بين خدمات القائمة بنفس ترتيبها
void openServiceSheet(BuildContext context, List<ServiceItem> items, int index) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: const Color(0x73000000),
    barrierLabel: 'إغلاق',
    transitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 420),
    reverseTransitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => ServicePager(items: items, index: index),
    transitionsBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
      child: child,
    ),
  ));
}

/// يفتح خدمة وحدة (من البحث والمفضلة والرئيسية)
void openService(BuildContext context, Service sv, {List<Service>? among}) {
  final list = among != null && among.any((x) => x.id == sv.id) ? among : [sv];
  openServiceSheet(context, [for (final x in list) (service: x, package: null)], list.indexWhere((x) => x.id == sv.id));
}

/// بطاقات الخدمات: كل خدمة بطاقة، والبطاقة اللي جنبها يبان طرفها، والسحب يبدّل بينهم
class ServicePager extends StatefulWidget {
  const ServicePager({super.key, required this.items, required this.index});

  final List<ServiceItem> items;
  final int index;

  @override
  State<ServicePager> createState() => _ServicePagerState();
}

class _ServicePagerState extends State<ServicePager> {
  /// عرض الصفحة أقل من الشاشة بهامش البطاقة، فالبطاقات اللي جنبها يبان طرفها فعلاً
  PageController? _controller;
  PageController get _pages => _controller!;

  /// كم نزل المستخدم في كل بطاقة (0 = بطاقة، 1 = ملء الشاشة)
  late final ValueNotifier<List<double>> _progress = ValueNotifier(List.filled(widget.items.length, 0.0));

  /// كم انسحبت كل بطاقة لتحت بالإصبع
  late final ValueNotifier<List<double>> _drags = ValueNotifier(List.filled(widget.items.length, 0.0));

  /// هامش البطاقة من الجنب، وكم يبان من البطاقة اللي جنبها، وحجم اللي جنبها
  static const _side = 15.0;
  static const _peek = 10.0;
  static const _neighborScale = 0.93;

  /// وقت السحب لتحت: التبديل يمين ويسار يتوقف، والبطاقة ترجع مكانها بالضبط عشان تنزل بخط مستوي
  bool _locked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final width = MediaQuery.sizeOf(context).width;
      _controller = PageController(initialPage: widget.index, viewportFraction: (width - _side * 2) / width);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _progress.dispose();
    _drags.dispose();
    super.dispose();
  }

  void _setProgress(int i, double v) {
    final list = _progress.value;
    if ((list[i] - v).abs() < 0.002) return;
    _progress.value = [...list]..[i] = v;
  }

  void _setDrag(int i, double v) {
    final list = _drags.value;
    if (list[i] == v) return;
    _drags.value = [...list]..[i] = v;
  }

  void _setLocked(bool v) {
    if (v == _locked) return;
    setState(() => _locked = v);
    if (v && _pages.hasClients) {
      final p = _pages.page;
      if (p != null && p != p.roundToDouble()) _pages.jumpToPage(p.round());
    }
  }

  double get _page =>
      _pages.hasClients && _pages.position.haveDimensions ? (_pages.page ?? widget.index.toDouble()) : widget.index.toDouble();

  /// خدمة من "خدمات مقترحة لك": لو موجودة في البطاقات ينتقل لها، وإلا يفتح بطاقاتها فوق
  void _open(List<Service> list, int i) {
    final target = list[i];
    final at = widget.items.indexWhere((x) => x.service.id == target.id && x.package == null);
    if (at >= 0 && !MediaQuery.disableAnimationsOf(context)) {
      _pages.animateToPage(at, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else if (at >= 0) {
      _pages.jumpToPage(at);
    } else {
      openServiceSheet(context, [for (final x in list) (service: x, package: null)], i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;
    final pageW = width - _side * 2;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final n = widget.items.length;
    // البطاقة اللي جنبها تصغر من النص، فطرفها يبعد بهالمقدار
    final shrink = pageW * (1 - _neighborScale) / 2;
    final inward = shrink + _peek - _side;

    return Stack(
      children: [
        PageView.builder(
          controller: _pages,
          physics: _locked ? const NeverScrollableScrollPhysics() : null,
          allowImplicitScrolling: true,
          itemCount: n,
          itemBuilder: (context, i) => AnimatedBuilder(
            animation: Listenable.merge([_pages, _progress, _drags]),
            child: ServiceScreen(
              service: widget.items[i].service,
              package: widget.items[i].package,
              onOpen: _open,
              onProgress: (v) => _setProgress(i, v),
              onDrag: (v) => _setDrag(i, v),
              onDragging: _setLocked,
              showButtons: false,
            ),
            builder: (context, child) {
              final page = _page;
              final d = i - page;
              final near = (1 - d.abs()).clamp(0.0, 1.0);
              final current = page.round().clamp(0, n - 1);
              // البطاقة الحالية لما ينزل فيها تكبر لين تملأ الشاشة، واللي جنبها تبعد وتختفي
              final q = _progress.value[current];
              final e = _progress.value[i] * near;
              final gap = (top + 4) * (1 - e);
              final radius = 34 * (1 - e);
              final pull = inward * (1 - q) - (_side + 4) * q;
              final dx = -d * pull * (rtl ? -1 : 1);
              final scale = 1 - d.abs().clamp(0.0, 1.0) * (1 - _neighborScale);
              // السحب لتحت بالإصبع: كل البطاقات تنزل مع بعض بخط مستوي
              final drag = _drags.value[current];
              return Transform.translate(
                offset: Offset(dx, drag),
                child: Transform.scale(
                  scale: scale,
                  child: OverflowBox(
                    minWidth: pageW + _side * 2 * e,
                    maxWidth: pageW + _side * 2 * e,
                    child: Padding(
                      padding: EdgeInsets.only(top: gap),
                      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // أزرار آبل الثابتة فوق البطاقة الحالية: الرجوع، والمفضلة والمشاركة مع بعض
        AnimatedBuilder(
          animation: Listenable.merge([_pages, _progress, _drags]),
          builder: (context, _) {
            final current = _page.round().clamp(0, n - 1);
            final q = _progress.value[current];
            return Positioned(
              top: top + 18 - 10 * q + _drags.value[current],
              left: _side * (1 - q) + 14,
              right: _side * (1 - q) + 14,
              child: ServiceButtons(service: widget.items[current].service, native: q < 0.35),
            );
          },
        ),
      ],
    );
  }
}

/// أزرار بطاقة الخدمة من آبل: الرجوع (إغلاق)، والمفضلة والمشاركة في قطعة زجاج وحدة
class ServiceButtons extends StatelessWidget {
  const ServiceButtons({super.key, required this.service, this.onClose, this.native = true});

  final Service service;
  final VoidCallback? onClose;

  /// أزرار آبل الأصلية. فوق الشريط المغبّش ترجع مرسومة من التطبيق، لأن زر آبل فوق
  /// تغبيش التطبيق كان يطلع وراه مربع فاضي
  final bool native;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final sv = service;
    final fav = s.favServices.contains(sv.id);
    return Row(
      children: [
        BackCircle(close: true, onTap: onClose, native: native),
        const Spacer(),
        Builder(
          builder: (ctx) => AppleButtonGroup(
            id: 'service-${sv.id}',
            native: native,
            buttons: [
              AppleIconButton(
                symbol: fav ? 'heart.fill' : 'heart',
                fallback: fav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                label: fav ? 'إزالة ${sv.name} من المفضلة' : 'إضافة ${sv.name} للمفضلة',
                iconColor: fav ? AppColors.red : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  s.toggleFavService(sv.id);
                },
              ),
              AppleIconButton(
                symbol: 'square.and.arrow.up',
                fallback: CupertinoIcons.share,
                label: 'مشاركة الخدمة',
                onTap: () => shareText(ctx, shareServiceText(sv)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// بطاقة الخدمة: الصورة وأزرارها، الاسم، التوفر، التقييم، الباقات، النبذة، التقييمات،
/// الخدمات المقترحة، والطلب والسلة تحت
class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key, required this.service, this.package, this.onOpen, this.onProgress, this.onDrag, this.onDragging, this.showButtons = true});

  final Service service;

  /// الباقة المختارة من البداية
  final ServicePackage? package;

  /// فتح خدمة من "خدمات مقترحة لك"
  final void Function(List<Service> list, int index)? onOpen;

  /// كم نزل في البطاقة (0 إلى 1): البطاقة تكبر معه لين تملأ الشاشة
  final ValueChanged<double>? onProgress;

  /// كم انسحبت البطاقة لتحت بالإصبع (بالنقاط)، عشان اللي يعرضها يحركها
  final ValueChanged<double>? onDrag;

  /// بدأ السحب لتحت أو خلص (عشان يوقف التبديل يمين ويسار وقت السحب)
  final ValueChanged<bool>? onDragging;

  /// أزرار الرجوع والمفضلة والمشاركة (البطاقات المتبدّلة ترسمها مرة وحدة فوقها بدل كل بطاقة)
  final bool showButtons;

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> with SingleTickerProviderStateMixin {
  bool _more = false;

  /// الباقة المختارة (null = جلسة وحدة)
  late ServicePackage? _pkg = widget.package;

  /// فلتر "خدمات مقترحة لك" (null = الكل)
  String? _suggestCat;

  /// السحب لتحت من أعلى البطاقة يقفلها (مرة وحدة)
  bool _closing = false;

  final _scroll = ScrollController();

  // ───────── سحب البطاقة لتحت مع الإصبع (مثل آبل): تمشي معه، وتوقف لما يوقف،
  // ولما يرفع إصبعه: لو نزلت كفاية أو سحب بسرعة تقفل، وإلا ترجع مكانها

  double _drag = 0;
  bool _dragging = false;
  bool _decided = false;
  Offset? _downAt;
  VelocityTracker? _velocity;
  late final AnimationController _settle = AnimationController.unbounded(vsync: this)
    ..addListener(() => _setDrag(_settle.value));

  void _setDrag(double v) {
    _drag = v < 0 ? 0 : v;
    widget.onDrag?.call(_drag);
  }

  void _pointerDown(PointerDownEvent e) {
    _settle.stop();
    _downAt = e.position;
    _decided = false;
    _velocity = VelocityTracker.withKind(e.kind)..addPosition(e.timeStamp, e.position);
  }

  void _pointerMove(PointerMoveEvent e) {
    _velocity?.addPosition(e.timeStamp, e.position);
    final start = _downAt;
    if (!_decided && start != null) {
      final d = e.position - start;
      if (d.distance < 6) return;
      _decided = true;
      // يبدأ السحب بس لو الحركة لتحت (مو يمين ويسار) والبطاقة في أعلاها
      final atTop = !_scroll.hasClients || _scroll.offset <= 0;
      if (d.dy > 0 && d.dy.abs() > d.dx.abs() && atTop) {
        setState(() => _dragging = true);
        widget.onDragging?.call(true);
        if (_scroll.hasClients && _scroll.offset != 0) _scroll.jumpTo(0);
      }
    }
    // ينزل لتحت بس (بدون أي حركة يمين ويسار)
    if (_dragging) _setDrag(_drag + e.delta.dy);
  }

  void _pointerEnd(PointerEvent e) {
    _downAt = null;
    if (!_dragging) return;
    final speed = _velocity?.getVelocity().pixelsPerSecond.dy ?? 0;
    setState(() => _dragging = false);
    widget.onDragging?.call(false);
    if (_drag > 140 || speed > 900) {
      _close();
    } else if (_drag > 0) {
      _settle.value = _drag;
      if (MediaQuery.disableAnimationsOf(context)) {
        _settle.value = 0;
      } else {
        _settle.animateTo(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      }
    }
  }

  /// 0 = أعلى البطاقة، 1 = نزل (يطلع الشريط الصغير فوق: الصورة والاسم والسعر)
  final _down = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final v = (_scroll.offset / 160).clamp(0.0, 1.0);
      _down.value = v;
      widget.onProgress?.call(v);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _down.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }
  /// خيار في "اختر": جلسة وحدة أو باقة
  Widget _option(String title, String? sub, int price, int save, bool selected, VoidCallback onTap) => Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: '$title، ${spokenMoney(price)}${save > 0 ? '، وفّر ${fmtNum(save)}%' : ''}',
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 18, 12),
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: selected ? AppColors.ink : Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              SelectDot(selected: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ts(17, weight: FontWeight.w500)),
                    if (sub != null) Text(sub, style: ts(13, color: AppColors.faint)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(price), style: ts(17, weight: FontWeight.w600)),
                  if (save > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                      child: Text('وفّر ${fmtNum(save)}%', style: ts(12, weight: FontWeight.w600, color: AppColors.onAccent)),
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  Service get sv => widget.service;

  @override
  Widget build(BuildContext context) {
    final about = _more || sv.about.length <= 120 ? sv.about : '${sv.about.substring(0, 120)}…';
    final reviews = sv.reviewList;
    final suggest = servicesIn(_suggestCat).where((x) => x.id != sv.id).toList();

    return Material(
      color: AppColors.bg,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              // السحب لتحت وهو في أعلى البطاقة ينزّلها مع الإصبع (مثل نوافذ آبل)، ويقفلها لو نزلت كفاية
              child: Listener(
                onPointerDown: _pointerDown,
                onPointerMove: _pointerMove,
                onPointerUp: _pointerEnd,
                onPointerCancel: _pointerEnd,
                child: Stack(
                children: [
                ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 20),
                physics: _dragging ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                children: [
                  // صورة الخدمة، والإغلاق والمفضلة والمشاركة فوقها
                  Stack(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          height: 330,
                          width: double.infinity,
                          color: sv.tint,
                          child: Image.asset(sv.photo, fit: BoxFit.cover),
                        ),
                      ),
                    ],
                  ),
                  // باقي البطاقة بهامش من الجنبين
                  Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  const SizedBox(height: 14),
                  // الاسم والتوفر والتقييم والسعر في بطاقة بيضاء
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(28)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(sv.name, style: ts(26, height: 1.25))),
                        const SizedBox(height: 10),
                        // التوفر في الفروع: كبسولة صغيرة
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(999)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.location_solid, size: 15, color: sv.allBranches ? AppColors.green : AppColors.faint),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    sv.availabilityText,
                                    style: ts(14, weight: FontWeight.w500, color: sv.allBranches ? AppColors.green : AppColors.body),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Semantics(
                              label: 'التقييم ${sv.ratingText} من 5، ${fmtNum(sv.reviews)} تقييم',
                              child: ExcludeSemantics(child: RatingRow(rating: sv.ratingText, reviews: sv.reviews)),
                            ),
                            const Spacer(),
                            if (sv.onOffer) ...[
                              Text(sv.oldPriceText, style: ts(16, color: AppColors.faint, decoration: TextDecoration.lineThrough)),
                              const SizedBox(width: 8),
                            ],
                            Text(priceLabel(sv), style: ts(26, weight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // باقات الجلسات
                  if (packagesFor(sv.id).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                      child: Semantics(header: true, child: Text('اختر', style: ts(20, weight: FontWeight.w500))),
                    ),
                    _option('جلسة وحدة', null, priceRange(sv).min, 0, _pkg == null, () => setState(() => _pkg = null)),
                    for (final p in packagesFor(sv.id))
                      _option(p.name, '${money(p.perSession)} للجلسة', p.price, p.savePercent, _pkg == p, () => setState(() => _pkg = p)),
                  ],
                  // التقسيط مع تابي وتمارا
                  if ((_pkg?.price ?? sv.finalPrice) >= installmentMin) ...[
                    const SizedBox(height: 12),
                    InstallmentHint(price: _pkg?.price ?? sv.finalPrice),
                  ],
                  const SizedBox(height: 16),
                  // النبذة
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(36)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text('عن الخدمة', style: ts(20, weight: FontWeight.w500))),
                        const SizedBox(height: 6),
                        AnimatedSize(
                          duration: motion(context, 250),
                          alignment: Alignment.topCenter,
                          child: Text(about, style: ts(15, color: AppColors.body, height: 1.85)),
                        ),
                        if (sv.about.length > 120)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _more = !_more),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(_more ? 'عرض أقل' : 'اقرأ المزيد', style: ts(15, weight: FontWeight.w600)),
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  // التقييمات
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(header: true, child: Text('التقييمات', style: ts(22, weight: FontWeight.w500))),
                        ),
                        const Icon(Icons.star_rounded, size: 22, color: starColor),
                        const SizedBox(width: 4),
                        Text(sv.ratingText, style: ts(18, weight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (reviews.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(28)),
                      child: Text('لا توجد تقييمات بعد', textAlign: TextAlign.center, style: ts(15, color: AppColors.body)),
                    )
                  else
                    for (final r in reviews) ...[
                      ReviewCard(review: r),
                      const SizedBox(height: 8),
                    ],
                  // خدمات مقترحة لك: فلاتر التخصص وصف خدمات يتحرك يمين ويسار
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
                    child: Semantics(header: true, child: Text('خدمات مقترحة لك', style: ts(22, weight: FontWeight.w500))),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final f in categoryFilters) ...[
                          FilterPill(label: f.label, selected: _suggestCat == f.id, onTap: () => setState(() => _suggestCat = f.id)),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 196,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: suggest.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final x = suggest[i];
                        return Pressable(
                          onTap: () => widget.onOpen != null ? widget.onOpen!(suggest, i) : openService(context, x, among: suggest),
                          semanticLabel: '${x.name}، ${priceLabel(x)}',
                          child: SizedBox(
                            width: 130,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ServiceImage(service: x, size: 130),
                                const SizedBox(height: 8),
                                Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, weight: FontWeight.w600)),
                                Text(priceLabel(x), style: ts(14, weight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  ],
                  ),
                  ),
                ],
              ),
                // لما ينزل: شريط آبل فوق (زجاج مغبّش) فيه صورة صغيرة والاسم والسعر بين الأزرار
                ValueListenableBuilder<double>(
                  valueListenable: _down,
                  builder: (context, v, _) {
                    final o = ((v - 0.4) / 0.6).clamp(0.0, 1.0);
                    if (o == 0) return const SizedBox.shrink();
                    return Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24 * o, sigmaY: 24 * o),
                          child: Container(
                            padding: EdgeInsets.fromLTRB(14, MediaQuery.paddingOf(context).top * v + 10, 14, 10),
                            decoration: BoxDecoration(
                              color: AppColors.bg.withAlpha((200 * o).round()),
                              border: Border(bottom: BorderSide(color: AppColors.ink.withAlpha((24 * o).round()), width: 0.5)),
                            ),
                            child: Opacity(
                              opacity: o,
                              child: Row(
                                children: [
                                  // مكان زر الرجوع، ومكان زرين المفضلة والمشاركة
                                  const SizedBox(width: 56),
                                  ServiceImage(service: sv, size: 40),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(sv.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, weight: FontWeight.w600)),
                                        Text(_pkg != null ? money(_pkg!.price) : priceLabel(sv), style: ts(14, weight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 108),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (widget.showButtons)
                  Positioned(
                    top: 14 + MediaQuery.paddingOf(context).top,
                    left: 14,
                    right: 14,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _down,
                      builder: (context, v, _) => ServiceButtons(service: sv, onClose: _close, native: v < 0.35),
                    ),
                  ),
                ],
              )),
            ),
            BottomAction(
              price: _pkg != null ? money(_pkg!.price) : priceLabel(sv),
              child: Row(
                children: [
                  // السلة: يضيفها ويكمّل يختار خدمات ثانية (ولو موجودة يفتح السلة)
                  Builder(builder: (context) {
                    final s = AppScope.of(context);
                    final added = s.inCart(sv.id, packageId: _pkg?.id);
                    return CircleButton(
                      icon: added ? CupertinoIcons.bag_fill : CupertinoIcons.bag_badge_plus,
                      size: 50,
                      iconSize: 22,
                      bg: added ? AppColors.ink : AppColors.white,
                      fg: added ? AppColors.white : AppColors.ink,
                      semanticLabel: added ? 'عرض السلة' : 'أضف للسلة',
                      onTap: () {
                        if (added) {
                          Navigator.of(context).push(iosRoute(const CartScreen()));
                        } else {
                          HapticFeedback.lightImpact();
                          s.addToCart(sv.id, packageId: _pkg?.id);
                        }
                      },
                    );
                  }),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PillButton(
                      label: _pkg != null ? 'اطلب الباقة' : 'اطلب الخدمة',
                      height: 50,
                      fontSize: 17,
                      onTap: () => openRequest(context, service: sv, package: _pkg),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// تقييم مستخدم: الاسم (أو مستخدم مجهول)، النجوم، التاريخ، التعليق
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Semantics(
      label: '${r.displayName}، ${fmtNum(r.stars)} من 5 نجوم، ${agoText(r.daysAgo)}. ${r.text}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(28)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: r.anonymous ? AppColors.bg : AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: r.anonymous
                        ? const Icon(CupertinoIcons.person_fill, size: 20, color: AppColors.faint)
                        : Text(r.name!.characters.first, style: ts(17, weight: FontWeight.w600, color: AppColors.onAccent)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.displayName, style: ts(16, weight: FontWeight.w600)),
                        Text(agoText(r.daysAgo), style: ts(13, color: AppColors.faint)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Icon(
                          i < r.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 18,
                          color: i < r.stars ? starColor : AppColors.faint,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(r.text, style: ts(15, color: AppColors.body, height: 1.7)),
            ],
          ),
        ),
      ),
    );
  }
}
