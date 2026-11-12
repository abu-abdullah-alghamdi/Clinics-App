import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';

/// الشروط والأحكام (نص تجريبي، يُستبدل بنص العيادة المعتمد قبل النشر)
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const _sections = [
    ('استخدام التطبيق', 'التطبيق لحجز المواعيد وطلب خدمات العيادة ومتابعتها. المعلومات اللي فيه للتعريف بالخدمات وما تغني عن استشارة الطبيب'),
    ('الحساب', 'أنت مسؤول عن صحة معلوماتك الشخصية، ورقم جوالك هو وسيلة الدخول لحسابك'),
    ('المواعيد', 'تقدر تعدّل أو تلغي موعدك من صفحة "مواعيدي". نرجو الإلغاء قبل الموعد بوقت كافٍ لإتاحة الفرصة لغيرك'),
    ('الطلبات والدفع', 'الأسعار بالريال السعودي، وتُضاف ضريبة القيمة المضافة لغير السعوديين حسب النظام. سياسة الاسترجاع حسب أنظمة العيادة ووزارة التجارة'),
    ('التعديلات', 'ممكن نحدّث هذي الشروط، ونبلغك بأي تغيير مهم داخل التطبيق'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: FloatingBar(title: 'الشروط والأحكام', body: ListView(
          padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.contentTop, 14, 30),
          children: [
            for (final (title, body) in _sections)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(30)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(title, style: ts(18, weight: FontWeight.w600))),
                    const SizedBox(height: 6),
                    Text(body, style: ts(16, color: AppColors.body, height: 1.7)),
                  ],
                ),
              ),
          ],
        )),
      ),
    );
  }
}
