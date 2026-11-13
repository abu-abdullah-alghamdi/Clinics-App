import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../extras.dart';
import '../native.dart';
import '../pay_widgets.dart';
import '../services_data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'request_screen.dart';
import 'services_tab.dart';

/// صفحة الخدمة: الصورة، الاسم، التوفر، التقييم، الباقات، النبذة، التقييمات، وزر الطلب
class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key, required this.service});

  final Service service;

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  bool _more = false;

  /// الباقة المختارة (null = جلسة وحدة)
  ServicePackage? _pkg;

  /// خيار في "اختر": جلسة وحدة أو باقة
  Widget _option(String title, String? sub, int price, int save, bool selected, VoidCallback onTap) => Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: '$title، ${spokenMoney(price)}${save > 0 ? '، وفّر ${fmtNum(save)}%' : ''}',
        child: AnimatedContainer(
          duration: motion(context, 200),
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
    final s = AppScope.of(context);
    final about = _more || sv.about.length <= 120 ? sv.about : '${sv.about.substring(0, 120)}…';
    final reviews = sv.reviewList;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: FloatingBar(trailing: [
                  // المشاركة والمفضلة في قطعة زجاج وحدة من آبل
                  Builder(
                    builder: (ctx) => AppleButtonGroup(
                      id: 'service-actions',
                      buttons: [
                        AppleIconButton(
                          symbol: 'square.and.arrow.up',
                          fallback: CupertinoIcons.share,
                          label: 'مشاركة الخدمة',
                          onTap: () => shareText(ctx, shareServiceText(sv)),
                        ),
                        AppleIconButton(
                          symbol: s.favServices.contains(sv.id) ? 'heart.fill' : 'heart',
                          fallback: s.favServices.contains(sv.id) ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                          label: s.favServices.contains(sv.id) ? 'إزالة ${sv.name} من المفضلة' : 'إضافة ${sv.name} للمفضلة',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            s.toggleFavService(sv.id);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                body: ListView(
                padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.contentTop + 14, 14, 20),
                children: [
                  // صورة الخدمة
                  ExcludeSemantics(
                    child: Container(
                      height: 230,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(color: sv.tint, borderRadius: BorderRadius.circular(44)),
                      child: Image.asset(sv.photo, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(sv.name, style: ts(32, height: 1.2))),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Icon(CupertinoIcons.location_solid, size: 16, color: sv.allBranches ? AppColors.green : AppColors.faint),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sv.availabilityText,
                                style: ts(15, color: sv.allBranches ? AppColors.green : AppColors.body, height: 1.5),
                              ),
                            ),
                          ],
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
                ],
              )),
            ),
            BottomAction(
              price: _pkg != null ? money(_pkg!.price) : priceLabel(sv),
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
