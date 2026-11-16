import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../state.dart';
import '../states.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell.dart';

/// نهاية خطوات الدخول: إذا بدأ من داخل التطبيق يرجع لنفس المكان، وإلا يفتح الرئيسية
void finishLogin(BuildContext context, {required bool inside}) {
  final nav = Navigator.of(context);
  if (inside) {
    nav.popUntil((r) => r.settings.name != loginRouteName);
  } else {
    nav.pushAndRemoveUntil(iosRoute(const MainShell()), (_) => false);
  }
}

/// يعرض الجوال 05xxxxxxxx بالشكل +966 5x xxx xxxx
String displayPhone(String phone) {
  final n = phone.startsWith('0') ? phone.substring(1) : phone;
  if (n.length != 9) return phone;
  return '+966 ${n.substring(0, 2)} ${n.substring(2, 5)} ${n.substring(5)}';
}

/// الاسم: بعد رمز التحقق لأول مرة ("اسمك")، أو للتعديل من "حسابي" ("معلوماتي الشخصية")
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.phone, this.inside = false, this.initial});

  /// رقم الجوال الموثّق (05xxxxxxxx)
  final String phone;
  final bool inside;

  /// المعلومات الحالية (لو موجودة = وضع التعديل)
  final Profile? initial;

  bool get editing => initial != null;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 3;

  void _submit() {
    if (!_valid) return;
    FocusScope.of(context).unfocus();
    AppScope.read(context).saveProfile(Profile(name: _name.text.trim(), phone: widget.phone));
    HapticFeedback.lightImpact();
    if (widget.editing) {
      Navigator.of(context).pop();
    } else {
      finishLogin(context, inside: widget.inside);
    }
  }

  void _logout() {
    AppScope.read(context).logout();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _deleteAccount() async {
    final s = AppScope.read(context);
    // تنبيه آبل الأصلي (iOS 26)
    final delete = await showNativeAlert(
      context,
      title: 'حذف الحساب؟',
      message: 'بيتم حذف بياناتك ومواعيدك من التطبيق نهائياً، وما تقدر تتراجع',
      cancel: 'إلغاء',
      destructive: 'حذف',
    );
    if (delete && mounted) {
      s.deleteAccount();
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
        child: Text(text, style: ts(15)),
      );

  @override
  Widget build(BuildContext context) {
    // العميل الجديد: الرجوع يطلّعه من التسجيل كامل (الرمز انستخدم وما له فايدة يرجع له)
    return PopScope(
      canPop: widget.editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) finishLogin(context, inside: widget.inside);
      },
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: FloatingBar(
                  title: widget.editing ? 'معلوماتي الشخصية' : 'اسمك',
                  body: ListView(
                    padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.contentTop, 14, 20),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      // الاسم
                      _label('الاسم الكامل'),
                      TextField(
                        controller: _name,
                        autofocus: !widget.editing,
                        style: ts(16),
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: pillInput('مثل: محمد أحمد الغامدي'),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _submit(),
                      ),

                      // الجوال (موثّق بالرمز): يطلع في التعديل بس
                      if (widget.editing) ...[
                        _label('رقم الجوال'),
                        Semantics(
                          label: 'رقم الجوال ${displayPhone(widget.phone)}، موثّق',
                          child: ExcludeSemantics(
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 62),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(999)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayPhone(widget.phone),
                                      textDirection: TextDirection.ltr,
                                      // يمين الحقل مثل باقي النصوص (مو لاصق بكلمة "موثّق")
                                      textAlign: TextAlign.end,
                                      style: ts(17, color: AppColors.body),
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.checkmark_seal_fill, size: 20, color: AppColors.green),
                                  const SizedBox(width: 6),
                                  Text('موثّق', style: ts(14, weight: FontWeight.w600, color: AppColors.green)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              BottomAction(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PillButton(
                      label: 'حفظ',
                      height: 50,
                      enabled: _valid,
                      onTap: _submit,
                    ),
                    // من "حسابي" بس: تسجيل الخروج وحذف الحساب تحت زر الحفظ
                    if (widget.editing) ...[
                      const SizedBox(height: 10),
                      PillButton(label: 'تسجيل الخروج', bg: AppColors.white, fontSize: 17, onTap: _logout),
                      const SizedBox(height: 4),
                      PillButton(label: 'حذف الحساب', bg: Colors.transparent, fg: AppColors.red, fontSize: 16, onTap: _deleteAccount),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
