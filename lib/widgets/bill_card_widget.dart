import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/bill.dart';

class BillCardWidget extends StatelessWidget {
  const BillCardWidget({
    super.key,
    required this.bill,
    required this.onTap,
    required this.onLongPress,
  });

  final Bill bill;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        title: Text('Bill No: ${bill.billNumber}'),
        subtitle: Text(
          '${bill.patientName}\n${DateFormat('dd/MM/yyyy').format(bill.date)}',
        ),
        trailing: Text(
          _formatMoney(bill.totalPaise),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        isThreeLine: true,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  String _formatMoney(int paise) {
    final inr = paise / 100;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(inr);
  }
}
