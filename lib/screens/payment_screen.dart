import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../extras.dart';
import '../main.dart';
import '../pay_widgets.dart';
import '../payments.dart';
import '../services_data.dart';
import '../state.dart';
import '../theme.dart';
import '../states.dart';
import '../widgets.dart';
import 'done_screen.dart';
import 'orders_screen.dart';

/// الموعد اللي ينحجز بعد الدفع
class Appointment {
  const Appointment({required this.doctorId, required this.cat, required this.day, required this.time});

  final String doctorId;
  final String cat;
  final int day;
  final int time;
}

/// صفحة الدفع (شكلية لين يتم الربط مع بوابة دفع حقيقية — شوف lib/payments.dart)
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.branchId,
    required this.items,
    this.appointment,
    this.fromCart = false,
    this.recipientName,
    this.recipientPhone,
  });

  /// الدفع لشخص ثاني: العيادة تتواصل معه وتحدد الموعد
  final String? recipientName;
  final String? recipientPhone;

  final String branchId;
  final List<OrderItem> items;

  /// لو موجود: بعد الدفع ينحجز الموعد ويطلع في "مواعيدي"
  final Appointment? appointment;
  final bool fromCart;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PayMethod _method = PayMethod.applePay;
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  /// مرحلة الدفع (null = النموذج ظاهر)
  PayPhase? _phase;

  int get _subtotal => widget.items.fold(0, (a, b) => a + b.total);

  /// كود الخصم المطبّق
  String? _coupon;
  bool _couponError = false;
  final _couponCtrl = TextEditingController();

  int get _discount => _coupon == null ? 0 : (_subtotal * coupons[_coupon]! / 100).round();

  /// طرق الدفع المتاحة: التقسيط من مبلغ معيّن، والدفع في العيادة مو للطلب لشخص ثاني
  List<PayMethod> get _methods => [
        for (final m in PayMethod.values)
          if (!(m.installments && _subtotal - _discount < installmentMin) && !(m == PayMethod.cash && widget.recipientName != null)) m,
      ];

  void _applyCoupon() {
    final code = normalizeDigits(_couponCtrl.text).trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      if (coupons.containsKey(code)) {
        _coupon = code;
        _couponError = false;
        HapticFeedback.lightImpact();
      } else {
        _couponError = true;
      }
      if (!_methods.contains(_method)) _method = PayMethod.applePay;
    });
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    _number.dispose();
    _holder.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  String _digits(TextEditingController c) => normalizeDigits(c.text).replaceAll(RegExp(r'\D'), '');

  bool get _cardOk {
    if (!_method.needsCard) return true;
    return _digits(_number).length == 16 &&
        _holder.text.trim().length >= 3 &&
        RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(_expiry.text) &&
        RegExp(r'^\d{3,4}$').hasMatch(_digits(_cvv));
  }

  /// آخر 4 أرقام من البطاقة (لو الدفع ببطاقة)
  String? get _last4 {
    if (!_method.needsCard) return null;
    final d = _digits(_number);
    return d.length >= 4 ? d.substring(d.length - 4) : null;
  }

  String get _methodText => _last4 == null ? _method.label : '${_method.label} ···· $_last4';

  Future<void> _pay() async {
    if (!_cardOk || _phase != null) return;
    FocusScope.of(context).unfocus();
    final s = AppScope.read(context);
    final amount = (_subtotal - _discount).toDouble();
    final cash = _method == PayMethod.cash;
    var reference = '';

    // الدفع في العيادة ما يمر على البوابة
    if (!cash) {
      setState(() => _phase = PayPhase.processing);
      final result = await PaymentGateway.instance.pay(
        amount: amount,
        method: _method,
        card: _method.needsCard
            ? CardDetails(number: _digits(_number), holder: _holder.text.trim(), expiry: _expiry.text, cvv: _digits(_cvv))
            : null,
      );
      if (!mounted) return;
      final pause = Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 300 : 1000);
      if (!result.ok) {
        // الدائرة تحمر وتهتز، وبعدها صفحة الفشل
        setState(() => _phase = PayPhase.failure);
        await Future<void>.delayed(pause);
        if (!mounted) return;
        final action = await Navigator.of(context).push<PaymentFailAction>(
          iosRoute(PaymentFailedScreen(amount: amount, methodText: _methodText)),
        );
        if (!mounted) return;
        setState(() => _phase = null);
        if (action == PaymentFailAction.retry) _pay();
        return;
      }
      // الدائرة تقفل وتنرسم علامة الصح
      setState(() => _phase = PayPhase.success);
      await Future<void>.delayed(pause);
      if (!mounted) return;
      reference = result.reference ?? '';
    }

    final order = s.placeOrder(
      items: widget.items,
      branchId: widget.branchId,
      method: _method,
      reference: reference,
      cardLast4: _last4,
      clearCart: widget.fromCart,
      discount: _discount,
      coupon: _coupon,
      recipientName: widget.recipientName,
      recipientPhone: widget.recipientPhone,
    );
    final a = widget.appointment;
    final nav = Navigator.of(context);
    if (a != null) {
      // الباقة: أول جلسة هي هذا الموعد
      if (widget.items.any((i) => i.package != null) && s.packages.isNotEmpty) s.usePackageSession(s.packages.first.id);
      // الخدمة تصير موعد في "مواعيدي"
      final b = s.addBooking(
        doctorId: a.doctorId,
        cat: a.cat,
        day: a.day,
        time: a.time,
        branchId: widget.branchId,
        serviceIds: [for (final i in widget.items) i.service.id],
        orderNumber: order.number,
      );
      nav.pushAndRemoveUntil(iosRoute(DoneScreen(booking: b, order: order)), (r) => r.isFirst);
    } else {
      nav.pushAndRemoveUntil(iosRoute(OrderDoneScreen(order: order)), (r) => r.isFirst);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
        child: Text(text, style: ts(20, weight: FontWeight.w500)),
      );

  Widget _field(String hint, TextEditingController c,
          {TextInputType? keyboard, List<TextInputFormatter>? formatters, bool obscure = false, List<String>? autofill}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          controller: c,
          style: ts(17).copyWith(letterSpacing: 1),
          keyboardType: keyboard,
          inputFormatters: formatters,
          obscureText: obscure,
          autocorrect: false,
          autofillHints: autofill,
          decoration: pillInput(hint),
          onChanged: (_) => setState(() {}),
        ),
      );

  /// خانة كود الخصم، وبعد التطبيق تصير سطر أخضر فيه الكود وزر الإزالة
  Widget _couponBox() {
    final code = _coupon;
    if (code != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(999)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Color(0xFFE3F5E9), shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.tag_fill, size: 18, color: AppColors.green),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(code, textDirection: TextDirection.ltr, textAlign: TextAlign.right, style: ts(16, weight: FontWeight.w600))),
            Text('تم تطبيقه', style: ts(14, weight: FontWeight.w500, color: AppColors.green)),
            const SizedBox(width: 8),
            CircleButton(
              icon: CupertinoIcons.xmark,
              size: 40,
              iconSize: 15,
              bg: AppColors.bg,
              semanticLabel: 'إزالة كود الخصم',
              onTap: () => setState(() {
                _coupon = null;
                _couponCtrl.clear();
              }),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 5, 5, 5),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: _couponError ? Border.all(color: AppColors.red, width: 1.5) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponCtrl,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  style: ts(16, weight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'اكتب الكود',
                    hintStyle: ts(16, color: AppColors.faint),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() => _couponError = false),
                  onSubmitted: (_) => _applyCoupon(),
                ),
              ),
              PillButton(
                label: 'تطبيق',
                height: 40,
                fontSize: 15,
                padding: 18,
                bg: AppColors.ink,
                fg: AppColors.white,
                enabled: _couponCtrl.text.trim().isNotEmpty,
                onTap: _applyCoupon,
              ),
            ],
          ),
        ),
        if (_couponError)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text('الكود غير صحيح', style: ts(14, color: AppColors.red)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = (_subtotal - _discount).toDouble();
    final payLabel = _method == PayMethod.cash
        ? 'تأكيد الطلب · ${money(total)}'
        : _method.installments
            ? 'ادفع أول دفعة · ${money(total / installmentCount)}'
            : 'ادفع ${money(total)}';

    // وقت الدفع: الصفحة كلها تصير حركة التحقق، وما يقدر يرجع لين تخلص
    final phase = _phase;
    if (phase != null) {
      return PopScope(
        canPop: false,
        child: Scaffold(body: SafeArea(child: PaymentProgressView(phase: phase, amount: total, methodText: _methodText))),
      );
    }

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: FloatingBar(title: 'الدفع', body: ListView(
                padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.belowBar, 14, 20),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const SizedBox(height: 16),
                  if (PaymentGateway.instance.isDemo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.ink, width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(CupertinoIcons.info_circle_fill, size: 22, color: AppColors.ink),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'وضع تجريبي: لن يتم خصم أي مبلغ، ولا تُحفظ بيانات البطاقة أو تُرسل',
                              style: ts(14, height: 1.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _label('ملخص الطلب'),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(32)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(widget.recipientName != null ? CupertinoIcons.person_fill : CupertinoIcons.location_solid, size: 16, color: AppColors.faint),
                            const SizedBox(width: 6),
                            Text(
                              widget.recipientName != null ? 'لـ ${widget.recipientName}' : branchById(widget.branchId).name,
                              style: ts(15, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final it in widget.items)
                          amountRow(it.label, money(it.total)),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AmountSummary(subtotal: _subtotal, discount: _discount, discountLabel: 'خصم ${_coupon ?? ''}'),
                  _label('كود الخصم'),
                  _couponBox(),
                  _label('طريقة الدفع'),
                  for (final m in _methods) ...[
                    _MethodTile(
                      method: m,
                      selected: _method == m,
                      total: total,
                      onTap: () => setState(() => _method = m),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_method.needsCard) ...[
                    _label('بيانات البطاقة'),
                    _field('0000 0000 0000 0000', _number,
                        keyboard: TextInputType.number,
                        formatters: [const WesternDigits(), _CardNumberFormatter()],
                        autofill: const [AutofillHints.creditCardNumber]),
                    const SizedBox(height: 8),
                    _field('الاسم على البطاقة', _holder,
                        keyboard: TextInputType.name, autofill: const [AutofillHints.creditCardName]),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _field('MM/YY', _expiry,
                              keyboard: TextInputType.number,
                              formatters: [const WesternDigits(), _ExpiryFormatter()],
                              autofill: const [AutofillHints.creditCardExpirationDate]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _field('CVV', _cvv,
                              keyboard: TextInputType.number,
                              obscure: true,
                              formatters: [
                                const WesternDigits(),
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              autofill: const [AutofillHints.creditCardSecurityCode]),
                        ),
                      ],
                    ),
                  ],
                ],
              )),
            ),
            BottomAction(
              child: _method == PayMethod.applePay
                  ? ApplePayButton(onTap: _pay)
                  : PillButton(
                      label: payLabel,
                      height: 50,
                      fontSize: 17,
                      enabled: _cardOk,
                      bg: _method.installments ? AppColors.ink : null,
                      fg: _method.installments ? AppColors.white : null,
                      onTap: _pay,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.method, required this.selected, required this.total, required this.onTap});

  final PayMethod method;
  final bool selected;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: '${method.label}، ${method.hint}',
        child: AnimatedContainer(
          duration: motion(context, 200),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: selected && method.installments ? AppColors.ink : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SelectDot(selected: selected),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(method.label, style: ts(17, weight: FontWeight.w600)),
                        if (method != PayMethod.applePay) Text(method.hint, style: ts(13, color: AppColors.faint)),
                      ],
                    ),
                  ),
                  PayMark(method: method),
                ],
              ),
              // التقسيط: جدول الدفعات وتواريخها
              AnimatedSize(
                duration: motion(context, 250),
                alignment: Alignment.topCenter,
                child: selected && method.installments
                    ? Padding(padding: const EdgeInsets.only(top: 14), child: InstallmentTimeline(total: total))
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      );
}

