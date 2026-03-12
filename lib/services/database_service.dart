import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/print_job.dart';
import '../parser/escpos_parser.dart';

class DatabaseService {
  static Database? _database;
  static const String _tableName = 'print_jobs';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'escpos_virtual_printer.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        connection_type TEXT NOT NULL,
        client_ip TEXT,
        vendor_id INTEGER,
        product_id INTEGER,
        raw_data TEXT NOT NULL,
        raw_hex TEXT NOT NULL,
        rendered_text TEXT NOT NULL,
        job_size INTEGER NOT NULL,
        service_type TEXT,
        content_blocks TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db
          .execute('ALTER TABLE $_tableName ADD COLUMN content_blocks TEXT');
    }
  }

  Future<int> insertPrintJob(PrintJob job) async {
    final db = await database;
    return await db.insert(_tableName, {
      'timestamp': job.timestamp.toIso8601String(),
      'connection_type': job.connectionType.name,
      'client_ip': job.clientIp,
      'vendor_id': job.vendorId,
      'product_id': job.productId,
      'raw_data': jsonEncode(job.rawData),
      'raw_hex': job.rawHex,
      'rendered_text': job.renderedText,
      'job_size': job.jobSize,
      'service_type': job.serviceType,
      'content_blocks': job.contentBlocks.isNotEmpty
          ? jsonEncode(job.contentBlocks
              .map((cb) => {
                    'type': cb.type.index,
                    'text': cb.text,
                    'imageData': cb.imageData != null
                        ? base64Encode(cb.imageData!)
                        : null,
                    'width': cb.width,
                    'height': cb.height,
                  })
              .toList())
          : null,
    });
  }

  Future<List<PrintJob>> getAllPrintJobs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => _mapToPrintJob(map)).toList();
  }

  Future<PrintJob?> getPrintJobById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _mapToPrintJob(maps.first);
  }

  Future<int> deletePrintJob(int id) async {
    final db = await database;
    return await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllPrintJobs() async {
    final db = await database;
    return await db.delete(_tableName);
  }

  Future<int> getPrintJobCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<PrintJob>> searchPrintJobs(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'rendered_text LIKE ? OR raw_hex LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => _mapToPrintJob(map)).toList();
  }

  PrintJob _mapToPrintJob(Map<String, dynamic> map) {
    List<int> rawDataList;
    try {
      rawDataList = List<int>.from(jsonDecode(map['raw_data'] as String));
    } catch (e) {
      rawDataList = [];
    }

    List<PrintContentBlock> contentBlocks = [];
    if (map['content_blocks'] != null) {
      try {
        final List<dynamic> decoded =
            jsonDecode(map['content_blocks'] as String);
        contentBlocks = decoded.map((item) {
          return PrintContentBlock(
            type: PrintContentType.values[item['type'] as int],
            text: item['text'] as String?,
            imageData: item['imageData'] != null
                ? base64Decode(item['imageData'] as String)
                : null,
            width: item['width'] as int?,
            height: item['height'] as int?,
          );
        }).toList();
      } catch (_) {
        contentBlocks = [];
      }
    }

    return PrintJob(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      connectionType: ConnectionType.values.firstWhere(
        (e) => e.name == map['connection_type'],
        orElse: () => ConnectionType.network,
      ),
      clientIp: map['client_ip'] as String?,
      vendorId: map['vendor_id'] as int?,
      productId: map['product_id'] as int?,
      rawData: rawDataList,
      rawHex: map['raw_hex'] as String,
      renderedText: map['rendered_text'] as String,
      jobSize: map['job_size'] as int,
      serviceType: map['service_type'] as String?,
      contentBlocks: contentBlocks,
    );
  }
}
