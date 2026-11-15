import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../extras.dart';
import '../main.dart';
import '../native.dart';
import '../services_data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart_screen.dart';
import 'request_screen.dart';
import 'service_screen.dart';
import 'shell.dart';

const starColor = Color(0xFFFFB800);

/// صفحة الخدمات: مربعات التخصصات (كبيرة فوق، وتتحول لكبسولات بحركة سريعة لما ينزل)، وأقسام الكشف والخدمات
/// والباقات والعروض في شبكة عمودين. الضغط على خدمة يفتح بطاقتها، والسحب يمين ويسار يبدّل بين الخدمات
class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  /// 0 = مربعات كبيرة، 1 = كبسولات (تتحرك بحركة وحدة سريعة مثل المثال، مو مع الإصبع)
  late final AnimationController _collapse = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

  /// ترتيب الأقسام الظاهرة، والقسم اللي يقرأه الحين (الخط تحته)
  List<String> _order = const [];
  String? _section;

  // أطوال الشريط اللي فوق
  static const _bar = 56.0;
  static const _tilesMax = 118.0;
  static const _tilesMin = 62.0;
  static const _tabs = 52.0;

  /// متى تتصغّر ومتى ترجع تكبر (فرق بينهم عشان ما ترجف عند الحد)
  static const _collapseAt = 90.0;
  static const _expandAt = 40.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _collapse.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final o = _scroll.offset;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (o > _collapseAt && _collapse.value < 1 && _collapse.status != AnimationStatus.forward) {
      if (reduce) {
        _collapse.value = 1;
      } else {
        _collapse.forward();
      }
    } else if (o < _expandAt && _collapse.value > 0 && _collapse.status != AnimationStatus.reverse) {
      if (reduce) {
        _collapse.value = 0;
      } else {
        _collapse.reverse();
      }
    }
    _track();
  }

  GlobalKey _key(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// مكان القسم في الصفحة (عنوانه تحت الشريط اللي فوق مباشرة)
  double? _offsetOf(String id) {
    final box = _keys[id]?.currentContext?.findRenderObject();
    if (box == null) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;
    // الشريط اللي فوق يغطي أول القائمة (وهو مصغّر وقت القراءة)
    final header = MediaQuery.paddingOf(context).top + _bar + _tilesMin + _tabs;
    return viewport.getOffsetToReveal(box, 0).offset - header;
  }

  /// الخط تحت القسم يمشي مع القسم اللي يقرأه
  void _track() {
    if (!_scroll.hasClients || _order.isEmpty) return;
    var current = _order.first;
    for (final id in _order) {
      final o = _offsetOf(id);
      if (o != null && _scroll.offset >= o - 12) current = id;
    }
    if (current != _section) setState(() => _section = current);
  }

  /// الضغط على قسم ينزّل له
  void _goTo(String id) {
    if (!_scroll.hasClients) return;
    final o = id == _order.first ? 0.0 : _offsetOf(id);
    if (o == null) return;
    final target = o.clamp(0.0, _scroll.position.maxScrollExtent);
    setState(() => _section = id);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  void _pickCat(String? cat) {
    HapticFeedback.selectionClick();
    AppScope.read(context).setServiceCat(cat);
    setState(() => _section = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = servicesIn(s.serviceCatFilter);
    ServiceItem one(Service x) => (service: x, package: null);
    final sections = <(String, String, List<ServiceItem>)>[
      if (list.any((x) => x.kashf)) ('kashf', 'الكشف', [for (final x in list.where((x) => x.kashf)) one(x)]),
      if (list.any((x) => !x.kashf)) ('services', 'الخدمات', [for (final x in list.where((x) => !x.kashf)) one(x)]),
      if (list.any((x) => packagesFor(x.id).isNotEmpty))
        ('packages', 'الباقات', [for (final x in list) for (final p in packagesFor(x.id)) (service: x, package: p)]),
      if (list.any((x) => x.onOffer)) ('offers', 'العروض', [for (final x in list.where((x) => x.onOffer)) one(x)]),
    ];
    _order = [for (final x in sections) x.$1];
    if (!_order.contains(_section)) _section = _order.isEmpty ? null : _order.first;
    // كل البطاقات بترتيب الصفحة (للسحب يمين ويسار بين الخدمات)
    final all = [for (final x in sections) ...x.$3];
    final top = MediaQuery.paddingOf(context).top;
    final bottom = navBottomSpace + (s.cartCount > 0 ? cartBarSpace * uiScale(context).clamp(1.0, 1.6) : 0) + 10;

    // طول الشريط اللي فوق (يتغيّر مع حركة المربعات)
    double headerHeight(double t) =>
        top + _bar + _tilesMax - (_tilesMax - _tilesMin) * Curves.easeInOutCubic.transform(t) + _tabs;

    var base = 0;
    final slivers = <Widget>[];
    for (final (id, label, items) in sections) {
      final start = base;
      base += items.length;
      slivers
        ..add(SliverToBoxAdapter(
          child: KeyedSubtree(
            key: _key(id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Semantics(header: true, child: Text(label, style: ts(22, weight: FontWeight.w600))),
            ),
          ),
        ))
        ..add(SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverLayoutBuilder(
            builder: (context, c) {
              final w = (c.crossAxisExtent - 12) / 2;
              return SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _GridCard(item: items[i], onTap: () => openServiceSheet(context, all, start + i)),
                  childCount: items.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 18,
                  mainAxisExtent: w + MediaQuery.textScalerOf(context).scale(112),
                ),
              );
            },
          ),
        ));
    }

    return Stack(
      children: [
        // الخدمات تمر تحت الشريط اللي فوق (مثل آبل)، ومسافة أولها بطول الشريط
        CustomScrollView(
          controller: _scroll,
          cacheExtent: 4000,
          slivers: [
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _collapse,
                builder: (context, _) => SizedBox(height: headerHeight(_collapse.value)),
              ),
            ),
            ...slivers,
            if (sections.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('ما فيه خدمات', textAlign: TextAlign.center, style: ts(17, color: AppColors.body)),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: bottom)),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: Listenable.merge([_collapse, _scroll]),
            builder: (context, _) => _ServicesHeader(
              t: _collapse.value,
              glass: _scroll.hasClients ? (_scroll.offset / 16).clamp(0.0, 1.0) : 0,
              top: top,
              bar: _bar,
              tilesMax: _tilesMax,
              tilesMin: _tilesMin,
              tabs: _tabs,
              cat: s.serviceCatFilter,
              onCat: _pickCat,
              sections: [for (final x in sections) (x.$1, x.$2)],
              section: _section,
              onSection: _goTo,
              cartCount: s.cartCount,
            ),
          ),
        ),
      ],
    );
  }
}

