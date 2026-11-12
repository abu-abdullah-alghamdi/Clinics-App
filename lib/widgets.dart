import 'dart:ui' show ImageFilter;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'services_data.dart';
import 'theme.dart';

/// يحوّل أي رقم عربي يكتبه المستخدم (٠١٢…) إلى إنجليزي (012…) أثناء الكتابة
class WesternDigits extends TextInputFormatter {
  const WesternDigits();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = normalizeDigits(newValue.text);
    if (text == newValue.text) return newValue;
    return newValue.copyWith(text: text);
  }
}

/// اسم الخط المدمج في التطبيق (pubspec.yaml ← fonts)
const appFont = 'IBMPlexSansArabic';

/// خط فيه رمز الريال السعودي بس
const riyalFont = 'SaudiRiyal';

/// نمط الخط الموحد للتطبيق (IBM Plex Sans Arabic)
TextStyle ts(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
  TextDecoration? decoration,
}) {
  final c = color ?? AppColors.ink;
  return TextStyle(
    fontFamily: appFont,
    // رمز الريال مو موجود في خط IBM Plex، فيجي من خطه الخاص
    fontFamilyFallback: const [riyalFont],
    fontSize: size,
    fontWeight: weight,
    color: c,
    height: height,
    decoration: decoration,
    decorationColor: c,
  );
}

/// يصغّر العنصر شوي عند الضغط مثل أزرار iOS (إلا إذا "تقليل الحركة" مفعّل)
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: active,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? (_) => _set(true) : null,
        onTapUp: active ? (_) => _set(false) : null,
        onTapCancel: active ? () => _set(false) : null,
        onTap: active ? widget.onTap : null,
        child: AnimatedScale(
          scale: _down && !reduce ? 0.96 : 1,
          duration: motion(context, 120),
          // مع "تقليل الحركة" الضغط يخفّت الزر بدل ما يصغّره
          child: Opacity(opacity: _down && reduce ? 0.6 : 1, child: widget.child),
        ),
      ),
    );
  }
}

/// زر كبسولة (ارتفاعه يكبر مع تكبير الخط)
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onTap,
    this.bg,
    this.fg,
    this.icon,
    this.height = 50,
    this.enabled = true,
    this.fontSize = 17,
    this.weight = FontWeight.w500,
    this.border,
    this.padding = 24,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? bg;
  final Color? fg;
  final IconData? icon;
  final double height;
  final bool enabled;
  final double fontSize;
  final FontWeight weight;
  final BoxBorder? border;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final base = bg ?? AppColors.accent;
    final b = enabled ? base : AppColors.disabled;
    final f = enabled ? (fg ?? fgOn(base)) : AppColors.disabledText;
    return Pressable(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: motion(context, 250),
        constraints: BoxConstraints(minHeight: height),
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
        decoration: BoxDecoration(color: b, borderRadius: BorderRadius.circular(999), border: border),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: f, size: 22),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(label, textAlign: TextAlign.center, style: ts(fontSize, weight: weight, color: f), maxLines: 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر دائري
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.bg,
    this.fg,
    this.semanticLabel,
    this.border,
    this.enabled = true,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? bg;
  final Color? fg;
  final String? semanticLabel;
  final BoxBorder? border;
  final bool enabled;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final base = bg ?? AppColors.white;
    return Pressable(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: semanticLabel,
      child: AnimatedContainer(
        duration: motion(context, 250),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: enabled ? base : AppColors.disabled,
          shape: BoxShape.circle,
          border: border,
        ),
        child: Icon(icon, color: enabled ? (fg ?? fgOn(base)) : AppColors.disabledText, size: iconSize),
      ),
    );
  }
}

/// زر الرجوع (السهم يتبع اتجاه العربي تلقائياً) أو الإغلاق في النوافذ المنبثقة
class BackCircle extends StatelessWidget {
  const BackCircle({super.key, this.onTap, this.close = false});

  final VoidCallback? onTap;
  final bool close;

  @override
  Widget build(BuildContext context) => AppleIconButton(
        // التطبيق عربي دايماً: سهم الرجوع يشير لليمين
        symbol: close ? 'xmark' : 'chevron.right',
        fallback: close ? CupertinoIcons.xmark : CupertinoIcons.back,
        label: close ? 'إغلاق' : 'رجوع',
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
      );
}

