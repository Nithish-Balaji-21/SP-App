import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/master_data.dart';
import 'add_medicine_screen.dart';

class MedicineInventoryScreen extends StatefulWidget {
  const MedicineInventoryScreen({super.key});

  @override
  State<MedicineInventoryScreen> createState() =>
      _MedicineInventoryScreenState();
}

class _MedicineInventoryScreenState extends State<MedicineInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<MedicineMaster>> _future;

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getMedicines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = DatabaseHelper.instance.getMedicines(
        search: _searchController.text.trim(),
      );
    });
  }

  Future<void> _openEditor({MedicineMaster? medicine}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddMedicineScreen(medicine: medicine)),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _deleteMedicine(MedicineMaster medicine) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Medicine'),
          content: Text('Delete ${medicine.name} (${medicine.batchEd})?'),
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

    await DatabaseHelper.instance.deleteMedicine(medicine.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            tooltip: 'Delete All Medicines',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _deleteAllMedicines,
          ),
          IconButton(
            tooltip: 'Add Medicine',
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search medicine or batch',
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
            child: FutureBuilder<List<MedicineMaster>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final medicines = snapshot.data ?? const [];
                if (medicines.isEmpty) {
                  return const Center(child: Text('No medicines found.'));
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: medicines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final medicine = medicines[index];
                      return Card(
                        child: ListTile(
                          title: Text(medicine.name),
                          subtitle: Text(
                            '${medicine.batchEd}\n'
                            'Pack size: ${medicine.unitsPerPack} | '
                            'Price: ${_money(medicine.pricePaise)} | '
                            'Stock: ${medicine.stockQty}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openEditor(medicine: medicine);
                              } else if (value == 'delete') {
                                _deleteMedicine(medicine);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
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

  String _money(int paise) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
    ).format(paise / 100);
  }

  Future<void> _deleteAllMedicines() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Medicines'),
          content: const Text(
            'This will remove all medicines from inventory. You can add real medicines manually after this. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await DatabaseHelper.instance.deleteAllMedicines();
    await _refresh();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All medicines deleted from inventory.')),
    );
  }
}