/// صورة التخصص في المربع (من صور خدماته)
const _catPhoto = {'dental': 's1', 'ortho': 's5', 'derma': 's6', 'laser': 's7'};

/// الشريط اللي فوق: العنوان والسلة والبحث، ومربعات التخصصات (أو الكبسولات)، والأقسام
class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader({
    required this.t,
    required this.glass,
    required this.top,
    required this.bar,
    required this.tilesMax,
    required this.tilesMin,
    required this.tabs,
    required this.cat,
    required this.onCat,
    required this.sections,
    required this.section,
    required this.onSection,
    required this.cartCount,
  });

  /// 0 = مربعات كبيرة، 1 = كبسولات
  final double t;

  /// زجاج آبل ورا الشريط (0 = شفاف فوق، 1 = المحتوى يمر تحته)
  final double glass;
  final double top, bar, tilesMax, tilesMin, tabs;
  final String? cat;
  final ValueChanged<String?> onCat;
  final List<(String, String)> sections;
  final String? section;
  final ValueChanged<String> onSection;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    final strip = tilesMax - (tilesMax - tilesMin) * Curves.easeInOutCubic.transform(t);
    final content = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Column(
        children: [
          SizedBox(height: top),
          SizedBox(
            height: bar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  // مكان فاضي بنفس عرض زر السلة عشان العنوان يبقى في النص
                  const SizedBox(width: GlassCircle.barSize),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('الخدمات', textAlign: TextAlign.center, style: ts(20, weight: FontWeight.w600)),
                    ),
                  ),
                  // السلة على اليسار
                  AppleIconButton(
                    symbol: 'bag',
                    fallback: CupertinoIcons.bag,
                    label: 'السلة',
                    prominent: true,
                    tint: AppColors.accent,
                    badge: cartCount,
                    onTap: () => Navigator.of(context).push(iosRoute(const CartScreen())),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: strip,
            child: ClipRect(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final f in categoryFilters) ...[
                    _CatTile(
                      label: f.label,
                      photo: f.id == null ? null : serviceById(_catPhoto[f.id] ?? 's1').thumb,
                      selected: cat == f.id,
                      t: t,
                      height: strip,
                      onTap: () => onCat(f.id),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            height: tabs,
            child: DecoratedBox(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x14000000)))),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final (id, label) in sections)
                    Pressable(
                      onTap: () => onSection(id),
                      selected: section == id,
                      semanticLabel: label,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: IntrinsicWidth(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                style: ts(17,
                                    weight: section == id ? FontWeight.w700 : FontWeight.w400,
                                    color: section == id ? AppColors.ink : AppColors.body),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: section == id ? AppColors.ink : AppColors.ink.withAlpha(0),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    // مثل شريط آبل: شفاف وهو في أعلى الصفحة، ولما تمر الخدمات تحته يصير زجاج مغبّش بخط رفيع تحته
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24 * glass, sigmaY: 24 * glass),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.bg.withAlpha((190 * glass).round()),
            border: Border(bottom: BorderSide(color: AppColors.ink.withAlpha((26 * glass).round()), width: 0.5)),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// مربع تخصص. فوق: الصورة في إطار مربع وتحته الاسم. مع النزول: الاسم اللي تحت يختفي، والإطار يقصر
/// والصورة تصغر، وبعدها الإطار يتمدد لجهة اليسار ويصير مستطيل ويطلع الاسم من داخله جنب الصورة.
/// ومع الطلوع نفس الحركة بالعكس
class _CatTile extends StatelessWidget {
  const _CatTile({required this.label, required this.photo, required this.selected, required this.t, required this.height, required this.onTap});

  final String label;

  /// null = "الكل" (أيقونة بدل الصورة)
  final String? photo;
  final bool selected;

  /// 0 = مربع، 1 = مستطيل
  final double t;
  final double height;
  final VoidCallback onTap;

  /// الإطار المربع، والمستطيل
  static const _square = 76.0;
  static const _pillH = 46.0;

  /// بدون حد ولا حافة: الصورة تعبّي المربع كامل، والتحديد إطار بلون العيادة يرتسم فوق حافتها
  static const _border = 0.0;
  static const _gap = 0.0;
  static const _ring = 1.5;

  /// الصورة داخل الإطار: كبيرة تعبّيه وحولها حافة بيضاء 1 من كل الجهات، وصغيرة في المستطيل
  static const _imageBig = _square - 2 * _border - 2 * _gap;
  static const _imageSmall = 34.0;

  static double _lerp(double a, double b, double x) => a + (b - a) * x;


  @override
  Widget build(BuildContext context) {
    final style = ts(15, weight: selected ? FontWeight.w700 : FontWeight.w500);
    final tp = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.rtl,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final textW = tp.width;
    tp.dispose();

    // حركة وحدة سلسة: الصورة تصغر وتنسحب لليمين، والإطار يقصر ويتمدد لليسار ويطلع الاسم داخله بنفس الوقت.
    // والاسم اللي تحت المربع يختفي في أول الحركة
    final k = Curves.easeInOutCubic.transform(t);
    final fadeLabel = (k / 0.4).clamp(0.0, 1.0);
    final shrink = k;
    final widen = k;

    // المسافات تنحسب من داخل الحد، عشان الصورة تكون بالنص بالضبط (قبل كانت مايلة لليسار بمقدار الحد)
    final pad = _lerp(_gap, (_pillH - 2 * _border - _imageSmall) / 2, shrink);
    final image = _lerp(_imageBig, _imageSmall, shrink);
    final frameH = _lerp(_square, _pillH, shrink);
    final innerH = frameH - 2 * _border;
    final pillW = 2 * _border + pad + _imageSmall + 8 + textW + 16;
    final frameW = _lerp(_square, pillW, widen);
    final radius = _lerp(20, 16, shrink);
    final labelH = 24 * (1 - fadeLabel);

    final frame = Container(
      width: frameW,
      height: frameH,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // وهو مستطيل: المختار كبسولة بلون العيادة، وغيره أبيض
        color: selected ? AppColors.accent : AppColors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      // وهو مربع: إطار بلون العيادة (1.5) يظهر بس على المختار
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: selected ? AppColors.accent : AppColors.accent.withAlpha(0), width: _ring),
      ),
      child: Stack(
        children: [
          // الصورة في بداية الإطار (يمين)
          PositionedDirectional(
            start: pad,
            top: (innerH - image) / 2,
            child: Container(
              width: image,
              height: image,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: photo == null ? AppColors.accent : AppColors.bg,
                // مربعة دايماً بزوايا ناعمة تمشي مع زوايا الإطار (ما تصير دائرية وهي تصغر)
                borderRadius: BorderRadius.circular((radius - _border - pad).clamp(6.0, image * 0.3)),
              ),
              child: photo == null
                  ? Icon(CupertinoIcons.square_grid_2x2_fill, size: image * 0.45, color: AppColors.onAccent)
                  : Image.asset(photo!, fit: BoxFit.cover),
            ),
          ),
          // الاسم داخل الإطار جنب الصورة: يطلع مع تمدد الإطار (المقصوص منه ما يبان)
          PositionedDirectional(
            start: pad + image + 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(label, maxLines: 1, softWrap: false, style: selected ? style.copyWith(color: AppColors.onAccent) : style),
            ),
          ),
        ],
      ),
    );

    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      child: SizedBox(
        width: frameW,
        height: height,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                frame,
                // الاسم تحت المربع: يختفي أول ما يبدأ النزول
                SizedBox(
                  height: labelH,
                  child: Opacity(
                    opacity: 1 - fadeLabel,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: style.copyWith(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة في شبكة الخدمات: الصورة وزر السلة عليها، الاسم (والباقة)، والسعر
class _GridCard extends StatelessWidget {
  const _GridCard({required this.item, required this.onTap});

  final ServiceItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sv = item.service;
    final p = item.package;
    final price = p != null ? money(p.price) : priceLabel(sv);
    final badge = p != null
        ? (p.savePercent > 0 ? 'وفّر ${fmtNum(p.savePercent)}%' : null)
        : (sv.onOffer ? 'خصم ${fmtNum(sv.discount)}%' : null);
    return Pressable(
      onTap: onTap,
      semanticLabel: [sv.name, if (p != null) p.name, price].join('، '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: sv.tint, borderRadius: BorderRadius.circular(26)),
                    child: Image.asset(sv.photo, fit: BoxFit.cover),
                  ),
                ),
                if (badge != null)
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                      child: Text(badge, style: ts(12, weight: FontWeight.w700, color: AppColors.onAccent)),
                    ),
                  ),
                PositionedDirectional(bottom: 10, end: 10, child: CartCircle(service: sv, packageId: p?.id)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sv.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(16, weight: FontWeight.w600, height: 1.3)),
                if (p != null) Text(p.name, maxLines: 1, style: ts(13, color: AppColors.body)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(child: Text(price, style: ts(17, weight: FontWeight.w700))),
                    if (p == null && sv.onOffer) ...[
                      const SizedBox(width: 6),
                      Text(sv.oldPriceText, style: ts(13, color: AppColors.faint, decoration: TextDecoration.lineThrough)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// نجمة + التقييم + عدد التقييمات
class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.rating, required this.reviews});

  final String rating;
  final int reviews;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 19, color: starColor),
          const SizedBox(width: 3),
          Text(rating, style: ts(14, weight: FontWeight.w600)),
          const SizedBox(width: 4),
          Flexible(child: Text('(${fmtNum(reviews)} تقييم)', style: ts(13, color: AppColors.body))),
        ],
      );
}