/// زجاج آبل الحقيقي متاح (iOS 26 وأحدث)
bool get nativeGlass => defaultTargetPlatform == TargetPlatform.iOS && PlatformVersion.shouldUseNativeControls;

/// زر دائري من آبل نفسها (زجاج iOS 26) للأزرار الثابتة فوق الصفحة.
/// على الأنظمة الأقدم يطلع زجاج مرسوم من التطبيق بنفس الحجم.
/// ملاحظة: ما يُستخدم داخل محتوى يتحرك مع التمرير
class AppleIconButton extends StatelessWidget {
  const AppleIconButton({
    super.key,
    required this.symbol,
    required this.fallback,
    required this.label,
    required this.onTap,
    this.prominent = false,
    this.tint,
    this.iconColor,
    this.badge,
  });

  /// اسم أيقونة آبل (SF Symbol)
  final String symbol;

  /// نفس الأيقونة للأنظمة الأقدم
  final IconData fallback;
  final String label;
  final VoidCallback onTap;

  /// زجاج بارز ملوّن (لأهم زر)
  final bool prominent;
  final Color? tint;
  /// لون الأيقونة (الافتراضي: الأسود، وفوق الزر البارز لون النص المناسب فوق لونه)
  final Color? iconColor;

  /// رقم صغير فوق الزر (مثل عدد السلة)
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final count = badge == null || badge == 0 ? null : badge;
    final iconColor = this.iconColor ?? (prominent ? fgOn(tint ?? AppColors.accent) : AppColors.ink);
    if (nativeGlass) {
      return CNButton.icon(
        icon: CNSymbol(symbol, size: 19, color: iconColor),
        tint: tint,
        badgeCount: count,
        semanticLabel: count == null ? label : '$label، $count',
        config: CNButtonConfig(style: prominent ? CNButtonStyle.prominentGlass : CNButtonStyle.glass),
        onPressed: onTap,
      );
    }
    return Pressable(
      onTap: onTap,
      semanticLabel: count == null ? label : '$label، $count',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          prominent
              ? Container(
                  width: GlassCircle.barSize,
                  height: GlassCircle.barSize,
                  decoration: BoxDecoration(color: tint ?? AppColors.accent, shape: BoxShape.circle),
                  child: Icon(fallback, size: 20, color: iconColor),
                )
              : GlassCircle(child: Icon(fallback, size: 19, color: iconColor)),
          if (count != null)
            PositionedDirectional(
              top: -4,
              end: -4,
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                  child: Text(fmtNum(count), style: ts(11, weight: FontWeight.w700, color: AppColors.white, height: 1)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// أزرار من آبل تتشارك قطعة زجاج وحدة (مثل المشاركة والمفضلة)
class AppleButtonGroup extends StatelessWidget {
  const AppleButtonGroup({super.key, required this.buttons, required this.id});

  final List<AppleIconButton> buttons;

  /// اسم المجموعة (لازم يكون مميز في الصفحة)
  final String id;

  @override
  Widget build(BuildContext context) {
    if (!nativeGlass) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final b in buttons) ...[if (b != buttons.first) const SizedBox(width: 8), b],
        ],
      );
    }
    return Semantics(
      label: buttons.map((b) => b.label).join('، '),
      child: CNGlassButtonGroup(
        buttons: [
          for (final b in buttons)
            CNButtonData.icon(
              icon: CNSymbol(b.symbol, size: 19, color: b.iconColor),
              onPressed: b.onTap,
              config: CNButtonDataConfig(glassEffectUnionId: id),
            ),
        ],
      ),
    );
  }
}

/// دائرة زجاجية مثل أزرار iOS 26: شفافة، تغبّش اللي تحتها، وحافتها لامعة.
/// مع "زيادة التباين" ترجع بيضاء صلبة بحد واضح
class GlassCircle extends StatelessWidget {
  const GlassCircle({super.key, required this.child, this.size = barSize});

