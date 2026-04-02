import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../models/master_data.dart';

class MedicineRowWidget extends StatefulWidget {
  const MedicineRowWidget({
    super.key,
    required this.index,
    required this.item,
    required this.medicineOptions,
    required this.batchHistory,
    required this.onChanged,
    required this.onMedicineNameChanged,
    required this.onMedicineSelected,
  });

  final int index;
  final BillItem item;
  final List<MedicineMaster> medicineOptions;
  final List<String> batchHistory;
  final ValueChanged<BillItem> onChanged;
  final ValueChanged<String> onMedicineNameChanged;
  final ValueChanged<MedicineMaster> onMedicineSelected;

  @override
  State<MedicineRowWidget> createState() => _MedicineRowWidgetState();
}

class _MedicineRowWidgetState extends State<MedicineRowWidget> {
  late final TextEditingController _qtyController;
  late final TextEditingController _medicineController;
  late final TextEditingController _batchController;
  late final TextEditingController _rsController;
  late final TextEditingController _paiseController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController();
    _medicineController = TextEditingController();
    _batchController = TextEditingController();
    _rsController = TextEditingController();
    _paiseController = TextEditingController();
    _syncControllersFromItem();
  }

  @override
  void didUpdateWidget(covariant MedicineRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllersFromItem();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _medicineController.dispose();
    _batchController.dispose();
    _rsController.dispose();
    _paiseController.dispose();
    super.dispose();
  }

  void _syncControllersFromItem() {
    final qtyText = widget.item.qty == 0 ? '' : widget.item.qty.toString();
    if (_qtyController.text != qtyText) {
      _qtyController.text = qtyText;
    }

    final medicineName = _cleanMedicineName(widget.item.name);
    if (_medicineController.text != medicineName) {
      _medicineController.text = medicineName;
    }

    if (_batchController.text != widget.item.batchEd) {
      _batchController.text = widget.item.batchEd;
    }

    final rsText = widget.item.rs == 0 ? '' : widget.item.rs.toString();
    if (_rsController.text != rsText) {
      _rsController.text = rsText;
    }

    final paiseText = widget.item.paise == 0
        ? ''
        : widget.item.paise.toString();
    if (_paiseController.text != paiseText) {
      _paiseController.text = paiseText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medicine ${widget.index + 1}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final qty = int.tryParse(value.trim()) ?? 0;
                      widget.onChanged(widget.item.copyWith(qty: qty));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      final all = widget.medicineOptions
                          .map((e) => _cleanMedicineName(e.name))
                          .toSet();
                      if (query.isEmpty) {
                        return all.take(20);
                      }
                      return all.where(
                        (name) => name.toLowerCase().contains(query),
                      ).take(20);
                    },
                    onSelected: (selectedName) {
                      final clean = _cleanMedicineName(selectedName);
                      _medicineController.text = clean;
                      widget.onChanged(widget.item.copyWith(name: clean));

                      final selected = widget.medicineOptions.firstWhere(
                        (e) => _cleanMedicineName(e.name) == clean,
                        orElse: () => MedicineMaster(
                          id: 0,
                          name: clean,
                          batchEd: '',
                          pricePaise: 0,
                          unitsPerPack: 1,
                          stockQty: 0,
                          lowStockThreshold: 10,
                        ),
                      );
                      widget.onMedicineSelected(selected);
                    },
                    fieldViewBuilder:
                        (
                          context,
                          textEditingController,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          if (textEditingController.text !=
                              _medicineController.text) {
                            textEditingController.text = _medicineController.text;
                          }
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Medicine Name',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final clean = _cleanMedicineName(value);
                              _medicineController.text = clean;
                              widget.onChanged(widget.item.copyWith(name: clean));
                              widget.onMedicineNameChanged(clean);
                            },
                          );
                        },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _rateHint(context),
            const SizedBox(height: 10),
            Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) {
                  return widget.batchHistory;
                }
                return widget.batchHistory.where(
                  (e) => e.toLowerCase().contains(query),
                );
              },
              onSelected: (selected) {
                _batchController.text = selected;
                widget.onChanged(widget.item.copyWith(batchEd: selected));
              },
              fieldViewBuilder:
                  (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    if (textEditingController.text != _batchController.text) {
                      textEditingController.text = _batchController.text;
                    }
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Batch No. / ED',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _batchController.text = value;
                        widget.onChanged(widget.item.copyWith(batchEd: value));
                      },
                    );
                  },
            ),
            const SizedBox(height: 10),
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
                    onChanged: (value) {
                      final rs = int.tryParse(value.trim()) ?? 0;
                      widget.onChanged(widget.item.copyWith(rs: rs));
                    },
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
                    onChanged: (value) {
                      var paise = int.tryParse(value.trim()) ?? 0;
                      if (paise < 0) {
                        paise = 0;
                      }
                      if (paise > 99) {
                        paise = 99;
                      }
                      widget.onChanged(widget.item.copyWith(paise: paise));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rateHint(BuildContext context) {
    final selected = widget.medicineOptions.cast<MedicineMaster?>().firstWhere(
      (medicine) =>
          medicine != null &&
          _cleanMedicineName(medicine.name) == _cleanMedicineName(widget.item.name),
      orElse: () => null,
    );

    if (selected == null || selected.unitsPerPack <= 0) {
      return const SizedBox.shrink();
    }

    final unitPrice = selected.unitPricePaise;
    final unitText = 'Unit rate: Rs ${(unitPrice / 100).toStringAsFixed(2)}';
    final packText = 'Pack size: ${selected.unitsPerPack}';

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '$unitText | $packText',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[700],
            ),
      ),
    );
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
}