/// معاينة التطبيق داخل اللوحة: التطبيق نفسه في إطار جوال، يشارك اللوحة نفس البيانات
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../clinic_config.dart';
import '../main.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// مقاس آيفون (بالنقاط) ومسافات الحواف فيه
const _phone = Size(393, 852);
const _insets = EdgeInsets.only(top: 59, bottom: 34);

class AppPreview extends StatelessWidget {
  const AppPreview({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: FittedBox(
          child: Container(
            width: _phone.width + 24,
            height: _phone.height + 24,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(66),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 18))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(54),
              child: MediaQuery(
                data: MediaQueryData(
                  size: _phone,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  padding: _insets,
                  viewPadding: _insets,
                  textScaler: TextScaler.noScaling,
                ),
                child: const Stack(
                  children: [
                    Positioned.fill(child: ClinicsApp()),
                    // الجزيرة فوق
                    Positioned(
                      top: 11,
                      left: 0,
                      right: 0,
                      child: Center(child: SizedBox(width: 124, height: 36, child: DecoratedBox(decoration: ShapeDecoration(color: Color(0xFF000000), shape: StadiumBorder())))),
                    ),
                    Positioned(top: 8, left: 10, right: 10, child: _NoticeBanner()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// إشعار يوصل للمريض لما العيادة تحدد موعده (مثل إشعار آيفون)
class _NoticeBanner extends StatefulWidget {
  const _NoticeBanner();

  @override
  State<_NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<_NoticeBanner> {
  ValueNotifier<PatientNotice?>? _source;
  PatientNotice? _notice;
  bool _shown = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    // الإشعار يجي من التطبيق نفسه لما يوصله تحديث من العيادة (مثل إشعار الجوال)
    _source = appState.notice..addListener(_onNotice);
  }

  void _onNotice() {
    final n = _source?.value;
    if (n == null || !mounted) return;
    _hide?.cancel();
    setState(() {
      _notice = n;
      _shown = true;
    });
    _hide = Timer(const Duration(seconds: 6), _dismiss);
  }

  void _dismiss() {
    if (mounted) setState(() => _shown = false);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _source?.removeListener(_onNotice);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _notice;
    if (n == null) return const SizedBox.shrink();
    final clinic = ClinicConfig.current;
    return IgnorePointer(
      ignoring: !_shown,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, -1.6),
        duration: motion(context, 380),
        curve: Curves.easeOutCubic,
        child: Pressable(
          onTap: () {
            // يفتح مواعيدي مثل الضغط على الإشعار
            appState.setTab(1);
            _dismiss();
          },
          semanticLabel: '${n.title}، ${n.body}',
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xF7FFFFFF),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                  child: Text(clinic.monogram, style: ts(18, weight: FontWeight.w700, color: AppColors.onAccent)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(clinic.appName, style: ts(13, color: AppColors.faint))),
                          Text('الآن', style: ts(13, color: AppColors.faint)),
                        ],
                      ),
                      Text(n.title, style: ts(15, weight: FontWeight.w600)),
                      Text(n.body, style: ts(14, color: AppColors.body)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
