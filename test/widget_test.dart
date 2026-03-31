import 'package:flutter_test/flutter_test.dart';

import 'package:state_pharmacy_app/models/bill.dart';

void main() {
  test('Bill model map conversion works', () {
    final bill = Bill(
      billNumber: '101',
      patientName: 'Test Patient',
      doctorName: 'Test Doctor',
      date: DateTime(2026, 3, 30),
      items: [
        BillItem(
          qty: 1,
          name: 'Dolo 650',
          batchEd: 'B123/027',
          rs: 45,
          paise: 0,
        ),
      ],
      totalPaise: 4500,
      createdAt: DateTime(2026, 3, 30, 10, 0, 0),
    );

    final map = bill.toMap();
    final rebuilt = Bill.fromMap(map);

    expect(rebuilt.billNumber, '101');
    expect(rebuilt.patientName, 'Test Patient');
    expect(rebuilt.items.length, 1);
    expect(rebuilt.totalPaise, 4500);
  });
}
