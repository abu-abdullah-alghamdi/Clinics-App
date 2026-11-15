import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account_tab.dart';
import 'appointments_tab.dart';
import 'doctors_tab.dart';
import 'home_tab.dart';
import 'services_tab.dart';

/// الهيكل الرئيسي: التبويبات (الشريط العائم نفسه فوق كل الصفحات في [TabBarLayer])
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // الشريط العائم يظهر بس لما هذي الصفحة هي اللي قدام
    final route = ModalRoute.of(context);
    if (route != null && !identical(route, _route)) {
      _route = route;
      WidgetsBinding.instance.addPostFrameCallback((_) => TabBarRoutes.instance.setShell(route));
    }
  }

  @override
  void dispose() {
    final route = _route;
    if (route != null) TabBarRoutes.instance.clearShell(route);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          // الخلفية المتدرجة بلون العيادة أعلى كل الصفحات الخمس
          pageGradient(context),
          Positioned.fill(
            child: IndexedStack(
              index: s.tab,
              children: [
                // كل تبويب يعيد رسم نفسه بس وهو ظاهر، والمخفي توقف حركاته
                for (final (i, tab) in const <Widget>[HomeTab(), AppointmentsTab(), DoctorsTab(), AccountTab(), ServicesTab()].indexed)
                  TabScope(
                    state: s,
                    active: s.tab == i,
                    version: s.version,
                    child: TickerMode(enabled: s.tab == i, child: RepaintBoundary(child: tab)),
                  ),
              ],
            ),
          ),
          // تلاشي المحتوى تحت شريط الحالة وتحت الشريط العائم (scroll edge effect)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: top + 28,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [pageTint.withAlpha(225), pageTint.withAlpha(150), pageTint.withAlpha(0)],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
          // شريط "عرض السلة" فوق الشريط العائم في الرئيسية والخدمات (يطلع بعد أول إضافة)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + navBarHeight + 8,
            child: SafeArea(
              top: false,
              bottom: false,
              child: AnimatedSwitcher(
                duration: motion(context, 250),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                    child: child,
                  ),
                ),
                child: (s.tab == 4 || s.tab == 0) && s.cartCount > 0
                    ? CartBar(key: const ValueKey('cart-bar'), count: s.cartCount)
                    : const SizedBox(key: ValueKey('no-bar'), width: double.infinity),
              ),
            ),
          ),
          // شريط التبويبات الأصلي من آبل (يتعامل مع منطقة الأمان والزجاج والحركة بنفسه)
        ],
      ),
    );
  }
}

/// المساحة السفلية اللي تخليها كل صفحة عشان الشريط ما يغطي المحتوى
const navBottomSpace = 120.0;

/// ارتفاع شريط آبل تقريباً (من فوق الشريط لأسفل الشاشة بدون منطقة الأمان)
const navBarHeight = 62.0;

/// ترتيب التبويبات في الشريط (من اليمين): الرئيسية، الأطباء، الخدمات، مواعيدي، حسابي
const _order = [0, 2, 4, 1, 3];

/// حجم أيقونات الشريط (مقاس تطبيقات آبل؛ الأكبر يثقل الخط ويضغط الأسماء)
const _iconSize = 18.0;

/// يتابع الصفحات اللي تنفتح فوق الصفحة الرئيسية، ويحسب منها حالة الشريط العائم ([view])
/// مثل هنقرستيشن: الصفحة الداخلة تغطيه وهي تتحرك، والرجوع بالزر يطلّعه على طول،
/// والسحب للرجوع يظهّره تدريجياً مع الإصبع.
class TabBarRoutes extends NavigatorObserver with ChangeNotifier {
  TabBarRoutes._();

  static final instance = TabBarRoutes._();

  Route<dynamic>? _shell;
  final List<Route<dynamic>> _routes = [];

  /// حركة الصفحة (الصفحات العادية والنوافذ كلها لها حركة)
  static Animation<double>? _anim(Route<dynamic>? r) => r is TransitionRoute<dynamic> ? r.animation : null;

  /// يبلّغ الشريط؛ ولو احنا وسط بناء الشاشة يأجّلها لبعد الإطار
  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  void setShell(Route<dynamic> route) {
    if (identical(_shell, route)) return;
    _anim(_shell)?.removeListener(_notify);
    _shell = route;
    _anim(_shell)?.addListener(_notify);
    // صفحات من شاشة قديمة انقفلت (مثلاً بعد التسجيل) ما عاد لها أثر
    for (final r in [..._routes]) {
      if (r.navigator == null) _drop(r);
    }
    _notify();
  }

  void clearShell(Route<dynamic> route) {
    if (!identical(_shell, route)) return;
    _anim(_shell)?.removeListener(_notify);
    _shell = null;
    _notify();
  }