  /// حجم أزرار الشريط في آبل
  static const barSize = 44.0;

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final solid = highContrast(context);
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: solid ? AppColors.white : null,
              // لمعة خفيفة من فوق مثل الزجاج
              gradient: solid
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xB8FFFFFF), Color(0x80FFFFFF)],
                    ),
              border: Border.all(
                color: solid ? AppColors.ink : const Color(0xCCFFFFFF),
                width: solid ? 1.5 : 1,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// أزرار زجاجية ثابتة أعلى الصفحة، والمحتوى يمر تحتها وأنت تنزل (مثل iOS 26)
class FloatingBar extends StatelessWidget {
  const FloatingBar({
    super.key,
    required this.body,
    this.title,
    this.leading = const BackCircle(),
    this.trailing = const [],
    this.side = 14,
  });

  /// عنوان الصفحة: ثابت فوق بين الأزرار
  final String? title;

  /// بعد الأزرار من أعلى الصفحة
  static const top = 14.0;

  /// أسفل سطر الأزرار
  static const belowBar = top + GlassCircle.barSize;

  /// بداية المحتوى عشان يبدأ تحت الأزرار
  static const contentTop = belowBar + 14;

  /// ارتفاع منطقة الساعة: الصفحة تبدأ من أعلى الشاشة والمحتوى يمر تحت الساعة،
  /// فكل صفحة تضيفه لبداية محتواها
  static double safeTop(BuildContext context) => MediaQuery.paddingOf(context).top;

  final Widget body;
  final Widget? leading;
  final List<Widget> trailing;
  final double side;

  @override
  Widget build(BuildContext context) {
    final inset = safeTop(context);
    // التلاشي يغطي الساعة والأزرار ثم يخف تدريجياً بدون حد واضح
    final fadeHeight = inset + belowBar + 34;
    final solid = (inset + top) / fadeHeight;
    final bar = (inset + belowBar) / fadeHeight;
    return Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: fadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, solid, bar, bar + (1 - bar) * 0.4, bar + (1 - bar) * 0.75, 1],
                  colors: [
                    AppColors.bg.withAlpha(250),
                    AppColors.bg.withAlpha(235),
                    AppColors.bg.withAlpha(190),
                    AppColors.bg.withAlpha(110),
                    AppColors.bg.withAlpha(40),
                    AppColors.bg.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: inset + top,
          start: side,
          end: side,
          child: SizedBox(
            height: GlassCircle.barSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: GlassCircle.barSize * 2 + 16),
                    child: Semantics(
                      header: true,
                      child: Text(
                        title!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(18, weight: FontWeight.w500),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    if (leading != null) leading!,
                    const Spacer(),
                    for (final w in trailing) ...[if (w != trailing.first) const SizedBox(width: 8), w],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// العنوان الكبير
class BigTitle extends StatelessWidget {
  const BigTitle(this.text, {super.key, this.size = 42});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Semantics(
          header: true,
          child: Text(text, style: ts(size, color: AppColors.title, height: 1.15)),
        ),
      );
}

/// بطاقة كبيرة وصورة الطبيب مقصوصة في الطرف الأيسر
class CutCard extends StatelessWidget {
  const CutCard({
    super.key,
    required this.image,
    required this.children,
    this.bottom,
    this.imageWidth = 196,
    this.imageHeight = 272,
    this.textWidth = 185,
    this.padding = const EdgeInsets.fromLTRB(26, 30, 26, 22),
    this.radius = 46,
    this.shadow = true,
    this.corner,
    this.borderColor,
  });

  /// زر صغير في الزاوية العلوية (مثل قلب المفضلة)
  final Widget? corner;

  final String image;
  final List<Widget> children;
  final Widget? bottom;
  final double imageWidth;
  final double imageHeight;
  final double textWidth;
  final EdgeInsets padding;
  final double radius;
  final bool shadow;

  /// حد ملوّن حول البطاقة (مثل الموعد اللي ألغته العيادة)
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    // مع تكبير الخط، نوسّع عمود النص ونصغّر الصورة عشان ما يتداخلون
    final scale = (MediaQuery.textScalerOf(context).scale(100) / 100).clamp(1.0, 2.0);
    final tw = (textWidth * scale).clamp(textWidth, 300.0);
    final iw = scale > 1.35 ? imageWidth * 0.75 : imageWidth;
    final ih = scale > 1.35 ? imageHeight * 0.75 : imageHeight;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ? cardShadow : null,
        border: highContrast(context)
            ? Border.all(color: AppColors.ink, width: 1.5)
            : (borderColor == null ? null : Border.all(color: borderColor!, width: 2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: -14,
            bottom: 0,
            width: iw,
            height: ih,
            child: ExcludeSemantics(
              child: Image.asset(image, fit: BoxFit.contain, alignment: Alignment.bottomLeft),
            ),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: SizedBox(
                    width: tw,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
                  ),
                ),
                if (bottom != null) ...[const SizedBox(height: 26), bottom!],
              ],
            ),
          ),
          if (corner != null) PositionedDirectional(top: 16, end: 16, child: corner!),
        ],
      ),
    );
  }
}

