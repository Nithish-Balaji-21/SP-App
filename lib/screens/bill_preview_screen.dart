import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/bill.dart';
import '../utils/pdf_generator.dart';
import 'new_bill_screen.dart';

class BillPreviewScreen extends StatefulWidget {
  const BillPreviewScreen({super.key, required this.bill});

  final Bill bill;

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  static const Color _inkBlue = Color(0xFF445E9A);
  bool _busy = false;
  late Bill _bill;

  @override
  void initState() {
    super.initState();
    _bill = widget.bill;
  }

  List<BillItem> get _filledItems => _bill.items
      .where((e) => e.name.trim().isNotEmpty)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Preview'),
        actions: [
          IconButton(
            tooltip: 'Edit Bill',
            icon: const Icon(Icons.edit),
            onPressed: _busy ? null : _editBill,
          ),
          IconButton(
            tooltip: 'Delete Bill',
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _deleteBill,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AspectRatio(aspectRatio: 0.82, child: _billSlipCard()),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _sharePdf,
                    icon: const Icon(Icons.share),
                    label: const Text('Share PDF'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _printPdf,
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Back'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billSlipCard() {
    final bill = _bill;
    final rows = _buildRows();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _inkBlue, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'No.',
                    style: TextStyle(color: _inkBlue, fontSize: 11),
                  ),
                  const Spacer(),
                  const Text(
                    'CASH BILL',
                    style: TextStyle(
                      color: _inkBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Ph: +91 9865605061',
                    style: const TextStyle(color: _inkBlue, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _inkBlue, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: const Text(
                  'STATE PHARMACY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _inkBlue,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                '10, Kamarajar Bus Stand,North-West Municipal Complex,Dindigul.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _inkBlue, fontSize: 9.5),
              ),
              const SizedBox(height: 6),
              _lineField(
                label: 'Name',
                value: bill.patientName,
                tailLabel: 'Date',
                tailValue: DateFormat('dd/MM/yyyy').format(bill.date),
              ),
              const SizedBox(height: 2),
              _lineField(label: 'Dr.', value: bill.doctorName),
              const SizedBox(height: 5),
              Table(
                border: TableBorder.all(color: _inkBlue, width: 1),
                columnWidths: const {
                  0: FlexColumnWidth(0.9),
                  1: FlexColumnWidth(2.8),
                  2: FlexColumnWidth(1.45),
                  3: FlexColumnWidth(0.9),
                  4: FlexColumnWidth(0.5),
                },
                children: [
                  const TableRow(
                    children: [
                      _SlipCell('Qty', header: true, align: TextAlign.center),
                      _SlipCell('Particulars', header: true),
                      _SlipCell('B.N. ED', header: true),
                      _SlipCell('Rs.', header: true, align: TextAlign.right),
                      _SlipCell('P.', header: true, align: TextAlign.right),
                    ],
                  ),
                  ...rows.map(
                    (row) => TableRow(
                      children: [
                        _SlipCell(row.qty, align: TextAlign.center),
                        _SlipCell(row.particulars),
                        _SlipCell(row.batchEd),
                        _SlipCell(row.rs, align: TextAlign.right),
                        _SlipCell(row.paise, align: TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      'DL.No:2561 / MDU 20-21',
                      style: TextStyle(color: _inkBlue, fontSize: 11),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _totalLine('DISCOUNT', '0.00', bold: false),
                      _totalLine(
                        'TOTAL',
                        '${bill.totalPaise ~/ 100}.${(bill.totalPaise % 100).toString().padLeft(2, '0')}',
                        bold: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineField({
    required String label,
    required String value,
    String? tailLabel,
    String? tailValue,
  }) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(color: _inkBlue, fontSize: 11)),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _inkBlue, width: 0.9)),
            ),
            child: Text(
              value,
              style: const TextStyle(color: _inkBlue, fontSize: 11),
            ),
          ),
        ),
        if (tailLabel != null) ...[
          const SizedBox(width: 8),
          Text(
            '$tailLabel: ',
            style: const TextStyle(color: _inkBlue, fontSize: 11),
          ),
          Container(
            width: 80,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _inkBlue, width: 0.9)),
            ),
            child: Text(
              tailValue ?? '',
              style: const TextStyle(color: _inkBlue, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }

  Widget _totalLine(String label, String value, {required bool bold}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            color: _inkBlue,
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Container(
          width: 78,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _inkBlue, width: 0.9)),
          ),
          alignment: Alignment.centerRight,
          child: Text(
            value,
            style: TextStyle(
              color: _inkBlue,
              fontSize: 11,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  List<_PreviewRow> _buildRows() {
    final rows = _filledItems
        .map(
          (item) => _PreviewRow(
            qty: item.qty <= 0 ? '' : item.qty.toString(),
            particulars: _cleanMedicineName(item.name),
            batchEd: item.batchEd,
            rs: item.rs <= 0 ? '' : item.rs.toString(),
            paise: item.paise <= 0 ? '' : item.paise.toString().padLeft(2, '0'),
          ),
        )
        .toList();

    while (rows.length < 8) {
      rows.add(const _PreviewRow());
    }
    return rows;
  }

  String _cleanMedicineName(String value) {
    var cleaned = value.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^\d+\s*[-.:)]\s*'), '');
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*\(\s*id\s*[:#-]?\s*\d+\s*\)', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return cleaned;
  }

  Future<void> _sharePdf() async {
    setState(() {
      _busy = true;
    });

    try {
      final file = await PdfGenerator.generateBillPdf(_bill);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'State Pharmacy Bill ${_bill.billNumber}');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _printPdf() async {
    setState(() {
      _busy = true;
    });

    try {
      final bytes = await PdfGenerator.buildBillPdfBytes(_bill);
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _editBill() async {
    final updated = await Navigator.push<Bill>(
      context,
      MaterialPageRoute(builder: (_) => NewBillScreen(bill: _bill)),
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() {
      _bill = updated;
    });
  }

  Future<void> _deleteBill() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Bill'),
          content: Text('Delete Bill No ${_bill.billNumber}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await DatabaseHelper.instance.deleteBillAndRestoreStock(_bill);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }
}

class _SlipCell extends StatelessWidget {
  const _SlipCell(
    this.value, {
    this.header = false,
    this.align = TextAlign.left,
  });

  final String value;
  final bool header;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      alignment: _toAlignment(align),
      child: Text(
        value,
        textAlign: align,
        style: TextStyle(
          color: _BillPreviewScreenState._inkBlue,
          fontSize: 10,
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Alignment _toAlignment(TextAlign value) {
    if (value == TextAlign.right) {
      return Alignment.centerRight;
    }
    if (value == TextAlign.center) {
      return Alignment.center;
    }
    return Alignment.centerLeft;
  }
}

class _PreviewRow {
  const _PreviewRow({
    this.qty = '',
    this.particulars = '',
    this.batchEd = '',
    this.rs = '',
    this.paise = '',
  });

  final String qty;
  final String particulars;
  final String batchEd;
  final String rs;
  final String paise;
}
