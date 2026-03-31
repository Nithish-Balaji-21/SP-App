import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/bill.dart';

class PdfGenerator {
  static final DateFormat _displayDate = DateFormat('dd/MM/yyyy');
  static final PdfColor _inkBlue = PdfColor.fromInt(0xFF445E9A);

  static Future<List<int>> buildBillPdfBytes(Bill bill) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(14),
        build: (context) {
          return _slipTemplate(bill, compact: false);
        },
      ),
    );

    return doc.save();
  }

  static Future<File> generateBillPdf(Bill bill) async {
    final bytes = await buildBillPdfBytes(bill);
    final dir = await _getPreferredStorageDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/bill_${bill.billNumber}_$stamp.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<List<int>> buildDailySummaryPdfBytes({
    required DateTime date,
    required List<Bill> bills,
    required int totalPaise,
    DateTime? toDate,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return [
            pw.Text(
              'STATE PHARMACY',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              toDate == null
                  ? 'Daily Summary - ${_displayDate.format(date)}'
                  : 'Summary - ${_displayDate.format(date)} to ${_displayDate.format(toDate)}',
            ),
            pw.SizedBox(height: 8),
            pw.Text('Total Bills: ${bills.length}'),
            pw.Text('Total Revenue: ${_formatMoneyInr(totalPaise)}'),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.3),
                1: const pw.FlexColumnWidth(2.6),
                2: const pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  children: [
                    _cell('Bill No', isHeader: true),
                    _cell('Name', isHeader: true),
                    _cell('Amount', isHeader: true),
                  ],
                ),
                ...bills.map(
                  (bill) => pw.TableRow(
                    children: [
                      _cell(bill.billNumber),
                      _cell(bill.patientName),
                      _cell(
                        _formatMoneyInr(bill.totalPaise),
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('DL.No.2561 / MDU 20-21'),
          ];
        },
      ),
    );

    return doc.save();
  }

  static Future<File> generateDailySummaryPdf({
    required DateTime date,
    required List<Bill> bills,
    required int totalPaise,
    DateTime? toDate,
  }) async {
    final bytes = await buildDailySummaryPdfBytes(
      date: date,
      bills: bills,
      totalPaise: totalPaise,
      toDate: toDate,
    );

    final dir = await _getPreferredStorageDirectory();
    final stamp = DateFormat('yyyyMMdd').format(date);
    final file = File('${dir.path}/daily_summary_$stamp.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<List<int>> buildNineBillsA4PdfBytes({
    required List<Bill> bills,
    required String dateLabel,
  }) async {
    final doc = pw.Document();
    final pages = <List<Bill>>[];
    const slipsPerPage = 6;

    for (var i = 0; i < bills.length; i += slipsPerPage) {
      final end = (i + slipsPerPage < bills.length)
          ? i + slipsPerPage
          : bills.length;
      pages.add(bills.sublist(i, end));
    }
    if (pages.isEmpty) {
      pages.add(<Bill>[]);
    }

    for (final pageBills in pages) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  dateLabel,
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.right,
                ),
                pw.SizedBox(height: 6),
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey300,
                      width: 0.5,
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(1),
                    },
                    children: List.generate(3, (row) {
                      return pw.TableRow(
                        children: List.generate(2, (col) {
                          final index = (row * 2) + col;
                          final bill = index < pageBills.length
                              ? pageBills[index]
                              : null;
                          return pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: _slipTemplate(bill, compact: true),
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
    return doc.save();
  }

  static Future<File> generateNineBillsA4Pdf({
    required List<Bill> bills,
    required String dateLabel,
  }) async {
    final bytes = await buildNineBillsA4PdfBytes(
      bills: bills,
      dateLabel: dateLabel,
    );
    final dir = await _getPreferredStorageDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/nine_bills_$stamp.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static pw.Widget _slipTemplate(Bill? bill, {required bool compact}) {
    final titleSize = compact ? 11.0 : 16.0;
    final textSize = compact ? 6.8 : 8.8;
    final headSize = compact ? 6.5 : 8.0;
    final rowHeight = compact ? 15.0 : 21.0;
    final details = bill;
    final itemRows = _toRows(details);

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _inkBlue, width: 1),
      ),
      padding: pw.EdgeInsets.all(compact ? 4 : 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'No.',
                style: pw.TextStyle(fontSize: textSize, color: _inkBlue),
              ),
              pw.Spacer(),
              pw.Text(
                'CASH BILL',
                style: pw.TextStyle(
                  fontSize: headSize,
                  color: _inkBlue,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Ph: 99943 54624',
                style: pw.TextStyle(fontSize: textSize, color: _inkBlue),
              ),
            ],
          ),
          pw.SizedBox(height: compact ? 2 : 3),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _inkBlue, width: 0.8),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: pw.Text(
              'STATE PHARMACY',
              style: pw.TextStyle(
                color: _inkBlue,
                fontWeight: pw.FontWeight.bold,
                fontSize: titleSize,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: compact ? 1.5 : 2),
          pw.Text(
            '10, Kamarajar Bus Stand, North-West Municipal Complex, Dindigul.',
            style: pw.TextStyle(fontSize: textSize - 0.2, color: _inkBlue),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: compact ? 2 : 4),
          _lineLabel(
            'Name',
            details?.patientName ?? '',
            tailLabel: 'Date',
            tailValue: details == null ? '' : _displayDate.format(details.date),
            fontSize: textSize,
          ),
          pw.SizedBox(height: 2),
          _lineLabel('Dr.', details?.doctorName ?? '', fontSize: textSize),
          pw.SizedBox(height: compact ? 2 : 3),
          _itemsGrid(
            itemRows,
            rowHeight: rowHeight,
            fontSize: textSize,
            headSize: headSize,
          ),
          pw.SizedBox(height: compact ? 2 : 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'DL.No:2561 / MDU 20-21',
                  style: pw.TextStyle(fontSize: textSize, color: _inkBlue),
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _footerValue(
                    'DISCOUNT',
                    details == null ? '' : _formatMoneyInr(0),
                    textSize,
                  ),
                  _footerValue(
                    'TOTAL',
                    details == null ? '' : _formatMoneyInr(details.totalPaise),
                    textSize,
                    bold: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemsGrid(
    List<Map<String, String>> rows, {
    required double rowHeight,
    required double fontSize,
    required double headSize,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: _inkBlue, width: 0.8),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),
        1: const pw.FlexColumnWidth(2.7),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(0.9),
        4: const pw.FlexColumnWidth(0.55),
      },
      children: [
        pw.TableRow(
          children: [
            _headCell('Qty', headSize),
            _headCell('Particulars', headSize),
            _headCell('B.N. ED', headSize),
            _headCell('Rs.', headSize),
            _headCell('P.', headSize),
          ],
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: [
              _bodyCell(row['qty']!, fontSize, rowHeight, pw.TextAlign.center),
              _bodyCell(
                row['particulars']!,
                fontSize,
                rowHeight,
                pw.TextAlign.left,
              ),
              _bodyCell(row['bned']!, fontSize, rowHeight, pw.TextAlign.left),
              _bodyCell(row['rs']!, fontSize, rowHeight, pw.TextAlign.right),
              _bodyCell(row['p']!, fontSize, rowHeight, pw.TextAlign.right),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _lineLabel(
    String label,
    String value, {
    required double fontSize,
    String? tailLabel,
    String? tailValue,
  }) {
    return pw.Row(
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(fontSize: fontSize, color: _inkBlue),
        ),
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _inkBlue, width: 0.7),
              ),
            ),
            padding: const pw.EdgeInsets.only(bottom: 1),
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: fontSize, color: _inkBlue),
            ),
          ),
        ),
        if (tailLabel != null) ...[
          pw.SizedBox(width: 8),
          pw.Text(
            '$tailLabel: ',
            style: pw.TextStyle(fontSize: fontSize, color: _inkBlue),
          ),
          pw.Container(
            width: 64,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _inkBlue, width: 0.7),
              ),
            ),
            padding: const pw.EdgeInsets.only(bottom: 1),
            child: pw.Text(
              tailValue ?? '',
              style: pw.TextStyle(fontSize: fontSize, color: _inkBlue),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _headCell(String text, double size) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
          color: _inkBlue,
        ),
      ),
    );
  }

  static pw.Widget _bodyCell(
    String text,
    double size,
    double height,
    pw.TextAlign align,
  ) {
    return pw.Container(
      height: height,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      alignment: _textAlignToAlignment(align),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: size, color: _inkBlue),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _footerValue(
    String label,
    String value,
    double size, {
    bool bold = false,
  }) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label ',
          style: pw.TextStyle(
            fontSize: size,
            color: _inkBlue,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Container(
          width: 64,
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _inkBlue, width: 0.7),
            ),
          ),
          padding: const pw.EdgeInsets.only(bottom: 1),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: size,
              color: _inkBlue,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  static List<Map<String, String>> _toRows(Bill? bill) {
    final rows = <Map<String, String>>[];
    if (bill != null) {
      for (final item in bill.items) {
        rows.add({
          'qty': item.qty.toString(),
          'particulars': _cleanMedicineName(item.name),
          'bned': item.batchEd,
          'rs': item.rs.toString(),
          'p': item.paise.toString().padLeft(2, '0'),
        });
      }
    }

    const minRows = 8;
    while (rows.length < minRows) {
      rows.add({'qty': '', 'particulars': '', 'bned': '', 'rs': '', 'p': ''});
    }
    return rows;
  }

  static pw.Widget _cell(
    String value, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      alignment: _textAlignToAlignment(align),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Alignment _textAlignToAlignment(pw.TextAlign align) {
    switch (align) {
      case pw.TextAlign.right:
        return pw.Alignment.centerRight;
      case pw.TextAlign.center:
        return pw.Alignment.center;
      default:
        return pw.Alignment.centerLeft;
    }
  }

  static String _formatMoneyInr(int paise) {
    final rs = paise ~/ 100;
    final p = (paise % 100).toString().padLeft(2, '0');
    return '$rs.$p';
  }

  static String _cleanMedicineName(String value) {
    var cleaned = value.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^\d+\s*[-.:)]\s*'), '');
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*\(\s*id\s*[:#-]?\s*\d+\s*\)', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return cleaned;
  }

  static Future<Directory> _getPreferredStorageDirectory() async {
    if (Platform.isAndroid) {
      final downloads = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (downloads != null && downloads.isNotEmpty) {
        return downloads.first;
      }
    }
    return getApplicationDocumentsDirectory();
  }
}