/// رقم البطاقة: 16 رقم في مجموعات من 4
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = d.length > 16 ? d.substring(0, 16) : d;
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(digits[i]);
    }
    final t = b.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// تاريخ الانتهاء MM/YY
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = d.length > 4 ? d.substring(0, 4) : d;
    final t = digits.length > 2 ? '${digits.substring(0, 2)}/${digits.substring(2)}' : digits;
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// صفحة نجاح الطلب
class OrderDoneScreen extends StatelessWidget {
  const OrderDoneScreen({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final cash = order.method == PayMethod.cash;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 40, 14, 20),
                children: [
                  Center(
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 56, color: AppColors.onAccent),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text('تم الطلب بنجاح', textAlign: TextAlign.center, style: ts(32)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'رقم الطلب #${order.number}',
                    textAlign: TextAlign.center,
                    style: ts(16, color: AppColors.body),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.forOther
                        ? 'العيادة بتتواصل مع ${order.recipientName} وتحدد الموعد معه'
                        : cash
                            ? 'الدفع عند زيارتك للفرع، ويتواصل معك الفرع لتحديد موعد الخدمة'
                            : 'تم الدفع (تجريبي)، ويتواصل معك الفرع لتحديد موعد الخدمة',
                    textAlign: TextAlign.center,
                    style: ts(15, color: AppColors.body, height: 1.7),
                  ),
                  const SizedBox(height: 20),
                  OrderCard(order: order),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: PillButton(label: 'تم', height: 50, onTap: () => Navigator.of(context).pop()),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: PillButton(
                      label: 'عرض طلباتي',
                      height: 50,
                      fontSize: 16,
                      bg: AppColors.white,
                      onTap: () {
                        final nav = Navigator.of(context);
                        AppScope.read(context).setTab(3);
                        nav.pop();
                        nav.push(iosRoute(const OrdersScreen()));
                      },
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
