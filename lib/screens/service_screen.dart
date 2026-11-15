import 'package:flutter/cupertino.dart';
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
  late final PageController _pages = PageController(initialPage: widget.index, viewportFraction: 0.93);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

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
    final top = MediaQuery.paddingOf(context).top + 8;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: PageView.builder(
        controller: _pages,
        itemCount: widget.items.length,
        itemBuilder: (context, i) => AnimatedBuilder(
          animation: _pages,
          builder: (context, child) {
            // البطاقة اللي جنب الحالية أصغر شوي، وتكبر وهي تجي للنص
            final page = _pages.hasClients && _pages.position.haveDimensions ? (_pages.page ?? widget.index.toDouble()) : widget.index.toDouble();
            final d = (page - i).abs().clamp(0.0, 1.0);
            return Transform.scale(scale: 1 - d * 0.05, alignment: Alignment.bottomCenter, child: child);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
              child: ServiceScreen(
                service: widget.items[i].service,
                package: widget.items[i].package,
                onOpen: _open,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة الخدمة: الصورة وأزرارها، الاسم، التوفر، التقييم، الباقات، النبذة، التقييمات،
/// الخدمات المقترحة، والطلب والسلة تحت
class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key, required this.service, this.package, this.onOpen});

  final Service service;

  /// الباقة المختارة من البداية
  final ServicePackage? package;

  /// فتح خدمة من "خدمات مقترحة لك"
  final void Function(List<Service> list, int index)? onOpen;

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  bool _more = false;

  /// الباقة المختارة (null = جلسة وحدة)
  late ServicePackage? _pkg = widget.package;

  /// فلتر "خدمات مقترحة لك" (null = الكل)
  String? _suggestCat;

  /// السحب لتحت من أعلى البطاقة يقفلها (مرة وحدة)
  bool _closing = false;

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

  Widget _round(IconData icon, String label, VoidCallback onTap) => CircleButton(
        icon: icon,
        size: 42,
        iconSize: 19,
        bg: AppColors.white,
        semanticLabel: label,
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final about = _more || sv.about.length <= 120 ? sv.about : '${sv.about.substring(0, 120)}…';
    final reviews = sv.reviewList;
    final fav = s.favServices.contains(sv.id);
    final suggest = servicesIn(_suggestCat).where((x) => x.id != sv.id).toList();

    return Material(
      color: AppColors.bg,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: NotificationListener<ScrollUpdateNotification>(
                // السحب لتحت وهو في أعلى البطاقة يقفلها
                onNotification: (n) {
                  if (n.dragDetails != null && n.metrics.pixels < -80) _close();
                  return false;
                },
                child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                children: [
                  // صورة الخدمة، والإغلاق والمفضلة والمشاركة فوقها
                  Stack(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          height: 300,
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(color: sv.tint, borderRadius: BorderRadius.circular(30)),
                          child: Image.asset(sv.photo, fit: BoxFit.cover),
                        ),
                      ),
                      PositionedDirectional(
                        top: 12,
                        start: 12,
                        child: _round(CupertinoIcons.xmark, 'إغلاق', _close),
                      ),
                      PositionedDirectional(
                        top: 12,
                        end: 12,
                        child: Column(
                          children: [
                            _round(
                              fav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                              fav ? 'إزالة ${sv.name} من المفضلة' : 'إضافة ${sv.name} للمفضلة',
                              () {
                                HapticFeedback.selectionClick();
                                s.toggleFavService(sv.id);
                              },
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (ctx) => _round(CupertinoIcons.share, 'مشاركة الخدمة', () => shareText(ctx, shareServiceText(sv))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(sv.name, style: ts(28, height: 1.25))),
                        const SizedBox(height: 10),
                        // التوفر في الفروع: كبسولة صغيرة
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(999)),
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