  /// ظهور الشريط: 1 = ظاهر كامل، 0 = مخفي
  /// السحب للرجوع: الشريط يظهر ويختفي مع الإصبع (وبعد ما يفك إصبعه لين تكمل الحركة)
  bool _gesture = false;
  Route<dynamic>? _afterGesture;

  @override
  void didStartUserGesture(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _gesture = true;
    _afterGesture = route;
    _notify();
  }

  @override
  void didStopUserGesture() {
    _gesture = false;
    final r = _afterGesture;
    final a = _anim(r);
    if (a == null || a.status == AnimationStatus.completed || a.status == AnimationStatus.dismissed) {
      _afterGesture = null;
    } else {
      void done(AnimationStatus st) {
        if (st == AnimationStatus.completed || st == AnimationStatus.dismissed) {
          a.removeStatusListener(done);
          if (identical(_afterGesture, r)) _afterGesture = null;
          _notify();
        }
      }

      a.addStatusListener(done);
    }
    _notify();
  }

  /// حالة الشريط الحين:
  /// - صفحة تدخل فوق الرئيسية: الصفحة تغطي الشريط وهي تتحرك (بنفس سرعتها ومنحنى حركتها)
  /// - رجوع بالزر: الشريط يطلع كامل على طول
  /// - سحب للرجوع: يظهر تدريجياً مع الإصبع
  /// - نافذة من تحت: يختفي على طول، ويرجع على طول وهي تنقفل
  NavBarState view({required bool reduceMotion}) {
    final shell = _shell;
    if (shell == null) return NavBarState.hidden;
    // الرئيسية نفسها وهي تدخل (بعد التسجيل مثلاً)
    final enter = _anim(shell);
    if (enter != null && enter.value < 1) return NavBarState(opacity: enter.value);
    // أول صفحة فوق الرئيسية هي اللي تغطي الشريط (اللي فوقها ما تفرق)
    Route<dynamic>? r;
    for (final x in _routes) {
      if (!identical(x, shell) && x.navigator != null) {
        r = x;
        break;
      }
    }
    if (r == null) return NavBarState.shown;
    // أول إطار من الصفحة الجديدة: فلاتر (Hero) يخليها مخفية عشان يقيس عناصرها، وحركتها
    // في هالإطار تقول "خلصت" وهي ما بدت. لو صدقناها ينخفي الشريط إطار واحد = رمشة
    if (r is ModalRoute<dynamic> && r.offstage) return NavBarState.shown;
    final a = _anim(r);
    if (a == null) return NavBarState.hidden;
    switch (a.status) {
      case AnimationStatus.completed:
        return NavBarState.hidden;
      case AnimationStatus.dismissed:
        return NavBarState.shown;
      case AnimationStatus.reverse when !_gesture && !identical(_afterGesture, r):
        return NavBarState.shown;
      case _:
        break;
    }
    if (_gesture || identical(_afterGesture, r) || reduceMotion) return NavBarState(opacity: 1 - a.value);
    if (r is PageRoute) {
      // نفس منحنى حركة صفحات آبل في فلاتر (CupertinoPageRoute)
      return r.fullscreenDialog
          ? NavBarState(cover: Curves.linearToEaseOut.transform(a.value), vertical: true)
          : NavBarState(cover: Curves.fastEaseInToSlowEaseOut.transform(a.value));
    }
    return NavBarState.hidden;
  }

  void _add(Route<dynamic>? r) {
    if (r == null || _routes.contains(r)) return;
    _routes.add(r);
    _anim(r)?.addListener(_notify);
    _notify();
  }

  void _drop(Route<dynamic>? r) {
    if (r == null || !_routes.remove(r)) return;
    _anim(r)?.removeListener(_notify);
    _notify();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // الصفحة لسا تتحرك وهي طالعة: نتابعها لين تختفي تماماً
    final a = _anim(route);
    if (a == null || a.status == AnimationStatus.dismissed) {
      _drop(route);
      return;
    }
    void done(AnimationStatus st) {
      if (st == AnimationStatus.dismissed) {
        a.removeStatusListener(done);
        _drop(route);
      }
    }

    a.addStatusListener(done);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _drop(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _drop(oldRoute);
    _add(newRoute);
  }
}

/// حالة ظهور الشريط
@immutable
class NavBarState {
  const NavBarState({this.opacity = 1, this.cover = 0, this.vertical = false});

  static const shown = NavBarState();
  static const hidden = NavBarState(opacity: 0);

  /// شفافية الشريط (للسحب للرجوع)
  final double opacity;

  /// كم من الشاشة غطّتها الصفحة اللي تدخل (0 = ولا شي، 1 = كلها)
  final double cover;