/// كبسولة يوم طويلة (رقم اليوم واسمه)
class DayPill extends StatelessWidget {
  const DayPill({
    super.key,
    required this.top,
    required this.bottom,
    required this.selected,
    required this.semanticLabel,
    this.closed = false,
    this.dot = false,
    this.onTap,
  });

  final String top;
  final String bottom;
  final bool selected;
  final bool closed;
  final bool dot;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    final bg = selected ? AppColors.accent : (closed ? AppColors.closed : AppColors.white);
    final fg = selected ? AppColors.onAccent : (closed ? AppColors.closedText : AppColors.ink);
    return Pressable(
      onTap: onTap,
      enabled: !closed,
      selected: selected,
      semanticLabel: '$semanticLabel${closed ? '، مغلق' : ''}${dot ? '، فيه موعد' : ''}',
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2.0,
        child: AnimatedContainer(
          duration: motion(context, 250),
          width: 70 * s,
          height: 100 * s,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: pillShadow,
            border: selected && highContrast(context) ? Border.all(color: AppColors.ink, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(top, style: ts(21, weight: FontWeight.w500, color: fg)),
              const SizedBox(height: 2),
              Text(bottom, style: ts(13, color: fg)),
              if (dot) ...[
                const SizedBox(height: 4),
                Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// كبسولة فلتر (الكل / أسنان ...)
class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: label,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 2.0,
          child: AnimatedContainer(
            duration: motion(context, 250),
            height: 44 * uiScale(context),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : AppColors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label, style: ts(16, color: selected ? AppColors.white : AppColors.ink)),
          ),
        ),
      );
}

/// صف أفقي يتمرر بعرض الشاشة (ارتفاعه يكبر شوي مع تكبير الخط)
class HScroll extends StatelessWidget {
  const HScroll({super.key, required this.height, required this.children, this.gap = 8});

  final double height;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height * uiScale(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          clipBehavior: Clip.none,
          itemCount: children.length,
          separatorBuilder: (_, _) => SizedBox(width: gap),
          itemBuilder: (_, i) => children[i],
        ),
      );
}

/// مربع اختيار
class AppCheck extends StatelessWidget {
  const AppCheck({super.key, required this.value, required this.onChanged, required this.child});

  final bool value;
  final VoidCallback onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: value,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChanged,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: motion(context, 200),
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: value ? AppColors.accent : AppColors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppColors.ink, width: 1.5),
                  ),
                  child: value ? const Icon(Icons.check_rounded, size: 18, color: AppColors.onAccent) : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      );
}

/// حقل إدخال كبسولة
InputDecoration pillInput(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: ts(16, color: AppColors.faint),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
      ),
    );

/// نافذة منبثقة بأسلوب iOS 26: زجاج، تطفو بهوامش عن أطراف الشاشة، ولها مقبض سحب
Future<void> showAppSheet(BuildContext context, {required String title, required List<Widget> children}) {
  return showGlassSheet<void>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(title, style: ts(22, weight: FontWeight.w500))),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

/// يفتح نافذة زجاجية عائمة (نفس نوافذ آبل الأصلية)
Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scrollControlled = true}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x33000000),
    isScrollControlled: scrollControlled,
    useSafeArea: true,
    builder: (ctx) => GlassSheet(child: builder(ctx)),
  );
}

/// غلاف النافذة الزجاجية: هامش 8 من الأطراف، حواف دائرية كبيرة، تغبيش خلفي، ومقبض
class GlassSheet extends StatelessWidget {
  const GlassSheet({super.key, required this.child, this.fill = false});

  final Widget child;

