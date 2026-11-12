import 'package:flutter/cupertino.dart';

import 'extras.dart';
import 'payments.dart';
import 'services_data.dart';
import 'theme.dart';
import 'widgets.dart';

/// شعار طريقة الدفع داخل مربع صغير (مثل قائمة الدفع في آبل)
class PayMark extends StatelessWidget {
  const PayMark({super.key, required this.method});

  final PayMethod method;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, double logoH) = switch (method) {
      PayMethod.applePay => (AppColors.white, AppColors.ink, 13.0),
      PayMethod.mada => (AppColors.white, const Color(0xFFD1D1D6), 11.0),
      PayMethod.tabby => (const Color(0xFF3EEDBF), const Color(0xFF3EEDBF), 9.0),
      PayMethod.tamara => (const Color(0xFFFBE1E8), const Color(0xFFFBE1E8), 8.0),
      _ => (AppColors.white, const Color(0xFFD1D1D6), 0.0),
    };
    final logo = method.logo;
    return ExcludeSemantics(
      child: Container(
        width: 50,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: method == PayMethod.tamara ? null : bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: border, width: method == PayMethod.applePay ? 1 : 0.8),
          gradient: method == PayMethod.tamara
              ? const LinearGradient(colors: [Color(0xFFFFD9C4), Color(0xFFF3D3F2)])
              : null,
        ),
        child: logo != null
            ? Image.asset(logo, height: logoH, fit: BoxFit.contain)
            : Icon(
                method == PayMethod.cash ? CupertinoIcons.building_2_fill : CupertinoIcons.creditcard,
                size: 18,
                color: AppColors.ink,
              ),
      ),
    );
  }
}

/// جدول دفعات التقسيط: 4 خانات، الأولى اليوم وبعدها كل شهر
class InstallmentTimeline extends StatelessWidget {
  const InstallmentTimeline({super.key, required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final part = total / installmentCount;
    final dates = installmentDates();
    return Semantics(
      label: '$installmentCount دفعات، كل دفعة ${spokenMoney(part)}، أول دفعة اليوم',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < installmentCount; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == 0 ? AppColors.ink : AppColors.closed,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(child: Text(money(part), style: ts(14, weight: FontWeight.w600))),
                    Text(installmentLabel(i, dates[i]), style: ts(12, color: AppColors.faint)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "أو 4 دفعات بـ ..." مع شعاري تابي وتمارا (تحت سعر الخدمة)
class InstallmentHint extends StatelessWidget {
  const InstallmentHint({super.key, required this.price});

  final int price;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'أو $installmentCount دفعات بـ ${spokenMoney(price / installmentCount)} مع تابي أو تمارا',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'أو $installmentCount دفعات بـ '),
                      TextSpan(text: money(price / installmentCount), style: ts(15, weight: FontWeight.w700)),
                    ]),
                    style: ts(15),
                  ),
                ),
                const PayMark(method: PayMethod.tabby),
                const SizedBox(width: 6),
                const PayMark(method: PayMethod.tamara),
              ],
            ),
          ),
        ),
      );
}

/// زر Apple Pay: الشعار وجنبه البطاقة (بعد ربط Apple Pay يصير زر آبل الأصلي ببطاقة المستخدم)
class ApplePayButton extends StatelessWidget {
  const ApplePayButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: 'الدفع عبر Apple Pay',
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const RadialGradient(
              radius: 1.6,
              colors: [Color(0xFF262626), AppColors.ink],
              stops: [0, 0.45],
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/pay/applepay_white.png', height: 22),
                Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 14), color: const Color(0xFF8A8A8A)),
                // البطاقة الافتراضية في Wallet
                Container(
                  width: 42,
                  height: 27,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD9DDE3), Color(0xFF9AA3AD), Color(0xFFCFD5DB)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 6,
                        top: 9,
                        child: Container(
                          width: 7,
                          height: 6,
                          decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(1.5)),
                        ),
                      ),
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: Container(width: 11, height: 3, color: const Color(0xFF1A1F71)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
