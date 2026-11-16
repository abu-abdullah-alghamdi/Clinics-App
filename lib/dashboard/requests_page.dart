/// الطلبات الجديدة: تنتظر تحديد موعد (الأقدم أول)
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../extras.dart';
import '../services_data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'desk.dart';
import 'schedule_sheet.dart';
import 'ui.dart';

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final desk = DeskScope.of(context);
    final list = desk.waiting;
    final wide = deskSize(context) != DeskSize.phone;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 16, 16, 40),
      children: [
        PageHeader(title: 'الطلبات', trailing: list.isEmpty ? null : Tag('${fmtNum(list.length)} بانتظار الموعد', bg: AppColors.white)),
        const BranchFilter(),
        if (list.isEmpty)
          const EmptyNote(icon: CupertinoIcons.checkmark_seal, text: 'كل الطلبات تحدد لها موعد')
        else if (wide)
          LayoutBuilder(
            builder: (context, c) {
              // بطاقتين جنب بعض لو فيه مساحة
              final w = c.maxWidth >= 760 ? (c.maxWidth - 12) / 2 : c.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [for (final r in list) SizedBox(width: w, child: RequestCard(request: r))],
              );
            },
          )
        else
          for (final r in list)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: RequestCard(request: r)),
      ],
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request});

  final DeskRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final b = r.booking;
    final role = DeskScope.of(context).staff?.role;
    final wait = DateTime.now().difference(b.createdAt);
    // كل ما طال الانتظار يبان أكثر (السرعة أهم شيء في الطلب)
    final waitColor = wait.inMinutes >= 180
        ? AppColors.red
        : wait.inMinutes >= 60
            ? const Color(0xFF8A5A00)
            : AppColors.faint;
    return DeskCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(b.number, style: ts(12, color: AppColors.faint)),
              const Spacer(),
              Icon(CupertinoIcons.clock, size: 15, color: waitColor),
              const SizedBox(width: 4),
              Text(ago(b.createdAt), style: ts(13, weight: FontWeight.w500, color: waitColor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PatientAvatar(name: r.patient),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.patient, style: ts(17, weight: FontWeight.w600)),
                    Text(r.phone, textDirection: TextDirection.ltr, style: ts(13, color: AppColors.faint)),
                    if (b.forOther) Text('طلبه له شخص ثاني', style: ts(12, color: AppColors.faint)),
                  ],
                ),
              ),
              if (r.fromApp) const Tag('من المعاينة', bg: Color(0xFFE6EDFD), fg: AppColors.blue),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.title, style: ts(16, weight: FontWeight.w600)),
                      if (b.packageName != null) Text(b.packageName!, style: ts(14, color: AppColors.body)),
                      const SizedBox(height: 2),
                      Text(b.branch.name, style: ts(14, color: AppColors.body)),
                      Text('يفضّل ${b.period.label}، ${b.doctor?.name ?? 'الطبيب المتاح'}', style: ts(14, color: AppColors.body)),
                    ],
                  ),
                ),
                Text(b.priceText, style: ts(16, weight: FontWeight.w600)),
              ],
            ),
          ),
          if (role?.canSchedule ?? false) ...[
            const SizedBox(height: 14),
            if (b.isPackage)
              PillButton(label: 'موافقة على الباقة', icon: Icons.check_rounded, onTap: () => DeskScope.read(context).approve(r))
            else
              PillButton(label: 'حدد الموعد', icon: CupertinoIcons.calendar_badge_plus, onTap: () => openSchedule(context, r)),
          ],
        ],
      ),
    );
  }
}
