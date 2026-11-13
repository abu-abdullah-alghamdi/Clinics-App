import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../main.dart';
import '../services_data.dart';
import '../state.dart';
import '../states.dart';
import '../theme.dart';
import '../widgets.dart';
import 'login_gate.dart';
import 'phone_screen.dart';
import 'request_screen.dart';

/// السلة: خدمات تنرسل مع بعض. كل خدمة تصير طلب مستقل برقمه في "مواعيدي"،
/// وكلهم بمرجع إرسال واحد عشان العيادة تعرف إنهم من عملية إرسال وحدة
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String? _branch;
  Period _period = Period.evening;
  bool _forOther = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// الفروع اللي تقدم كل الخدمات اللي في السلة
  List<Branch> _branches(List<CartEntry> cart) => branches
      .where((b) => cart.every((e) => branchesFor(e.service).any((x) => x.id == b.id)))
      .toList();

  bool _otherReady() => _name.text.trim().length >= 2 && nationalNumber(_phone.text) != null;

  Widget _title(String text) => px(Padding(
        padding: const EdgeInsets.fromLTRB(6, 20, 6, 10),
        child: Semantics(header: true, child: Text(text, style: ts(20, weight: FontWeight.w500))),
      ));

  Widget _input(TextEditingController c, String hint, {TextInputType? keyboard, List<String>? autofill, bool ltr = false}) => TextField(
        controller: c,
        keyboardType: keyboard,
        autofillHints: autofill,
        textDirection: ltr ? TextDirection.ltr : null,
        textAlign: TextAlign.start,
        inputFormatters: ltr ? const [WesternDigits()] : null,
        style: ts(17),
        decoration: pillInput(hint),
        onChanged: (_) => setState(() {}),
      );

  /// اختيار الطبيب لخدمة في السلة (الطبيب المتاح أو طبيب معيّن في الفرع المختار)
  Future<void> _pickDoctor(CartEntry e, String branchId) {
    final s = AppScope.read(context);
    final sv = e.service;
    final docs = doctorsFor(sv, branchId);
    final noPrice = e.package != null;
    return showGlassSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
              child: Semantics(header: true, child: Text(sv.name, style: ts(22, weight: FontWeight.w500))),
            ),
            ChoiceRow(
              leading: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.person_2_fill, size: 24, color: AppColors.onAccent),
              ),
              title: 'الطبيب المتاح',
              trailing: noPrice ? null : priceLabel(sv, branchId: branchId),
              selected: e.doctorId == null,
              onTap: () {
                s.setCartDoctor(e, null);
                Navigator.of(ctx).pop();
              },
            ),
            for (final d in docs) ...[
              const SizedBox(height: 8),
              ChoiceRow(
                leading: DoctorAvatar(doctor: d, size: 52),
                title: d.name,
                subtitle: d.role,
                trailing: noPrice ? null : money(sv.priceWith(d)),
                selected: e.doctorId == d.id,
                onTap: () {
                  s.setCartDoctor(e, d.id);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _send(List<CartEntry> cart, String branchId, bool canForOther) async {
    FocusScope.of(context).unfocus();
    if (!await requireLogin(context, title: 'سجّل دخولك لإرسال الطلب')) return;
    if (!mounted) return;
    final other = _forOther && canForOther;
    HapticFeedback.mediumImpact();
    final sent = AppScope.read(context).sendCart(
      branchId: branchId,
      period: _period,
      recipientName: other ? _name.text.trim() : null,
      recipientPhone: other ? '0${nationalNumber(_phone.text)}' : null,
    );
    Navigator.of(context).pushReplacement(iosRoute(RequestSentScreen(requests: sent)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cart = s.cart;
    final avail = _branches(cart);
    // الفرع المختار لازم يقدم كل الخدمات (لو انشالت خدمة أو انضافت يتعدل)
    if (!avail.any((b) => b.id == _branch)) _branch = avail.isNotEmpty ? avail.first.id : null;
    final branch = _branch;
    // الطبيب اللي ما يداوم في الفرع المختار يرجع "الطبيب المتاح"
    if (branch != null) {
      for (final e in cart) {
        if (e.doctorId != null && !doctorsFor(e.service, branch).any((d) => d.id == e.doctorId)) e.doctorId = null;
      }
    }
    final canForOther = !cart.any((e) => e.package != null);
    final total = cart.fold<int>(0, (a, e) => a + e.priceIn(branch));
    final ready = cart.isNotEmpty && branch != null && (!(_forOther && canForOther) || _otherReady());

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: FloatingBar(
                title: 'السلة',
                body: ListView(
                  padding: EdgeInsets.fromLTRB(0, FloatingBar.safeTop(context) + FloatingBar.belowBar, 0, 20),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    const SizedBox(height: 14),
                    if (cart.isEmpty)
                      px(StatusCard(
                        icon: CupertinoIcons.bag,
                        iconBg: AppColors.accent,
                        title: 'السلة فاضية',
                        actions: [
                          PillButton(
                            label: 'تصفح الخدمات',
                            height: 50,
                            fontSize: 17,
                            onTap: () {
                              s.openServices();
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            },
                          ),
                        ],
                      )),
                    for (final e in cart)
                      px(Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CartItem(
                          entry: e,
                          price: e.package != null ? money(e.package!.price) : e.doctor != null ? money(e.priceIn(branch)) : priceLabel(e.service, branchId: branch),
                          onDoctor: branch == null ? null : () => _pickDoctor(e, branch),
                          onRemove: () {
                            HapticFeedback.selectionClick();
                            s.removeFromCart(e);
                          },
                        ),
                      )),
                    if (cart.isNotEmpty) ...[
                      _title('الفرع'),
                      if (avail.isEmpty)
                        px(Text('ما فيه فرع يقدم كل الخدمات اللي في السلة', style: ts(15, color: AppColors.red)))
                      else
                        px(Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final b in avail)
                              FilterPill(label: b.name, selected: branch == b.id, onTap: () => setState(() => _branch = b.id)),
                          ],
                        )),
                      _title('الفترة'),
                      px(SegmentedPill(
                        options: [for (final p in Period.values) p.label],
                        selected: _period.index,
                        onChanged: (i) => setState(() => _period = Period.values[i]),
                      )),
                      if (canForOther) ...[
                        _title('الطلب لـ'),
                        px(SegmentedPill(
                          options: const ['لي', 'لشخص ثاني'],
                          selected: _forOther ? 1 : 0,
                          onChanged: (i) => setState(() => _forOther = i == 1),
                        )),
                        if (_forOther) ...[
                          const SizedBox(height: 10),
                          px(_input(_name, 'الاسم', keyboard: TextInputType.name, autofill: const [AutofillHints.name])),
                          const SizedBox(height: 8),
                          px(_input(_phone, '05x xxx xxxx', keyboard: TextInputType.phone, ltr: true)),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (cart.isNotEmpty)
              BottomAction(
                price: money(total),
                child: PillButton(
                  label: cart.length > 1 ? 'إرسال الطلبات' : 'إرسال الطلب',
                  height: 50,
                  fontSize: 17,
                  enabled: ready,
                  onTap: () => _send(cart, branch!, canForOther),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// خدمة في السلة: الصورة، الاسم والباقة، الطبيب (يتغيّر بالضغط)، المبلغ، وزر الحذف
class _CartItem extends StatelessWidget {
  const _CartItem({required this.entry, required this.price, required this.onDoctor, required this.onRemove});

  final CartEntry entry;
  final String price;
  final VoidCallback? onDoctor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final doctor = e.doctor?.name ?? 'الطبيب المتاح';
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          ServiceImage(service: e.service, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.service.name, style: ts(17, weight: FontWeight.w600)),
                if (e.package != null) Text(e.package!.name, style: ts(14, color: AppColors.body)),
                const SizedBox(height: 4),
                // الطبيب: يضغط عليه ويغيّره
                Pressable(
                  onTap: onDoctor,
                  semanticLabel: 'الطبيب: $doctor، تغيير',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(doctor, style: ts(14, weight: FontWeight.w500, color: AppColors.blue))),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_down, size: 13, color: AppColors.blue),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(price, style: ts(15, weight: FontWeight.w700)),
              ],
            ),
          ),
          CircleButton(
            icon: CupertinoIcons.xmark,
            size: 40,
            iconSize: 16,
            bg: AppColors.bg,
            semanticLabel: 'حذف ${e.service.name} من السلة',
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}
