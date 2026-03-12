import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_star_prnt_plus/flutter_star_prnt.dart';
import '../models/print_job.dart';
import '../parser/escpos_parser.dart';
import '../services/database_service.dart';

class StarPrinterService {
  static final StarPrinterService _instance = StarPrinterService._internal();
  factory StarPrinterService() => _instance;
  StarPrinterService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final StreamController<PrintJob> _printJobController =
      StreamController<PrintJob>.broadcast();

  List<PortInfo> _discoveredPrinters = [];
  PortInfo? _connectedPrinter;
  bool _isListening = false;

  Stream<PrintJob> get onPrintJob => _printJobController.stream;
  List<PortInfo> get discoveredPrinters => _discoveredPrinters;
  bool get isListening => _isListening;
  PortInfo? get connectedPrinter => _connectedPrinter;

  Future<List<PortInfo>> discoverPrinters({
    StarPortType portType = StarPortType.All,
  }) async {
    try {
      _discoveredPrinters = await StarPrnt.portDiscovery(portType);
      print('Star printers discovered: ${_discoveredPrinters.length}');
      for (final printer in _discoveredPrinters) {
        print('  - ${printer.portName}: ${printer.modelName}');
      }
      return _discoveredPrinters;
    } catch (e) {
      print('Star printer discovery error: $e');
      return [];
    }
  }

  Future<bool> connectPrinter(PortInfo printer) async {
    try {
      _connectedPrinter = printer;
      print('Connected to Star printer: ${printer.portName}');
      return true;
    } catch (e) {
      print('Failed to connect to Star printer: $e');
      return false;
    }
  }

  Future<bool> startListening(PortInfo printer) async {
    if (_isListening) {
      await stopListening();
    }

    try {
      await connectPrinter(printer);

      _isListening = true;
      print('Star printer listening started on ${printer.portName}');
      return true;
    } catch (e) {
      print('Failed to start Star printer listening: $e');
      return false;
    }
  }

  void _handlePrintData(List<int> data, PortInfo printer) async {
    if (data.isEmpty) return;

    final parsedData = parsePrintJob(data);

    final printJob = PrintJob(
      timestamp: DateTime.now(),
      connectionType: ConnectionType.usb,
      clientIp: null,
      vendorId: null,
      productId: null,
      rawData: data,
      rawHex: parsedData.rawHex,
      renderedText: parsedData.renderedText,
      jobSize: parsedData.jobSize,
      serviceType: 'Star:${printer.modelName ?? printer.portName}',
      contentBlocks: parsedData.contentBlocks,
    );

    final id = await _databaseService.insertPrintJob(printJob);
    _printJobController.add(printJob.copyWith(id: id));

    print('Star printer print job received: ${printJob.jobSize} bytes');
  }

  Future<void> stopListening() async {
    _connectedPrinter = null;
    _isListening = false;
    print('Star printer listening stopped');
  }

  Future<bool> printRawData(List<int> data, PortInfo printer) async {
    try {
      final printCommands = PrintCommands();
      printCommands.push({'appendRawBytes': Uint8List.fromList(data)});

      final result = await StarPrnt.sendCommands(
        portName: printer.portName ?? '',
        emulation: _getEmulation(printer.modelName),
        printCommands: printCommands,
      );

      return result.isSuccess;
    } catch (e) {
      print('Star printer print error: $e');
      return false;
    }
  }

  String _getEmulation(String? modelName) {
    if (modelName == null) return StarEmulation.StarPRNT.text;

    final model = modelName.toLowerCase();
    if (model.contains('escpos') || model.contains('mobile')) {
      return StarEmulation.EscPosMobile.text;
    }
    if (model.contains('sp700')) return StarEmulation.StarDotImpact.text;
    if (model.contains('line')) return StarEmulation.StarLine.text;
    if (model.contains('graphic')) return StarEmulation.StarGraphic.text;
    if (model.contains('prntl')) return StarEmulation.StarPRNTL.text;

    return StarEmulation.StarPRNT.text;
  }

  void dispose() {
    stopListening();
    _printJobController.close();
  }
}
