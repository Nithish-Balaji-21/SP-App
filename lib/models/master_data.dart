class MedicineMaster {
  MedicineMaster({
    required this.id,
    required this.name,
    required this.batchEd,
    required this.pricePaise,
    required this.stockQty,
    required this.lowStockThreshold,
  });

  final int id;
  final String name;
  final String batchEd;
  final int pricePaise;
  final int stockQty;
  final int lowStockThreshold;

  int get rs => pricePaise ~/ 100;
  int get paise => pricePaise % 100;

  factory MedicineMaster.fromMap(Map<String, dynamic> map) {
    return MedicineMaster(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: (map['name'] as String? ?? '').trim(),
      batchEd: (map['batch_ed'] as String? ?? '').trim(),
      pricePaise: (map['price_paise'] as num?)?.toInt() ?? 0,
      stockQty: (map['stock_qty'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toInt() ?? 10,
    );
  }
}
