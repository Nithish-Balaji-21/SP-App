import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/bill.dart';
import '../models/master_data.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'state_pharmacy.db';
  static const _dbVersion = 2;
  static const _billsTable = 'bills';
  static const _patientsTable = 'patients';
  static const _doctorsTable = 'doctors';
  static const _medicinesTable = 'medicines';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedMasterDataIfNeeded(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createMasterTables(db);
          await _seedMasterDataIfNeeded(db);
        }
      },
      onOpen: (db) async {
        await _replacePlaceholderMedicineNamesIfNeeded(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_billsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_number TEXT,
        patient_name TEXT,
        doctor_name TEXT,
        date TEXT,
        items TEXT,
        total_paise INTEGER,
        created_at TEXT
      )
    ''');

    await _createMasterTables(db);
  }

  Future<void> _createMasterTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_patientsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_doctorsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_medicinesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        batch_ed TEXT,
        price_paise INTEGER,
        stock_qty INTEGER,
        low_stock_threshold INTEGER,
        updated_at TEXT,
        UNIQUE(name, batch_ed)
      )
    ''');
  }

  Future<void> _seedMasterDataIfNeeded(Database db) async {
    final patientCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_patientsTable'),
    );
    if ((patientCount ?? 0) == 0) {
      final now = DateTime.now().toIso8601String();
      for (final name in _seedPatients) {
        await db.insert(_patientsTable, {'name': name, 'created_at': now});
      }
    }

    final doctorCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_doctorsTable'),
    );
    if ((doctorCount ?? 0) == 0) {
      final now = DateTime.now().toIso8601String();
      for (final name in _seedDoctors) {
        await db.insert(_doctorsTable, {'name': name, 'created_at': now});
      }
    }

    final medicineCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_medicinesTable'),
    );
    if ((medicineCount ?? 0) == 0) {
      final random = Random();
      final now = DateTime.now().toIso8601String();
      for (var i = 1; i <= 200; i++) {
        final batch = 'B${1000 + i}/${(i % 12) + 1}27';
        final price = ((40 + i) * 100) + ((i * 3) % 100);
        await db.insert(_medicinesTable, {
          'name': _seedMedicineNameAt(i),
          'batch_ed': batch,
          'price_paise': price,
          'stock_qty': 20 + random.nextInt(120),
          'low_stock_threshold': 10,
          'updated_at': now,
        });
      }
    }

    await _replacePlaceholderMedicineNamesIfNeeded(db);
  }

  Future<void> _replacePlaceholderMedicineNamesIfNeeded(Database db) async {
    final placeholderRows = await db.query(
      _medicinesTable,
      columns: ['id', 'batch_ed'],
      where: "name LIKE 'Medicine %'",
      orderBy: 'id ASC',
    );

    if (placeholderRows.isEmpty) {
      return;
    }

    var index = 1;
    final now = DateTime.now().toIso8601String();
    for (final row in placeholderRows) {
      final id = (row['id'] as num).toInt();
      final batch = (row['batch_ed'] as String? ?? '').trim();

      var candidate = _seedMedicineNameAt(index);
      var updated = false;

      for (var tryCount = 0; tryCount < 6; tryCount++) {
        final duplicate = await db.query(
          _medicinesTable,
          columns: ['id'],
          where: 'name = ? AND batch_ed = ? AND id != ?',
          whereArgs: [candidate, batch, id],
          limit: 1,
        );

        if (duplicate.isEmpty) {
          await db.update(
            _medicinesTable,
            {'name': candidate, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [id],
          );
          updated = true;
          break;
        }

        candidate = '${_seedMedicineNameAt(index)} ${tryCount + 1}';
      }

      if (!updated) {
        await db.update(
          _medicinesTable,
          {'name': '${_seedMedicineNameAt(index)} Tab', 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      index++;
    }
  }

  String _seedMedicineNameAt(int index) {
    final base =
        _seedMedicineBaseNames[(index - 1) % _seedMedicineBaseNames.length];
    final suffix =
        _seedMedicineSuffixes[(index - 1) % _seedMedicineSuffixes.length];
    return suffix.isEmpty ? base : '$base $suffix';
  }

  Future<int> insertBill(Bill bill) async {
    final db = await database;
    return db.insert(_billsTable, bill.toMap());
  }

  Future<Bill?> getBillById(int id) async {
    final db = await database;
    final rows = await db.query(
      _billsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }
    return Bill.fromMap(rows.first);
  }

  Future<List<Bill>> getAllBills({String search = ''}) async {
    final db = await database;
    final trimmed = search.trim();

    List<Map<String, dynamic>> rows;
    if (trimmed.isEmpty) {
      rows = await db.query(
        _billsTable,
        orderBy: 'datetime(created_at) DESC, id DESC',
      );
    } else {
      rows = await db.query(
        _billsTable,
        where: 'patient_name LIKE ? OR date LIKE ?',
        whereArgs: ['%$trimmed%', '%$trimmed%'],
        orderBy: 'datetime(created_at) DESC, id DESC',
      );
    }

    return rows.map(Bill.fromMap).toList();
  }

  Future<List<Bill>> getBillsByDate(DateTime date) async {
    final ymd = _dateToYmd(date);
    final db = await database;
    final rows = await db.query(
      _billsTable,
      where: 'date = ?',
      whereArgs: [ymd],
      orderBy: 'datetime(created_at) DESC, id DESC',
    );

    return rows.map(Bill.fromMap).toList();
  }

  Future<List<Bill>> getBillsByDateRange(DateTime from, DateTime to) async {
    final db = await database;
    final fromYmd = _dateToYmd(from);
    final toYmd = _dateToYmd(to);
    final rows = await db.query(
      _billsTable,
      where: 'date >= ? AND date <= ?',
      whereArgs: [fromYmd, toYmd],
      orderBy: 'date ASC, datetime(created_at) ASC, id ASC',
    );
    return rows.map(Bill.fromMap).toList();
  }

  Future<int> deleteBill(int id) async {
    final db = await database;
    return db.delete(_billsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getNextBillNumber() async {
    final db = await database;
    final rows = await db.query(_billsTable, columns: ['bill_number']);

    var maxValue = 0;
    for (final row in rows) {
      final raw = (row['bill_number'] as String? ?? '').trim();
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > maxValue) {
        maxValue = parsed;
      }
    }

    return maxValue + 1;
  }

  Future<Map<String, int>> getDailyStats(DateTime date) async {
    final bills = await getBillsByDate(date);
    final totalPaise = bills.fold<int>(0, (sum, bill) => sum + bill.totalPaise);

    return {'count': bills.length, 'revenue_paise': totalPaise};
  }

  Future<List<String>> getPatientNames({String search = ''}) async {
    final db = await database;
    final trimmed = search.trim();
    final rows = await db.query(
      _patientsTable,
      columns: ['name'],
      where: trimmed.isEmpty ? null : 'name LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%'],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: 200,
    );
    return rows.map((e) => (e['name'] as String? ?? '').trim()).toList();
  }

  Future<List<String>> getDoctorNames({String search = ''}) async {
    final db = await database;
    final trimmed = search.trim();
    final rows = await db.query(
      _doctorsTable,
      columns: ['name'],
      where: trimmed.isEmpty ? null : 'name LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%'],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: 200,
    );
    return rows.map((e) => (e['name'] as String? ?? '').trim()).toList();
  }

  Future<void> upsertPatientName(String value) async {
    final name = value.trim();
    if (name.isEmpty) {
      return;
    }
    final db = await database;
    await db.insert(_patientsTable, {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> upsertDoctorName(String value) async {
    final name = value.trim();
    if (name.isEmpty) {
      return;
    }
    final db = await database;
    await db.insert(_doctorsTable, {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<MedicineMaster>> getMedicines({String search = ''}) async {
    final db = await database;
    await _replacePlaceholderMedicineNamesIfNeeded(db);
    final trimmed = search.trim();
    final rows = await db.query(
      _medicinesTable,
      where: trimmed.isEmpty ? null : 'name LIKE ? OR batch_ed LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%', '%$trimmed%'],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: 300,
    );
    return rows.map(MedicineMaster.fromMap).toList();
  }

  Future<List<String>> getBatchHistoryByMedicineName(
    String medicineName,
  ) async {
    final name = medicineName.trim();
    if (name.isEmpty) {
      return [];
    }
    final db = await database;
    final rows = await db.query(
      _medicinesTable,
      columns: ['batch_ed'],
      where: 'name = ?',
      whereArgs: [name],
      orderBy: 'updated_at DESC, id DESC',
      limit: 50,
    );
    final values = <String>[];
    for (final row in rows) {
      final batch = (row['batch_ed'] as String? ?? '').trim();
      if (batch.isNotEmpty && !values.contains(batch)) {
        values.add(batch);
      }
    }
    return values;
  }

  Future<void> upsertMedicine({
    required String name,
    required String batchEd,
    required int pricePaise,
    int stockQty = 0,
    int lowStockThreshold = 10,
  }) async {
    final normalizedName = name.trim();
    final normalizedBatch = batchEd.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert(_medicinesTable, {
      'name': normalizedName,
      'batch_ed': normalizedBatch,
      'price_paise': pricePaise,
      'stock_qty': stockQty,
      'low_stock_threshold': lowStockThreshold,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.update(
      _medicinesTable,
      {'price_paise': pricePaise, 'updated_at': now},
      where: 'name = ? AND batch_ed = ?',
      whereArgs: [normalizedName, normalizedBatch],
    );
  }

  Future<List<String>> reduceStockForBillItems(List<BillItem> items) async {
    final db = await database;
    final lowStockNames = <String>{};

    for (final item in items) {
      final name = item.name.trim();
      final batch = item.batchEd.trim();
      if (name.isEmpty) {
        continue;
      }

      final existing = await db.query(
        _medicinesTable,
        where: 'name = ? AND batch_ed = ?',
        whereArgs: [name, batch],
        limit: 1,
      );

      if (existing.isEmpty) {
        await upsertMedicine(
          name: name,
          batchEd: batch,
          pricePaise: item.amountPaise,
          stockQty: 0,
          lowStockThreshold: 10,
        );
      }

      final refreshed = await db.query(
        _medicinesTable,
        where: 'name = ? AND batch_ed = ?',
        whereArgs: [name, batch],
        limit: 1,
      );
      if (refreshed.isEmpty) {
        continue;
      }

      final row = refreshed.first;
      final id = (row['id'] as num).toInt();
      final stock = (row['stock_qty'] as num?)?.toInt() ?? 0;
      final threshold = (row['low_stock_threshold'] as num?)?.toInt() ?? 10;
      final updatedStock = max(0, stock - max(0, item.qty));

      await db.update(
        _medicinesTable,
        {
          'stock_qty': updatedStock,
          'price_paise': item.amountPaise,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (updatedStock <= threshold) {
        lowStockNames.add(name);
      }
    }

    return lowStockNames.toList()..sort();
  }

  Future<int> getLowStockCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_medicinesTable WHERE stock_qty <= low_stock_threshold',
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  String _dateToYmd(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static const List<String> _seedPatients = [
    'Aakash',
    'Aarthi',
    'Abinaya',
    'Akila',
    'Akshaya',
    'Anand',
    'Anitha',
    'Aravind',
    'Arun Kumar',
    'Balaji',
    'Banu Priya',
    'Bharathi',
    'Chitra',
    'Deepa',
    'Dhanush',
    'Divya',
    'Elango',
    'Fathima',
    'Ganesan',
    'Gayathri',
    'Gowri',
    'Hari',
    'Hemalatha',
    'Ilamaran',
    'Indumathi',
    'Jeeva',
    'Jothi',
    'Karthik',
    'Kavitha',
    'Keerthi',
    'Kishore',
    'Lakshmi',
    'Madhan',
    'Mahalakshmi',
    'Manikandan',
    'Meena',
    'Mohan',
    'Nandhini',
    'Naveen',
    'Nirmala',
    'Pandi',
    'Parvathi',
    'Prabhu',
    'Priya',
    'Ragavan',
    'Raji',
    'Ramesh',
    'Revathi',
    'Saravanan',
    'Sathya',
    'Selvi',
    'Shalini',
    'Sivakumar',
    'Sowmiya',
    'Srinivasan',
    'Sujatha',
    'Tamilselvi',
    'Udhaya',
    'Vignesh',
    'Yamuna',
  ];

  static const List<String> _seedDoctors = [
    'Dr. R. Kumar, MBBS',
    'Dr. S. Priya, MBBS',
    'Dr. A. Suresh, MD',
    'Dr. N. Karthikeyan, MBBS',
    'Dr. V. Rajesh, MBBS',
    'Dr. P. Lakshmi, MBBS',
    'Dr. M. Arul, MD',
    'Dr. T. Dinesh, MBBS',
    'Dr. B. Meena, MBBS',
    'Dr. J. Prakash, MBBS',
    'Dr. C. Devi, MBBS',
    'Dr. G. Gopinath, MD',
    'Dr. H. Rekha, MBBS',
    'Dr. K. Senthil, MBBS',
    'Dr. L. Harini, MBBS',
    'Dr. E. Ravi, MBBS',
    'Dr. F. Shankar, MBBS',
    'Dr. U. Vasanthi, MD',
    'Dr. Y. Balamurugan, MBBS',
    'Dr. Z. Nivetha, MBBS',
  ];

  static const List<String> _seedMedicineBaseNames = [
    'Dolo',
    'Paracetamol',
    'Crocin',
    'Calpol',
    'Azithral',
    'Azithromycin',
    'Amoxyclav',
    'Amoxicillin',
    'Cetrizine',
    'Levocetirizine',
    'Montair',
    'Sinarest',
    'Rantac',
    'Pantocid',
    'Pan',
    'Omez',
    'Rabekind',
    'Rablet',
    'Aciloc',
    'Domstal',
    'Ondem',
    'Emeset',
    'Norflox',
    'Taxim',
    'Ciplox',
    'Ciprofloxacin',
    'Oflox',
    'Metrogyl',
    'Tinidazole',
    'Zifi',
    'Cefixime',
    'Doxy',
    'Doxycycline',
    'Azee',
    'Augmentin',
    'Mox',
    'Monocef',
    'Becosules',
    'Neurobion',
    'Shelcal',
    'Calcimax',
    'Limcee',
    'Zincovit',
    'Liv 52',
    'Benadryl',
    'Alex',
    'Ascoril',
    'TusQ',
    'Honitus',
    'Vicks',
    'Volini',
    'Moov',
    'Iodex',
    'Diclomol',
    'Combiflam',
    'Brufen',
    'Ibuprofen',
    'Nise',
    'Aceclo',
    'Zerodol',
    'Bandy',
    'Albendazole',
    'ORS',
    'Electral',
    'Digene',
    'Gelusil',
    'Eno',
    'Looz',
    'Duphalac',
    'Deriphyllin',
    'Asthalin',
    'Budecort',
    'Foracort',
    'Montek',
    'Nocold',
    'D Cold',
    'Nasalon',
    'Betadine',
    'Soframycin',
    'Mupirocin',
    'Candid',
    'Clotrimazole',
    'Ketoconazole',
    'Panderm',
    'Dermadew',
    'Luliconazole',
    'Atarax',
    'Allegra',
    'Fexofenadine',
    'Amlong',
    'Telma',
    'Ecosprin',
    'Glycomet',
    'Glimisave',
    'Insugen',
    'Thyronorm',
    'Folvite',
  ];

  static const List<String> _seedMedicineSuffixes = [
    '250',
    '500',
    '650',
    'DS',
    'Forte',
    'Plus',
    'Tab',
    'Cap',
    'Syrup',
    '',
  ];
}
