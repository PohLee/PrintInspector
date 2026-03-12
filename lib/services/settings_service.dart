import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SettingsService {
  static Database? _database;

  int _tcpPort = 9100;
  bool _networkEnabled = true;
  bool _usbEnabled = false;
  bool _starEnabled = false;
  bool _mdnsEnabled = true;
  Set<String> _mdnsServiceTypes = {
    '_pdl-datastream._tcp',
    '_ipp._tcp',
    '_printer._tcp',
  };
  bool _autoStart = false;
  String _printerName = 'ESC/POS Virtual Printer';
  int _pageWidth = 80;
  int _dpi = 203;

  int get tcpPort => _tcpPort;
  bool get networkEnabled => _networkEnabled;
  bool get usbEnabled => _usbEnabled;
  bool get starEnabled => _starEnabled;
  bool get mdnsEnabled => _mdnsEnabled;
  Set<String> get mdnsServiceTypes => _mdnsServiceTypes;
  bool get autoStart => _autoStart;
  String get printerName => _printerName;
  int get pageWidth => _pageWidth;
  int get dpi => _dpi;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'settings.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> loadSettings() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('settings');

      for (final map in maps) {
        final key = map['key'] as String;
        final value = map['value'] as String;

        switch (key) {
          case 'tcp_port':
            _tcpPort = int.tryParse(value) ?? 9100;
            break;
          case 'network_enabled':
            _networkEnabled = value == 'true';
            break;
          case 'usb_enabled':
            _usbEnabled = value == 'true';
            break;
          case 'star_enabled':
            _starEnabled = value == 'true';
            break;
          case 'mdns_enabled':
            _mdnsEnabled = value == 'true';
            break;
          case 'mdns_service_types':
            _mdnsServiceTypes = Set<String>.from(jsonDecode(value));
            break;
          case 'auto_start':
            _autoStart = value == 'true';
            break;
          case 'printer_name':
            _printerName = value;
            break;
          case 'page_width':
            _pageWidth = int.tryParse(value) ?? 80;
            break;
          case 'dpi':
            _dpi = int.tryParse(value) ?? 203;
            break;
        }
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setTcpPort(int port) async {
    _tcpPort = port;
    await _saveSetting('tcp_port', port.toString());
  }

  Future<void> setNetworkEnabled(bool enabled) async {
    _networkEnabled = enabled;
    await _saveSetting('network_enabled', enabled.toString());
  }

  Future<void> setUsbEnabled(bool enabled) async {
    _usbEnabled = enabled;
    await _saveSetting('usb_enabled', enabled.toString());
  }

  Future<void> setStarEnabled(bool enabled) async {
    _starEnabled = enabled;
    await _saveSetting('star_enabled', enabled.toString());
  }

  Future<void> setMdnsEnabled(bool enabled) async {
    _mdnsEnabled = enabled;
    await _saveSetting('mdns_enabled', enabled.toString());
  }

  Future<void> setMdnsServiceTypes(Set<String> types) async {
    _mdnsServiceTypes = types;
    await _saveSetting('mdns_service_types', jsonEncode(types.toList()));
  }

  Future<void> setAutoStart(bool autoStart) async {
    _autoStart = autoStart;
    await _saveSetting('auto_start', autoStart.toString());
  }

  Future<void> setPrinterName(String name) async {
    _printerName = name;
    await _saveSetting('printer_name', name);
  }

  Future<void> setPageWidth(int width) async {
    _pageWidth = width;
    await _saveSetting('page_width', width.toString());
  }

  Future<void> setDpi(int dpi) async {
    _dpi = dpi;
    await _saveSetting('dpi', dpi.toString());
  }
}