  /// تاخذ الارتفاع كامل (للقوائم الطويلة اللي تنسحب لفوق)
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final solid = highContrast(context);
    const radius = BorderRadius.all(Radius.circular(36));
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, keyboard > 0 ? keyboard + 8 : (safeBottom > 0 ? safeBottom * 0.35 + 4 : 8)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: radius,
          boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 30, offset: Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: solid ? AppColors.white : const Color(0xEBFFFFFF),
                borderRadius: radius,
                border: Border.all(color: solid ? AppColors.ink : const Color(0xB3FFFFFF), width: solid ? 1.5 : 1),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // مقبض السحب
                    Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        margin: const EdgeInsets.only(top: 8, bottom: 14),
                        decoration: BoxDecoration(color: const Color(0x4D3C3C43), borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    if (fill) Expanded(child: child) else Flexible(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// صفحة تبويب بعنوان كبير يصغر ويثبت فوق في شريط زجاجي وأنت تمرر (مثل الإعدادات والصور)
class LargeTitleScroll extends StatelessWidget {
  const LargeTitleScroll({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.onRefresh,
    this.horizontal = 0,
    this.bottomSpace = 0,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  /// السحب لتحت للتحديث
  final Future<void> Function()? onRefresh;
  final double horizontal;
  final double bottomSpace;

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.ink,
        textTheme: CupertinoTextThemeData(
          textStyle: ts(17),
          navTitleTextStyle: ts(17, weight: FontWeight.w600),
          navLargeTitleTextStyle: ts(36, color: AppColors.title, height: 1.2),
        ),
      ),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            // العنوان الكبير مساحته ثابتة في شريط آبل، فنحد تكبيره عشان ما ينقص
            largeTitle: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: Semantics(header: true, child: Text(title, maxLines: 1)),
            ),
            trailing: trailing,
            automaticallyImplyLeading: false,
            transitionBetweenRoutes: false,
            backgroundColor: highContrast(context) ? AppColors.bg : AppColors.bg.withValues(alpha: 0.78),
            border: null,
            // مسافة تحت سطر الأزرار مثل شريط آبل، عشان الزر ما يلمس حافة الشريط
            bottom: const PreferredSize(preferredSize: Size.fromHeight(10), child: SizedBox.shrink()),
            bottomMode: NavigationBarBottomMode.always,
          ),
          if (onRefresh != null) CupertinoSliverRefreshControl(onRefresh: onRefresh),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, bottomSpace),
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ],
      ),
    );
  }
}

/// زر في قائمة الضغط المطوّل
class PeekAction {
  const PeekAction(this.label, this.icon, this.onTap, {this.destructive = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
}

/// الضغط المطوّل على البطاقة: معاينة مرفوعة وقائمة سريعة (مثل آبل)
class PeekMenu extends StatelessWidget {
  const PeekMenu({super.key, required this.child, required this.actions, this.inset = 14});

  final Widget child;
  final List<PeekAction> actions;

  /// هامش البطاقة من أطراف الشاشة (عشان نعطيها عرض ثابت في المعاينة)
  final double inset;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - inset * 2;
    return CupertinoContextMenu(
      actions: [
        for (final a in actions)
          CupertinoContextMenuAction(
            isDestructiveAction: a.destructive,
            trailingIcon: a.icon,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              a.onTap();
            },
            child: Text(a.label, style: ts(17, color: a.destructive ? AppColors.red : AppColors.ink)),
          ),
      ],
      // المعاينة تحتاج عرض ثابت، والـ Material عشان الكلام ياخذ نفس الخط بدون خطوط تحته
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(width: width, child: child),
      ),
    );
  }
}

/// زر القلب للمفضلة (فاضي / معبّى)
class FavButton extends StatelessWidget {
  const FavButton({
    super.key,
    required this.active,
    required this.onTap,
    required this.name,
    this.size = 44,
    this.bg,
    this.glass = false,
  });

  final bool active;
  final VoidCallback onTap;
  final String name;
  final double size;
  final Color? bg;

  /// زجاج iOS 26 (فوق الصور وأعلى الصفحة)
  final bool glass;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        selected: active,
        semanticLabel: active ? 'إزالة $name من المفضلة' : 'إضافة $name للمفضلة',
        child: glass
            ? GlassCircle(size: size, child: _heart(context))
            : AnimatedContainer(
                duration: motion(context, 200),
                width: size,
                height: size,
                decoration: BoxDecoration(color: bg ?? AppColors.white, shape: BoxShape.circle, boxShadow: pillShadow),
                child: _heart(context),
              ),
      );

  Widget _heart(BuildContext context) => AnimatedSwitcher(
        duration: motion(context, 180),
        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
        child: Icon(
          active ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
          key: ValueKey(active),
          size: size * 0.46,
          color: AppColors.ink,
        ),
      );
}

