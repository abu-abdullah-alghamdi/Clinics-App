import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../clinic_config.dart';
import '../data.dart';
import '../extras.dart';
import '../native.dart';
import '../services_data.dart';
import '../state.dart';
import '../states.dart';
import '../theme.dart';
import '../widgets.dart';
import 'services_tab.dart';

/// يفتح رابط (اتصال أو واتساب)
Future<void> openLink(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ما قدرنا نفتح الرابط على هذا الجهاز', style: ts(14, color: AppColors.white))),
    );
  }
}

// أرقام التواصل من إعدادات العيادة (clinics/<id>/config.json)
Uri get clinicCallUri => ClinicConfig.current.callUri;
Uri get clinicWhatsappUri => ClinicConfig.current.whatsappUri;

/// التواصل مع العيادة: اتصال أو واتساب
void showClinicContact(BuildContext context) {
  showAppSheet(
    context,
    title: 'تواصل مع العيادة',
    children: [
      PillButton(label: 'اتصال', icon: CupertinoIcons.phone_fill, bg: AppColors.bg, onTap: () => openLink(context, clinicCallUri)),
      const SizedBox(height: 10),
      PillButton(label: 'واتساب', icon: CupertinoIcons.chat_bubble_fill, bg: AppColors.bg, onTap: () => openLink(context, clinicWhatsappUri)),
      const SizedBox(height: 8),
    ],
  );
}

/// تنبيه آبل بزر واحد
Future<void> showInfoAlert(BuildContext context, String title, String message) =>
    CNAlert.show<String>(context: context, title: title, message: message, actions: const [CNAlertAction(label: 'تم', isCancel: true)]);

// ───────── التقييم بعد الزيارة

/// صورة الطلب: الطبيب لو تحدد، وإلا صورة الخدمة
class RequestAvatar extends StatelessWidget {
  const RequestAvatar({super.key, required this.booking, this.size = 64});

  final Booking booking;
  final double size;

  @override
  Widget build(BuildContext context) {
    final d = booking.doctor;
    return d != null ? ExcludeSemantics(child: DoctorAvatar(doctor: d, size: size)) : ServiceImage(service: booking.service, size: size);
  }
}

/// بطاقة "كيف كانت زيارتك؟" لآخر زيارة مكتملة ما تقيّمت
class RatePrompt extends StatelessWidget {
  const RatePrompt({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(34), boxShadow: cardShadow),
      child: Row(
        children: [
          RequestAvatar(booking: b, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('كيف كانت زيارتك؟', style: ts(17, weight: FontWeight.w600)),
                Text('${b.title}${withDoctor(b)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, color: AppColors.faint)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Semantics(
                        button: true,
                        label: '${fmtNum(i)} من 5',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => showRatingSheet(context, b, stars: i),
                          child: const Padding(
                            padding: EdgeInsetsDirectional.only(end: 6, top: 2, bottom: 2),
                            child: Icon(Icons.star_outline_rounded, size: 30, color: Color(0xFFC7C7CC)),
                          ),
                        ),
                      ),
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

/// نافذة التقييم: النجوم، وش عجبه (أو ما عجبه)، وتعليق اختياري
Future<void> showRatingSheet(BuildContext context, Booking b, {int stars = 5}) {
  final s = AppScope.read(context);
  var value = stars;
  final picked = <String>{};
  final comment = TextEditingController();
  return showGlassSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final good = value >= 4;
        final tags = good ? ratingGood : ratingBad;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: RequestAvatar(booking: b, size: 72)),
              const SizedBox(height: 10),
              Semantics(
                header: true,
                child: Text(b.doctor == null ? 'قيّم زيارتك' : 'قيّم زيارتك مع ${b.doctor!.n1}', textAlign: TextAlign.center, style: ts(22, weight: FontWeight.w500)),
              ),
              Text(lines([b.title, b.branch.name]), textAlign: TextAlign.center, style: ts(14, color: AppColors.faint)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Semantics(
                      button: true,
                      selected: i == value,
                      label: '${fmtNum(i)} من 5',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheet(() {
                            if ((i >= 4) != good) picked.clear();
                            value = i;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 44,
                            color: i <= value ? starColor : const Color(0xFFC7C7CC),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Text(ratingWords[value - 1], textAlign: TextAlign.center, style: ts(15, weight: FontWeight.w600)),
              const SizedBox(height: 16),
              Text(good ? 'وش عجبك؟' : 'وش ما عجبك؟', style: ts(16, weight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in tags)
                    Pressable(
                      onTap: () => setSheet(() => picked.contains(t) ? picked.remove(t) : picked.add(t)),
                      selected: picked.contains(t),
                      semanticLabel: t,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: picked.contains(t) ? AppColors.ink : AppColors.bg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(t, style: ts(14, weight: FontWeight.w500, color: picked.contains(t) ? AppColors.white : AppColors.ink)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: comment,
                minLines: 2,
                maxLines: 4,
                style: ts(16),
                decoration: InputDecoration(
                  hintText: 'اكتب تعليقك (اختياري)',
                  hintStyle: ts(15, color: AppColors.faint),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              PillButton(
                label: 'إرسال التقييم',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  s.rateVisit(b.id, value);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// النجوم الصغيرة على الزيارة اللي تقيّمت
class RatedStars extends StatelessWidget {
  const RatedStars({super.key, required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'قيّمتها ${fmtNum(stars)} من 5',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 16, color: i <= stars ? starColor : const Color(0xFFC7C7CC)),
            ],
          ),
        ),
      );
}
