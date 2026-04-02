import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/bill.dart';
import '../models/master_data.dart';
import '../utils/pdf_generator.dart';
import '../widgets/medicine_row_widget.dart';
import 'add_medicine_screen.dart';
import 'bill_preview_screen.dart';

class NewBillScreen extends StatefulWidget {
  const NewBillScreen({super.key, this.bill});

  final Bill? bill;

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _billNoController;
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _saving = false;
  bool _loadingMasters = true;

  final List<BillItem> _items = [
    BillItem(qty: 0, name: '', batchEd: '', rs: 0, paise: 0),
  ];
  final List<int> _rowIds = [0];
  int _nextRowId = 1;

  List<String> _patientNames = [];
  List<String> _doctorNames = [];
  List<MedicineMaster> _medicineList = [];
  final Map<int, List<String>> _batchHistoryByRow = {};
  bool _stockPopupOpen = false;

  @override
  void initState() {
    super.initState();
    _billNoController = TextEditingController();
    final existing = widget.bill;
    if (existing != null) {
      _billNoController.text = existing.billNumber;
      _patientController.text = existing.patientName;
      _doctorController.text = existing.doctorName;
      _selectedDate = existing.date;
      _items
        ..clear()
        ..addAll(
          existing.items.isEmpty
              ? [BillItem(qty: 0, name: '', batchEd: '', rs: 0, paise: 0)]
              : existing.items.map((item) => item.copyWith()).toList(),
        );
      _rowIds
        ..clear()
        ..addAll(List<int>.generate(_items.length, (index) => index));
      _nextRowId = _items.length;
    } else {
      _loadNextBillNo();
    }
    _loadMasterData();
  }

  @override
  void dispose() {
    _billNoController.dispose();
    _patientController.dispose();
    _doctorController.dispose();
    super.dispose();
  }

  Future<void> _loadNextBillNo() async {
    final next = await DatabaseHelper.instance.getNextBillNumber();
    if (!mounted) {
      return;
    }
    _billNoController.text = next.toString();
  }

  Future<void> _loadMasterData() async {
    final patientNames = await DatabaseHelper.instance.getPatientNames();
    final doctorNames = await DatabaseHelper.instance.getDoctorNames();
    final medicines = await DatabaseHelper.instance.getMedicines();
    if (!mounted) {
      return;
    }
    setState(() {
      _patientNames = patientNames;
      _doctorNames = doctorNames;
      _medicineList = medicines;
      _loadingMasters = false;
    });

    if (widget.bill != null) {
      for (final entry in _rowIds.asMap().entries) {
        final index = entry.key;
        final rowId = entry.value;
        final item = _items[index];
        if (item.name.trim().isNotEmpty) {
          await _loadBatchHistoryForRow(rowId, item.name);
        }
      }
    }
  }

  int get _totalPaise {
    return _items.fold<int>(0, (sum, item) => sum + item.amountPaise);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
  }

  void _addMedicine() {
    setState(() {
      _items.add(BillItem(qty: 0, name: '', batchEd: '', rs: 0, paise: 0));
      _rowIds.add(_nextRowId++);
    });
  }