/// صف في ملخص المبلغ
Widget amountRow(String label, String value, {bool bold = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: ts(bold ? 17 : 15, weight: bold ? FontWeight.w600 : FontWeight.w400, color: color ?? (bold ? AppColors.ink : AppColors.body))),
          ),
          Text(value, style: ts(bold ? 19 : 15, weight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
        ],
      ),
    );

/// ملخص المبلغ: المجموع والضريبة والإجمالي
class AmountSummary extends StatelessWidget {
  const AmountSummary({super.key, required this.subtotal, required this.vat, this.discount = 0, this.discountLabel = 'الخصم'});

  final num subtotal;
  final double vat;

  /// خصم كود الخصم (بالريال)
  final num discount;
  final String discountLabel;

  @override
  Widget build(BuildContext context) {
    final total = subtotal - discount + vat;
    final detailed = vat > 0 || discount > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(32)),
      child: Column(
        children: detailed
            ? [
                amountRow('المجموع', money(subtotal)),
                if (discount > 0) amountRow(discountLabel, '- ${money(discount)}', color: AppColors.green),
                if (vat > 0) amountRow('ضريبة القيمة المضافة (${fmtNum((vatRate * 100).round())}%)', money(vat)),
                const Divider(color: AppColors.bg, height: 18, thickness: 1.5),
                amountRow('الإجمالي', money(total), bold: true),
              ]
            // المواطن السعودي (والزائر قبل التسجيل): الإجمالي بس
            : [amountRow('الإجمالي', money(total), bold: true)],
      ),
    );
  }
}

/// هامش الصفحات الجانبي
Widget px(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: child);

/// عنوان الصفحة في نفس سطر الأزرار الزجاجية (ينزل مع المحتوى والأزرار تبقى ثابتة)
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: GlassCircle.barSize,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GlassCircle.barSize + 8),
          child: Center(
            child: Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(18, weight: FontWeight.w500)),
            ),
          ),
        ),
      );
}

/// منطقة الزر الأساسي أسفل الصفحة (بعرض الشاشة)
class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: SizedBox(width: double.infinity, child: child),
      );
}

/// صورة الطبيب في دائرة ليمونية
class DoctorAvatar extends StatelessWidget {
  const DoctorAvatar({super.key, required this.doctor, required this.size});

  final Doctor doctor;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
        child: Image.asset(doctor.image, fit: BoxFit.cover, alignment: Alignment.topCenter),
      );
}

/// دائرة الاختيار في القوائم (تتعبّى ليموني مع علامة صح)
class SelectDot extends StatelessWidget {
  const SelectDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: motion(context, 200),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ink, width: 1.5),
        ),
        child: selected ? const Icon(Icons.check_rounded, size: 18, color: AppColors.onAccent) : null,
      );
}

/// شريط الأيام: أسبوعين من اليوم، والجمعة مغلقة
class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.selected, required this.onSelect});

  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => HScroll(
        height: 106,
        children: [
          for (final day in [for (var i = 0; i < 14; i++) DayInfo(i)])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: DayPill(
                top: day.dayNum,
                bottom: day.closed ? 'مغلق' : day.short,
                semanticLabel: day.full,
                closed: day.closed,
                selected: selected == day.offset,
                onTap: () => onSelect(day.offset),
              ),
            ),
        ],
      );
}

/// علامة "تمت الإضافة" لحظة بعد الإضافة للسلة، وبعدها يرجع الزر لحالته
mixin AddedFlash<T extends StatefulWidget> on State<T> {
  bool added = false;

  void flashAdded(Duration duration, {VoidCallback? onReset}) {
    HapticFeedback.lightImpact();
    setState(() => added = true);
    Future.delayed(duration, () {
      if (!mounted) return;
      setState(() {
        added = false;
        onReset?.call();
      });
    });
  }
}

/// اختيار بين خيارين أو أكثر في كبسولة وحدة (مثل "لي / لشخص ثاني")
class SegmentedPill extends StatelessWidget {
  const SegmentedPill({super.key, required this.options, required this.selected, required this.onChanged});

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(999)),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: Pressable(
                  onTap: () {
                    if (i == selected) return;
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  selected: i == selected,
                  semanticLabel: options[i],
                  child: AnimatedContainer(
                    duration: motion(context, 200),
                    constraints: BoxConstraints(minHeight: 44 * uiScale(context)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? AppColors.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(options[i], style: ts(16, weight: FontWeight.w500, color: i == selected ? AppColors.white : AppColors.ink)),
                  ),
                ),
              ),
          ],
        ),
      );
}
