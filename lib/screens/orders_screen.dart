import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../payments.dart';
import '../services_data.dart';
import '../state.dart';
import '../states.dart';
import '../theme.dart';
import '../widgets.dart';

String _date(DateTime d) => '${fmtNum(d.day)} ${monthNames[d.month - 1]} ${fmtNum(d.year)}';

/// بطاقة عملية دفع: رقمها، الخدمة، الفرع، طريقة الدفع، الإجمالي
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(32),
        border: highContrast(context) ? Border.all(color: AppColors.ink, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('عملية #${order.number}', style: ts(18, weight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                child: Text('مدفوع', style: ts(13, weight: FontWeight.w600, color: AppColors.onAccent)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(lines([_date(order.date), branchById(order.branchId).name, order.method.label]), style: ts(13, color: AppColors.faint)),
          const SizedBox(height: 8),
          if (order.forOther)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('لـ ${order.recipientName}', style: ts(14, weight: FontWeight.w600)),
            ),
          for (final it in order.items)
            amountRow(it.label, money(it.total)),
          if (order.discount > 0) amountRow('خصم ${order.coupon ?? ''}', '- ${money(order.discount)}'),
          const Divider(color: AppColors.bg, height: 16, thickness: 1.5),
          amountRow('الإجمالي', money(order.total), bold: true),
        ],
      ),
    );
  }
}

/// المدفوعات (من صفحة "حسابي")
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        top: false,
        child: FloatingBar(title: 'المدفوعات', body: ListView(
          padding: EdgeInsets.fromLTRB(14, FloatingBar.safeTop(context) + FloatingBar.contentTop, 14, 30),
          children: [
            if (s.orders.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 50),
                child: Column(
                  children: [
                    const Icon(CupertinoIcons.doc_text, size: 44, color: AppColors.faint),
                    const SizedBox(height: 12),
                    Text('ما عندك مدفوعات حتى الآن', style: ts(20)),
                  ],
                ),
              )
            else
              for (final o in s.orders) ...[
                OrderCard(order: o),
                const SizedBox(height: 10),
              ],
          ],
        )),
      ),
    );
  }
}
