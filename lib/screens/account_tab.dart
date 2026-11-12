import 'package:flutter/cupertino.dart';

import '../data.dart';
import '../main.dart';
import '../services_data.dart';
import '../state.dart';
import '../states.dart';
import '../theme.dart';
import '../widgets.dart';
import 'branches_screen.dart';
import 'clinic_demo_screen.dart';
import 'extras_screens.dart';
import 'favorites_screen.dart';
import 'orders_screen.dart';
import 'phone_screen.dart';
import 'privacy_screen.dart';
import 'profile_screen.dart';
import 'shell.dart';
import 'states_preview_screen.dart';
import 'visit_extras.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  void _contact(BuildContext context) => showClinicContact(context);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final title = !s.loggedIn ? 'مستخدم جديد' : (s.name.trim().isNotEmpty ? s.name.trim() : 'أهلاً بك');
    final sub = s.loggedIn ? displayPhone(s.phone.trim()) : 'سجّل دخولك';

    // المستخدم الجديد: المربع نفسه زر تسجيل الدخول، وبعدها يرجع لهذي الصفحة
    void login() => Navigator.of(context).push(iosRoute(const PhoneScreen(inside: true), name: loginRouteName));

    Widget row(String label, {Widget? trailing, bool divider = true, VoidCallback? onTap, Color? color}) => Pressable(
          onTap: onTap,
          // صف المفتاح يخلي قارئ الشاشة يقرأ حالته (مفعّل/متوقف)
          semanticLabel: trailing == null ? label : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: divider ? const Border(bottom: BorderSide(color: AppColors.bg)) : null,
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: ts(17, color: color))),
                trailing ?? const Icon(CupertinoIcons.forward, size: 18, color: AppColors.faint),
              ],
            ),
          ),
        );

    Widget stat(String n, String label, bool lime) => Expanded(
          child: Pressable(
            onTap: () => s.setTab(1),
            semanticLabel: '$n $label',
            child: Container(
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lime ? AppColors.accent : AppColors.white,
                borderRadius: BorderRadius.circular(34),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n, style: ts(34, color: lime ? AppColors.onAccent : AppColors.ink)),
                  const SizedBox(height: 12),
                  Text(label, style: ts(15, color: lime ? AppColors.onAccent : AppColors.ink)),
                ],
              ),
            ),
          ),
        );

    // العنوان الكبير يتعامل مع الساعة فوق، والـ SafeArea للأطراف بس
    return SafeArea(
      top: false,
      bottom: false,
      child: LargeTitleScroll(
        title: 'حسابي',
        horizontal: 14,
        bottomSpace: navBottomSpace,
        children: [
          Pressable(
            onTap: s.loggedIn ? null : login,
            semanticLabel: s.loggedIn ? null : '$title، $sub',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(46), boxShadow: cardShadow),
              child: Row(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    child: Text(s.initial, style: ts(30, weight: FontWeight.w600, color: AppColors.onAccent)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: ts(24)),
                        const SizedBox(height: 4),
                        Text(sub, style: ts(15, color: AppColors.body), textDirection: s.loggedIn ? TextDirection.ltr : null),
                      ],
                    ),
                  ),
                  if (!s.loggedIn) const Icon(CupertinoIcons.forward, size: 20, color: AppColors.faint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              stat(fmtNum(s.upcoming.length), 'مواعيد قادمة', true),
              const SizedBox(width: 10),
              stat(fmtNum(s.completedCount), 'زيارات مكتملة', false),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(40)),
            child: Column(
              children: [
                if (s.loggedIn && s.profile != null)
                  row('معلوماتي الشخصية',
                      onTap: () => Navigator.of(context).push(
                            iosRoute(ProfileScreen(phone: s.profile!.phone, initial: s.profile)),
                          )),
                if (s.loggedIn)
                  row('المدفوعات',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.orders.isNotEmpty) Text(fmtNum(s.orders.length), style: ts(16, color: AppColors.faint)),
                          const SizedBox(width: 6),
                          const Icon(CupertinoIcons.forward, size: 18, color: AppColors.faint),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(iosRoute(const OrdersScreen()))),
                if (s.loggedIn) ...[
                  row('باقاتي',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.packages.isNotEmpty) Text(fmtNum(s.packages.length), style: ts(16, color: AppColors.faint)),
                          const SizedBox(width: 6),
                          const Icon(CupertinoIcons.forward, size: 18, color: AppColors.faint),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(iosRoute(const PackagesScreen()))),
                ],
                row('المفضلة', onTap: () => Navigator.of(context).push(iosRoute(const FavoritesScreen()))),
                row('تذكير المواعيد على واتساب',
                    // مفتاح iOS مرسوم داخل التطبيق عشان ينزل تحت الشريط الزجاجي وأنت تمرر
                    trailing: CupertinoSwitch(
                      value: s.remindOnWhatsapp,
                      activeTrackColor: AppColors.ink,
                      onChanged: (_) => s.toggleRemind(),
                    ),
                    onTap: s.toggleRemind),
                row('تواصل مع العيادة', onTap: () => _contact(context)),
                row('سياسة الخصوصية', divider: showStatesPreview, onTap: () => Navigator.of(context).push(iosRoute(const PrivacyScreen()))),
                // للتجربة بس: يتقفل من showStatesPreview في states.dart قبل النشر
                if (showStatesPreview) ...[
                  row('لوحة العيادة (تجريبية)', onTap: () => Navigator.of(context).push(iosRoute(const ClinicDemoScreen()))),
                  row('معاينة الحالات', divider: false, onTap: () => Navigator.of(context).push(iosRoute(const StatesPreviewScreen()))),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // فروعنا: مربع واحد يفتح صفحة الفروع
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(40)),
            child: row(
              'فروعنا',
              divider: false,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fmtNum(branches.length), style: ts(16, color: AppColors.faint)),
                  const SizedBox(width: 6),
                  const Icon(CupertinoIcons.forward, size: 18, color: AppColors.faint),
                ],
              ),
              onTap: () => Navigator.of(context).push(iosRoute(const BranchesScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

/// مربع فرع: الاسم، مفتوح/مغلق، الأيام والساعات، الحي، وزرين (اتصال · الاتجاهات)
