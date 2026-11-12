/// الدفع — حالياً شكلي (ما يخصم أي مبلغ).
///
/// عند الربط مع بوابة دفع حقيقية (مثل Moyasar أو HyperPay أو Tap):
/// اكتب كلاس جديد يطبّق [PaymentGateway] وغيّر [PaymentGateway.instance] له.
/// باقي التطبيق ما يحتاج أي تعديل.
library;

enum PayMethod { applePay, mada, card, tabby, tamara }

extension PayMethodText on PayMethod {
  String get label => switch (this) {
        PayMethod.applePay => 'Apple Pay',
        PayMethod.mada => 'مدى',
        PayMethod.card => 'بطاقة ائتمانية',
        PayMethod.tabby => 'تابي',
        PayMethod.tamara => 'تمارا',
      };

  String get hint => switch (this) {
        PayMethod.applePay => 'ادفع بلمسة من جوالك',
        PayMethod.mada => 'بطاقة مدى البنكية',
        PayMethod.card => 'Visa / Mastercard',
        PayMethod.tabby => '4 دفعات بدون فوائد',
        PayMethod.tamara => 'قسّمها بدون فوائد',
      };

  bool get needsCard => this == PayMethod.mada || this == PayMethod.card;

  /// تقسيط (تابي أو تمارا)
  bool get installments => this == PayMethod.tabby || this == PayMethod.tamara;

  /// شعار طريقة الدفع (null = أيقونة بدل الشعار)
  String? get logo => switch (this) {
        PayMethod.applePay => 'assets/pay/applepay.png',
        PayMethod.mada => 'assets/pay/mada.png',
        PayMethod.tabby => 'assets/pay/tabby.png',
        PayMethod.tamara => 'assets/pay/tamara.png',
        _ => null,
      };
}

class CardDetails {
  const CardDetails({required this.number, required this.holder, required this.expiry, required this.cvv});

  final String number;
  final String holder;
  final String expiry;
  final String cvv;
}

class PaymentResult {
  const PaymentResult.success(this.reference)
      : ok = true,
        error = null;
  const PaymentResult.failure(this.error)
      : ok = false,
        reference = null;

  final bool ok;
  final String? reference;
  final String? error;
}

abstract class PaymentGateway {
  /// البوابة المستخدمة في التطبيق (غيّرها هنا عند الربط الحقيقي)
  static PaymentGateway instance = MockPaymentGateway();

  /// هل هي بوابة تجريبية؟ (تظهر ملاحظة "وضع تجريبي" في صفحة الدفع)
  bool get isDemo;

  Future<PaymentResult> pay({required double amount, required PayMethod method, CardDetails? card});
}

/// بوابة شكلية: تنتظر ثانيتين وترجع نجاح، وما تحفظ ولا ترسل بيانات البطاقة.
/// للتجربة: أي بطاقة رقمها ينتهي بـ 0002 ترجع فشل
class MockPaymentGateway implements PaymentGateway {
  @override
  bool get isDemo => true;

  @override
  Future<PaymentResult> pay({required double amount, required PayMethod method, CardDetails? card}) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (card != null && card.number.endsWith('0002')) return const PaymentResult.failure('رفض البنك العملية');
    return PaymentResult.success('DEMO-${DateTime.now().millisecondsSinceEpoch}');
  }
}
