import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../native.dart';
import '../services_data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'request_screen.dart';
import 'service_screen.dart';
import 'shell.dart';

const starColor = Color(0xFFFFB800);

/// صفحة الخدمات: قائمة الخدمات حسب التخصص
class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = servicesIn(s.serviceCatFilter);
    // العنوان الكبير يتعامل مع الساعة فوق، والـ SafeArea للأطراف بس
    return SafeArea(
      top: false,
      bottom: false,
      child: LargeTitleScroll(
        title: 'الخدمات',
        bottomSpace: navBottomSpace,
        children: [
          // فلترة حسب التخصص
          HScroll(
            height: 60,
            children: [
              for (final f in categoryFilters)
                FilterPill(label: f.label, selected: s.serviceCatFilter == f.id, onTap: () => s.setServiceCat(f.id)),
            ],
          ),
          const SizedBox(height: 8),
          for (final sv in list) ...[
            px(PeekMenu(
              actions: [
                PeekAction('اطلب الخدمة', CupertinoIcons.calendar, () => openRequest(context, service: sv)),
                PeekAction(
                  s.favServices.contains(sv.id) ? 'إزالة من المفضلة' : 'أضف للمفضلة',
                  s.favServices.contains(sv.id) ? CupertinoIcons.heart_slash : CupertinoIcons.heart,
                  () => s.toggleFavService(sv.id),
                ),
                PeekAction('مشاركة', CupertinoIcons.share, () => shareText(context, shareServiceText(sv))),
              ],
              child: ServiceCard(service: sv),
            )),
            const SizedBox(height: 10),
          ],
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

/// زر الطلب السريع على بطاقة الخدمة (دائرة بلون التطبيق فيها سهم)
class RequestCircle extends StatelessWidget {
  const RequestCircle({super.key, required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) => CircleButton(
        icon: Icons.north_west_rounded,
        size: 44,
        iconSize: 22,
        bg: AppColors.accent,
        fg: AppColors.onAccent,
        semanticLabel: 'اطلب ${service.name}',
        onTap: () => openRequest(context, service: service),
      );
}

/// بطاقة الخدمة: الصورة، الاسم، التوفر، التقييم، السعر، وزر الطلب
class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final sv = service;
    final s = AppScope.of(context);
    void open() => Navigator.of(context).push(iosRoute(ServiceScreen(service: sv)));
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
                    RequestCircle(service: sv),
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
