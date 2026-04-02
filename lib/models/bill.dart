import 'dart:convert';

class BillItem {
  BillItem({
    required this.qty,
    required this.name,
    required this.batchEd,
    required this.rs,
    required this.paise,
  });

  final int qty;
  final String name;
  final String batchEd;
  final int rs;
  final int paise;

  int get unitRatePaise => (rs * 100) + paise;

  int get amountPaise => qty <= 0 ? 0 : qty * unitRatePaise;

  BillItem copyWith({
    int? qty,
    String? name,
    String? batchEd,
    int? rs,
    int? paise,
  }) {
    return BillItem(
      qty: qty ?? this.qty,
      name: name ?? this.name,
      batchEd: batchEd ?? this.batchEd,
      rs: rs ?? this.rs,
      paise: paise ?? this.paise,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'qty': qty,
      'name': name,
      'batch_ed': batchEd,
      'rs': rs,
      'paise': paise,
    };
  }

  factory BillItem.fromJson(Map<String, dynamic> map) {
    return BillItem(
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      name: (map['name'] as String? ?? '').trim(),
      batchEd: (map['batch_ed'] as String? ?? '').trim(),
      rs: (map['rs'] as num?)?.toInt() ?? 0,
      paise: (map['paise'] as num?)?.toInt() ?? 0,
    );
  }
}

class Bill {
  Bill({
    this.id,
    required this.billNumber,
    required this.patientName,
    required this.doctorName,
    required this.date,
    required this.items,
    required this.totalPaise,
    required this.createdAt,
  });

  final int? id;
  final String billNumber;
  final String patientName;
  final String doctorName;
  final DateTime date;
  final List<BillItem> items;
  final int totalPaise;
  final DateTime createdAt;

  Bill copyWith({
    int? id,
    String? billNumber,
    String? patientName,
    String? doctorName,
    DateTime? date,
    List<BillItem>? items,
    int? totalPaise,
    DateTime? createdAt,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      date: date ?? this.date,
      items: items ?? this.items,
      totalPaise: totalPaise ?? this.totalPaise,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_number': billNumber,
      'patient_name': patientName,
      'doctor_name': doctorName,
      'date': _dateToYmd(date),
      'items': jsonEncode(items.map((e) => e.toJson()).toList()),
      'total_paise': totalPaise,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as String? ?? '[]').trim();
    final decoded = jsonDecode(rawItems);
    final itemList = decoded is List
        ? decoded
              .map((e) => BillItem.fromJson((e as Map).cast<String, dynamic>()))
              .toList()
        : <BillItem>[];

    return Bill(
      id: (map['id'] as num?)?.toInt(),
      billNumber: (map['bill_number'] as String? ?? '').trim(),
      patientName: (map['patient_name'] as String? ?? '').trim(),
      doctorName: (map['doctor_name'] as String? ?? '').trim(),
      date:
          DateTime.tryParse((map['date'] as String? ?? '').trim()) ??
          DateTime.now(),
      items: itemList,
      totalPaise: (map['total_paise'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse((map['created_at'] as String? ?? '').trim()) ??
          DateTime.now(),
    );
  }

  static String _dateToYmd(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
