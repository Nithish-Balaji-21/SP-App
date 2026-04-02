import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/master_data.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key, this.medicine});

  final MedicineMaster? medicine;

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _batchEdController = TextEditingController();
  final _rsController = TextEditingController();
  final _paiseController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _thresholdController = TextEditingController(text: '10');
  final _unitsPerPackController = TextEditingController(text: '1');

  bool _saving = false;

  MedicineMaster? get _medicine => widget.medicine;

  bool get _isEditing => _medicine != null;

  @override
  void initState() {
    super.initState();
    final medicine = _medicine;
    if (medicine != null) {
      _nameController.text = medicine.name;
      _batchEdController.text = medicine.batchEd;
      _rsController.text = medicine.rs.toString();
      _paiseController.text = medicine.paise.toString().padLeft(2, '0');
      _stockController.text = medicine.stockQty.toString();
      _thresholdController.text = medicine.lowStockThreshold.toString();
      _unitsPerPackController.text = medicine.unitsPerPack.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _batchEdController.dispose();
    _rsController.dispose();
    _paiseController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _unitsPerPackController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final rs = int.tryParse(_rsController.text.trim()) ?? 0;
    final paise = (int.tryParse(_paiseController.text.trim()) ?? 0).clamp(
      0,
      99,
    );
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final threshold = int.tryParse(_thresholdController.text.trim()) ?? 10;
    final unitsPerPack = int.tryParse(_unitsPerPackController.text.trim()) ?? 1;

    await DatabaseHelper.instance.saveMedicine(
      id: _medicine?.id,
      name: _nameController.text.trim(),
      batchEd: _batchEdController.text.trim(),
      pricePaise: (rs * 100) + paise,
      unitsPerPack: unitsPerPack <= 0 ? 1 : unitsPerPack,
      stockQty: stock,
      lowStockThreshold: threshold,
    );

    if (!mounted) {
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Medicine' : 'Add New Medicine'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Medicine Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Enter medicine name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _batchEdController,
              decoration: const InputDecoration(
                labelText: 'Batch No. / Expiry',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Enter batch / expiry';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rs',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _paiseController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Paise',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitsPerPackController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Units per Strip / Pack',
                helperText: 'Example: 10 tablets in a strip',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final parsed = int.tryParse((value ?? '').trim()) ?? 0;
                if (parsed <= 0) {
                  return 'Enter pack size';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock Qty',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Low Stock Alert At',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'Update Medicine' : 'Save Medicine'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