/// زر السلة على بطاقة الخدمة (مربع): + يضيفها، وصح يعني إنها في السلة (والضغط يشيلها)
class CartCircle extends StatelessWidget {
  const CartCircle({super.key, required this.service, this.packageId});

  final Service service;

  /// باقة بدل الجلسة الوحدة
  final String? packageId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final entry = s.cartEntry(service.id, packageId: packageId);
    final added = entry != null;
    // مربع بزوايا ناعمة (مو دائرة)
    return Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
        added ? s.removeFromCart(entry) : s.addToCart(service.id, packageId: packageId);
      },
      semanticLabel: added ? 'إزالة ${service.name} من السلة' : 'أضف ${service.name} للسلة',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: added ? AppColors.ink : AppColors.accent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Icon(added ? Icons.check_rounded : Icons.add_rounded, size: 24, color: added ? AppColors.white : AppColors.onAccent),
      ),
    );
  }
}

/// المسافة اللي ياخذها شريط "عرض السلة" فوق الشريط العائم
const cartBarSpace = 74.0;

/// شريط "عرض السلة": عدد الخدمات في مربع، وكلمة عرض السلة
class CartBar extends StatelessWidget {
  const CartBar({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.6,
      child: Pressable(
        onTap: () => Navigator.of(context).push(iosRoute(const CartScreen())),
        semanticLabel: 'عرض السلة، ${fmtNum(count)} خدمات',
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 22, 10),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 42),
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
                child: Text(fmtNum(count), style: ts(18, weight: FontWeight.w700, color: AppColors.onAccent)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('عرض السلة', style: ts(17, weight: FontWeight.w600, color: AppColors.white))),
              const Icon(CupertinoIcons.chevron_left, size: 18, color: AppColors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة الخدمة: الصورة، الاسم، التوفر، التقييم، السعر، وزر الطلب
class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final sv = service;
    final s = AppScope.of(context);
    void open() => openService(context, sv);
    // الضغط على البطاقة يفتح صفحة الخدمة (زر + والقلب لهم ضغطتهم الخاصة)
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: open,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(32),
        border: highContrast(context) ? Border.all(color: AppColors.ink, width: 1.5) : null,
      ),
      // مع الخط الكبير جداً البطاقة ترتب نفسها عمودي بدل ما يتقص الكلام
      child: _ServiceCardLayout(
        stacked: MediaQuery.textScalerOf(context).scale(10) > 15,
        image: ServiceImage(service: sv, size: 96),
        body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        hint: 'عرض تفاصيل الخدمة',
                        onTap: open,
                        child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sv.name, style: ts(18, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Icon(CupertinoIcons.location_solid, size: 14, color: sv.allBranches ? AppColors.green : AppColors.faint),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sv.availabilityText,
                              style: ts(13, color: sv.allBranches ? AppColors.green : AppColors.body, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Semantics(
                        label: 'التقييم ${sv.ratingText} من 5، ${fmtNum(sv.reviews)} تقييم',
                        child: ExcludeSemantics(child: RatingRow(rating: sv.ratingText, reviews: sv.reviews)),
                      ),
                    ],
                  ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FavButton(
                      active: s.favServices.contains(sv.id),
                      name: sv.name,
                      size: 44,
                      bg: AppColors.bg,
                      onTap: () => s.toggleFavService(sv.id),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(priceLabel(sv), style: ts(19, weight: FontWeight.w600)),
                          if (sv.onOffer)
                            Text(sv.oldPriceText, style: ts(13, color: AppColors.faint, decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                    ),
                    CartCircle(service: sv),
                  ],
                ),
              ],
            ),
      ),
      ),
    );
  }
}

class _ServiceCardLayout extends StatelessWidget {
  const _ServiceCardLayout({required this.stacked, required this.image, required this.body});

  final bool stacked;
  final Widget image;
  final Widget body;

  @override
  Widget build(BuildContext context) => stacked
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [image, const SizedBox(height: 12), body],
        )
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [image, const SizedBox(width: 14), Expanded(child: body)],
        );
}
