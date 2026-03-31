import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/bill.dart';
import '../utils/pdf_generator.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  bool _busy = false;
  List<Bill> _bills = [];

  int get _totalPaise =>
      _bills.fold<int>(0, (sum, bill) => sum + bill.totalPaise);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bills = await DatabaseHelper.instance.getBillsByDateRange(
      _fromDate,
      _toDate,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _bills = bills;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate;
        }
      } else {
        _toDate = picked;
        if (_toDate.isBefore(_fromDate)) {
          _fromDate = _toDate;
        }
      }
    });

    _load();
  }

  Future<void> _exportSummary() async {
    setState(() {
      _busy = true;
    });

    try {
      final file = await PdfGenerator.generateDailySummaryPdf(
        date: _fromDate,
        toDate: _toDate,
        bills: _bills,
        totalPaise: _totalPaise,
      );
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'State Pharmacy Daily Summary');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _printSummary() async {
    setState(() {
      _busy = true;
    });

    try {
      final bytes = await PdfGenerator.buildDailySummaryPdfBytes(
        date: _fromDate,
        toDate: _toDate,
        bills: _bills,
        totalPaise: _totalPaise,
      );
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

  Future<void> _exportNineBills() async {
    setState(() {
      _busy = true;
    });

    try {
      final label =
          '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';
      final file = await PdfGenerator.generateNineBillsA4Pdf(
        bills: _bills,
        dateLabel: label,
      );
      await Share.shareXFiles([XFile(file.path)], text: '9 Bills A4 Sheet');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _printNineBills() async {
    setState(() {
      _busy = true;
    });

    try {
      final label =
          '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';
      final bytes = await PdfGenerator.buildNineBillsA4PdfBytes(
        bills: _bills,
        dateLabel: label,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isFrom: true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'From Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_fromDate)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isFrom: false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'To Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_toDate)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Range: ${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Apply Date Range'),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bills: ${_bills.length}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Revenue: ${_formatMoney(_totalPaise)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Bills List', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._bills.map(
            (bill) => Card(
              child: ListTile(
                title: Text('Bill ${bill.billNumber} - ${bill.patientName}'),
                trailing: Text(
                  _formatMoney(bill.totalPaise),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          if (_bills.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No bills on this date.'),
            ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _exportSummary,
              icon: const Icon(Icons.share),
              label: const Text('Export Summary as PDF'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _printSummary,
              icon: const Icon(Icons.print),
              label: const Text('Print Summary'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _exportNineBills,
              icon: const Icon(Icons.grid_view),
              label: const Text('Export 9 Bills (A4)'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _printNineBills,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print 9 Bills (A4)'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(int paise) {
    final rs = paise / 100;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rs);
  }
}
