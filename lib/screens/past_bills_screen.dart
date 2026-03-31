import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/bill.dart';
import '../widgets/bill_card_widget.dart';
import 'bill_preview_screen.dart';

class PastBillsScreen extends StatefulWidget {
  const PastBillsScreen({super.key});

  @override
  State<PastBillsScreen> createState() => _PastBillsScreenState();
}

class _PastBillsScreenState extends State<PastBillsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Bill>> _billsFuture;

  @override
  void initState() {
    super.initState();
    _billsFuture = DatabaseHelper.instance.getAllBills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _billsFuture = DatabaseHelper.instance.getAllBills(
        search: _searchController.text.trim(),
      );
    });
  }

  Future<void> _confirmDelete(Bill bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Bill'),
          content: Text('Delete Bill No ${bill.billNumber}?'),
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

    if (confirm != true || bill.id == null) {
      return;
    }

    await DatabaseHelper.instance.deleteBill(bill.id!);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past Bills')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by patient name or date (yyyy-MM-dd)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _refresh();
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _refresh(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Bill>>(
              future: _billsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final bills = snapshot.data ?? [];
                if (bills.isEmpty) {
                  return const Center(child: Text('No bills found.'));
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return BillCardWidget(
                        bill: bill,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BillPreviewScreen(bill: bill),
                            ),
                          );
                        },
                        onLongPress: () => _confirmDelete(bill),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
