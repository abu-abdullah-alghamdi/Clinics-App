import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../main.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile_screen.dart';

/// رمز التجربة
const demoCode = '1111';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.national, this.inside = false});

  /// الرقم الوطني بدون الصفر (9 أرقام)
  final String national;
  final bool inside;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Timer? _timer;
  int _left = 30;
  bool _error = false;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _left = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = math.max(0, _left - 1));
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  String get _code => normalizeDigits(_ctrl.text).replaceAll(RegExp(r'\D'), '');

  void _onChanged(String _) {
    final v = _code;
    if (v.length < 4) {
      setState(() => _error = false);
      return;
    }
    _check(v);
  }

  void _check(String v) {
    if (v.length < 4) return;
    if (v == demoCode) {
      setState(() {
        _ok = true;
        _error = false;
      });
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        final s = AppScope.read(context);
        final phone = '0${widget.national}';
        if (s.hasAccount(phone)) {
          // مسجّل من قبل: يدخل مباشرة
          s.login(widget.national);
          finishLogin(context, inside: widget.inside);
        } else {
          // أول مرة: يكتب اسمه بس
          Navigator.of(context).push(
            iosRoute(ProfileScreen(phone: phone, inside: widget.inside), name: loginRouteName),
          ).then((_) {
            // لو رجع من صفحة المعلومات، نفرّغ الرمز عشان يقدر يكمل من جديد
            if (!mounted) return;
            setState(() => _ok = false);
            _ctrl.clear();
          });
        }
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _error = true);
      _ctrl.clear();
      if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
    }
  }

  String get _display {
    final n = widget.national;
    return '+966 ${n.substring(0, 2)} ${n.substring(2, 5)} ${n.substring(5)}';
  }

  /// خانة رقم واحدة من خانات الرمز
  Widget _box(int i, String code) {
    final filled = i < code.length;
    final active = !_ok && i == code.length;
    final borderColor = _error
        ? AppColors.red
        : active
            ? AppColors.ink
            : Colors.transparent;
    return Container(
      height: 86 * uiScale(context),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _ok ? AppColors.accent : AppColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(filled ? fmtNum(code[i]) : '', style: ts(34, weight: FontWeight.w500, color: _ok ? AppColors.onAccent : null)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: FloatingBar(side: 16, body: ListView(
                padding: EdgeInsets.fromLTRB(16, FloatingBar.safeTop(context) + FloatingBar.contentTop, 16, 20),
                children: [
                  const BigTitle('تحقق من رقمك', size: 34),
                  const SizedBox(height: 22),

                  // الجوال: الأيقونة يمين، والرقم جنبها وتحته "تبي تغير رقم الجوال؟"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                          child: const Icon(CupertinoIcons.device_phone_portrait, size: 24, color: AppColors.ink),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(_display, style: ts(18, weight: FontWeight.w600)),
                              ),
                              Semantics(
                                button: true,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => Navigator.of(context).maybePop(),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Text('تبي تغير رقم الجوال؟', style: ts(14, weight: FontWeight.w600, color: AppColors.blue)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('لقد أرسلنا للتو رمز التحقق عبر الرسائل القصيرة', style: ts(15, color: AppColors.body, height: 1.7)),
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _shake,
                    builder: (context, child) {
                      final t = _shake.value;
                      final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
                      return Transform.translate(offset: Offset(dx, 0), child: child);
                    },
                    child: GestureDetector(
                      onTap: () => _focus.requestFocus(),
                      child: Stack(
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              // 4 خانات بنفس العرض بالضبط، وبينها مسافة 12
                              children: [
                                for (var i = 0; i < 4; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(child: _box(i, code)),
                                ],
                              ],
                            ),
                          ),
                          // حقل مخفي يستقبل الأرقام (ويدعم تعبئة الرمز التلقائية من الرسائل)
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0,
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focus,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                autofillHints: const [AutofillHints.oneTimeCode],
                                inputFormatters: [const WesternDigits(), LengthLimitingTextInputFormatter(4)],
                                showCursor: false,
                                enableInteractiveSelection: false,
                                onChanged: _onChanged,
                                decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_error)
                    Text('رمز التحقق غير صحيح', textAlign: TextAlign.center, style: ts(15, weight: FontWeight.w600, color: AppColors.red)),
                  if (_ok)
                    Text('تم التحقق', textAlign: TextAlign.center, style: ts(14, color: AppColors.green)),
                  const SizedBox(height: 6),
                  Center(
                    child: _left > 0
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text.rich(
                              TextSpan(children: [
                                const TextSpan(text: 'إعادة الإرسال بعد '),
                                TextSpan(
                                  text: '\u{2066}0:${fmtNum(_left.toString().padLeft(2, '0'))}\u{2069}',
                                  style: ts(14, weight: FontWeight.w600),
                                ),
                              ]),
                              style: ts(14, color: AppColors.body),
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              _ctrl.clear();
                              setState(() {
                                _error = false;
                                _startTimer();
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text('إعادة إرسال الرمز', style: ts(15, weight: FontWeight.w600)),
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(999)),
                      child: Text('للتجربة: الرمز 1111', style: ts(14, color: AppColors.body)),
                    ),
                  ),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }
}