  Future<void> _loadBatchHistoryForRow(int rowId, String medicineName) async {
    final batches = await DatabaseHelper.instance.getBatchHistoryByMedicineName(
      medicineName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _batchHistoryByRow[rowId] = batches;
    });
  }

  Future<void> _addNewMedicineMaster() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
    );
    if (added == true) {
      await _loadMasterData();
    }
  }

  Future<void> _saveBill({required bool exportPdf}) async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    final cleanedItems = _items
        .where((item) => item.name.trim().isNotEmpty)
        .toList();
    if (cleanedItems.isEmpty) {
      _showSnack('Add at least one medicine item.');
      return;
    }

    if (_billNoController.text.trim().isEmpty) {
      _showSnack('Bill number is required.');
      return;
    }

    final stockError = await _validateStockBeforeSave(cleanedItems);
    if (stockError != null) {
      await _showStockLimitDialog(stockError);
      return;
    }

    setState(() {
      _saving = true;
    });

    final bill = Bill(
      id: widget.bill?.id,
      billNumber: _billNoController.text.trim(),
      patientName: _patientController.text.trim(),
      doctorName: _doctorController.text.trim(),
      date: _selectedDate,
      items: cleanedItems,
      totalPaise: cleanedItems.fold<int>(0, (sum, e) => sum + e.amountPaise),
      createdAt: widget.bill?.createdAt ?? DateTime.now(),
    );

    try {
      await DatabaseHelper.instance.upsertPatientName(_patientController.text);
      await DatabaseHelper.instance.upsertDoctorName(_doctorController.text);

      if (widget.bill == null) {
        final id = await DatabaseHelper.instance.insertBill(bill);
        final lowStocks = await DatabaseHelper.instance.reduceStockForBillItems(
          cleanedItems,
        );
        final stored = await DatabaseHelper.instance.getBillById(id);
        if (stored == null) {
          _showSnack('Failed to save bill.');
          return;
        }

        if (lowStocks.isNotEmpty) {
          _showSnack('Low stock alert: ${lowStocks.join(', ')}');
        }

        if (exportPdf) {
          final file = await PdfGenerator.generateBillPdf(stored);
          _showSnack('PDF saved: ${file.path}');
        }

        if (!mounted) {
          return;
        }

        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => BillPreviewScreen(bill: stored)),
        );
        return;
      }

      await DatabaseHelper.instance.replaceBill(
        oldBill: widget.bill!,
        newBill: bill,
      );
      final stored = await DatabaseHelper.instance.getBillById(
        widget.bill!.id!,
      );
      if (stored == null) {
        _showSnack('Failed to save bill.');
        return;
      }

      if (exportPdf) {
        final file = await PdfGenerator.generateBillPdf(stored);
        _showSnack('PDF saved: ${file.path}');
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, stored);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Bill'),
        actions: [
          IconButton(
            tooltip: 'Add New Medicine',
            onPressed: _addNewMedicineMaster,
            icon: const Icon(Icons.medication_outlined),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loadingMasters)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            TextFormField(
              controller: _billNoController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Bill Number',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Enter bill number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _searchableNameField(
              controller: _patientController,
              options: _patientNames,
              label: 'Patient Name',
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Enter patient name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _searchableNameField(
              controller: _doctorController,
              options: _doctorNames,
              label: 'Doctor Name',
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Medicines', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final rowId = _rowIds[index];

              return Dismissible(
                key: ValueKey('medicine_$rowId'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  setState(() {
                    _items.removeAt(index);
                    _batchHistoryByRow.remove(rowId);
                    _rowIds.removeAt(index);
                    if (_items.isEmpty) {
                      _items.add(
                        BillItem(
                          qty: 0,
                          name: '',
                          batchEd: '',
                          rs: 0,
                          paise: 0,
                        ),
                      );
                      _rowIds.add(_nextRowId++);
                    }
                  });
                },
                child: MedicineRowWidget(
                  index: index,
                  item: item,
                  medicineOptions: _medicineList,
                  batchHistory: _batchHistoryByRow[rowId] ?? const [],
                  onMedicineNameChanged: (value) {
                    _loadBatchHistoryForRow(rowId, value);
                  },
                  onMedicineSelected: (selected) {
                    setState(() {
                      _items[index] = _items[index].copyWith(
                        name: selected.name,
                        batchEd: selected.batchEd,
                        rs: selected.unitRs,
                        paise: selected.unitPaise,
                      );
                    });
                    _loadBatchHistoryForRow(rowId, selected.name);
                  },
                  onChanged: (updated) {
                    _onRowChanged(index, updated);
                  },
                ),
              );
            }),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _addMedicine,
                icon: const Icon(Icons.add),
                label: const Text('Add Medicine'),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatMoney(_totalPaise),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : () => _saveBill(exportPdf: false),
                icon: const Icon(Icons.save),
                label: const Text('Save Bill'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : () => _saveBill(exportPdf: true),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Save & Export PDF'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _searchableNameField({
    required TextEditingController controller,
    required List<String> options,
    required String label,
    String? Function(String?)? validator,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return options.take(25);
        }
        return options.where((e) => e.toLowerCase().contains(query)).take(25);
      },
      onSelected: (selected) {
        controller.text = selected;
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            if (textEditingController.text != controller.text) {
              textEditingController.text = controller.text;
            }
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              validator: validator,
              onChanged: (value) {
                controller.text = value;
              },
            );
          },
    );
  }

  String _formatMoney(int paise) {
    final rs = paise / 100;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rs);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onRowChanged(int index, BillItem updated) {
    final clamped = _clampToAvailableStock(updated);
    setState(() {
      _items[index] = clamped;
    });

    if (clamped.qty != updated.qty) {
      _showStockLimitDialog(
        '${_cleanMedicineName(updated.name)}: only ${clamped.qty} in stock. You cannot bill more than available quantity.',
      );
    }
  }

  BillItem _clampToAvailableStock(BillItem item) {
    final stock = _availableStockFor(item.name, item.batchEd);
    if (stock == null) {
      return item;
    }
    if (stock <= 0 && item.qty > 0) {
      return item.copyWith(qty: 0);
    }
    if (item.qty > stock) {
      return item.copyWith(qty: stock);
    }
    return item;
  }

  int? _availableStockFor(String name, String batchEd) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return null;
    }

    final normalizedBatch = batchEd.trim();
    MedicineMaster? match;
    if (normalizedBatch.isNotEmpty) {
      for (final med in _medicineList) {
        if (med.name == normalizedName && med.batchEd == normalizedBatch) {
          match = med;
          break;
        }
      }
    } else {
      for (final med in _medicineList) {
        if (med.name == normalizedName) {
          match = med;
          break;
        }
      }
    }

    return match?.stockQty;
  }

  Future<String?> _validateStockBeforeSave(List<BillItem> items) async {
    final oldQtyByKey = <String, int>{};
    if (widget.bill != null) {
      for (final oldItem in widget.bill!.items) {
        final key = _itemKey(oldItem.name, oldItem.batchEd);
        oldQtyByKey[key] = (oldQtyByKey[key] ?? 0) + oldItem.qty;
      }
    }

    final requestedByKey = <String, int>{};
    for (final item in items) {
      final key = _itemKey(item.name, item.batchEd);
      requestedByKey[key] = (requestedByKey[key] ?? 0) + item.qty;
    }

    for (final entry in requestedByKey.entries) {
      final parts = entry.key.split('||');
      final name = parts.first;
      final batch = parts.length > 1 ? parts[1] : '';
      final requestedQty = entry.value;

      final medicine = await DatabaseHelper.instance.getMedicineByNameAndBatch(
        name: name,
        batchEd: batch,
      );

      if (medicine == null) {
        return '${_cleanMedicineName(name)} ($batch) is not in inventory. Add it to stock first.';
      }

      final available = medicine.stockQty + (oldQtyByKey[entry.key] ?? 0);
      if (available <= 0) {
        return '${_cleanMedicineName(name)} ($batch) is out of stock.';
      }

      if (requestedQty > available) {
        return '${_cleanMedicineName(name)} ($batch): available quantity is $available. Please reduce qty.';
      }
    }

    return null;
  }

  String _itemKey(String name, String batch) {
    return '${name.trim()}||${batch.trim()}';
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

  Future<void> _showStockLimitDialog(String message) async {
    if (_stockPopupOpen || !mounted) {
      return;
    }
    _stockPopupOpen = true;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Stock Limit'),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    _stockPopupOpen = false;
  }
}