  /// الصفحة تدخل من تحت (نافذة كاملة) بدل من الجنب
  final bool vertical;

  bool get visible => opacity > 0.001 && cover < 0.999;
}

/// يحط الشريط العائم فوق كل الصفحات (MaterialApp.builder).
/// لازم يكون فوق: لو كان داخل الرئيسية، الصفحة اللي تنفتح فوقه تنقص وقت الحركة
/// (فلاتر ما يقدر يرسم فوق عنصر آبل الأصلي وقت الحركة).
class TabBarLayer extends StatelessWidget {
  const TabBarLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final screen = MediaQuery.sizeOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ListenableBuilder(
            listenable: TabBarRoutes.instance,
            builder: (context, bar) {
              final v = TabBarRoutes.instance.view(reduceMotion: reduceMotion);
              // الشريط يبقى موجود دايماً (ما ينشال ويرجع)، بس ما ينرسم وهو مخفي
              return IgnorePointer(
                ignoring: !v.visible || v.opacity < 0.99 || v.cover > 0,
                child: Opacity(
                  opacity: v.visible ? v.opacity : 0,
                  child: ClipRect(
                    clipper: _CoverClipper(view: v, rtl: rtl, screenHeight: screen.height),
                    child: bar,
                  ),
                ),
              );
            },
            child: const GlassNavBar(),
          ),
        ),
      ],
    );
  }
}

/// يقص الجزء اللي غطّته الصفحة الداخلة من الشريط، فيبان كأن الصفحة تمر فوقه
class _CoverClipper extends CustomClipper<Rect> {
  _CoverClipper({required this.view, required this.rtl, required this.screenHeight});

  final NavBarState view;
  final bool rtl;
  final double screenHeight;

  @override
  Rect getClip(Size size) {
    final c = view.cover;
    if (c <= 0) return Offset.zero & size;
    if (view.vertical) {
      // حافة النافذة العلوية وهي تطلع من تحت، والشريط في أسفل الشاشة
      final edge = (1 - c) * screenHeight;
      final visible = (edge - (screenHeight - size.height)).clamp(0.0, size.height);
      return Rect.fromLTWH(0, 0, size.width, visible);
    }
    // الصفحة تدخل من اليسار في العربي (ومن اليمين في الإنجليزي)
    final covered = c * size.width;
    return rtl ? Rect.fromLTRB(covered, 0, size.width, size.height) : Rect.fromLTRB(0, 0, size.width - covered, size.height);
  }

  @override
  bool shouldReclip(_CoverClipper old) =>
      old.view.cover != view.cover || old.view.vertical != view.vertical || old.rtl != rtl || old.screenHeight != screenHeight;
}

/// شريط التبويبات الأصلي من آبل (UITabBar):
/// على iOS 26 يطلع بزجاج آبل وحركتها الأصلية، وعلى الأقدم يرجع شريط Cupertino عادي.
/// ثابت في مكانه، والصفحات تمر فوقه وهي تدخل ([TabBarRoutes]).
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final index = _order.indexOf(s.tab).clamp(0, _order.length - 1);
    return CNTabBar(
      // الإخفاء وقت الصفحات والنوافذ نتحكم فيه نحن (يختفي تدريجياً بدل ما ينشال)
      autoHideOnPageTransition: false,
      autoHideOnModal: false,
      currentIndex: index,
      onTap: (i) {
        final tab = _order[i];
        // تبويب الأطباء يفتح دايماً على "الكل"
        if (tab == 2) {
          s.openDoctors();
        } else {
          s.setTab(tab);
        }
      },
      tint: AppColors.ink,
      labelFontFamily: appFont,
      labelFontSize: 11,
      iconSize: _iconSize,
      items: const [
        CNTabBarItem(label: 'الرئيسية', icon: CNSymbol('house', size: _iconSize), activeIcon: CNSymbol('house.fill', size: _iconSize)),
        CNTabBarItem(label: 'الأطباء', icon: CNSymbol('stethoscope', size: _iconSize), activeIcon: CNSymbol('stethoscope', size: _iconSize)),
        CNTabBarItem(
          label: 'الخدمات',
          icon: CNSymbol('square.grid.2x2', size: _iconSize),
          activeIcon: CNSymbol('square.grid.2x2.fill', size: _iconSize),
        ),
        CNTabBarItem(label: 'مواعيدي', icon: CNSymbol('calendar', size: _iconSize), activeIcon: CNSymbol('calendar', size: _iconSize)),
        CNTabBarItem(label: 'حسابي', icon: CNSymbol('person.crop.circle', size: _iconSize), activeIcon: CNSymbol('person.crop.circle.fill', size: _iconSize)),
      ],
    );
  }
}
