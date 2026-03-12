import 'dart:async';
import 'dart:io';
import '../models/print_job.dart';
import '../parser/escpos_parser.dart';
import 'database_service.dart';

class PrinterServer {
  ServerSocket? _server;
  final DatabaseService _databaseService;
  int _port;
  bool _isRunning = false;
  final StreamController<PrintJob> _printJobController =
      StreamController<PrintJob>.broadcast();

  PrinterServer({
    DatabaseService? databaseService,
    int port = 9100,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _port = port;

  int get port => _port;
  bool get isRunning => _isRunning;
  Stream<PrintJob> get onPrintJob => _printJobController.stream;

  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;

      _server!.listen(
        _handleClient,
        onError: (error) {
          print('Server error: $error');
        },
      );

      print('Printer server started on port $_port');
      return true;
    } catch (e) {
      print('Failed to start server: $e');
      _isRunning = false;
      return false;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    await _server?.close();
    _server = null;
    _isRunning = false;
    print('Printer server stopped');
  }

  void setPort(int port) {
    _port = port;
  }

  Future<void> _handleClient(Socket client) async {
    final clientIP = client.address.address;
    final clientPort = client.port;
    print('Client connected: $clientIP:$clientPort');

    final List<int> data = [];

    try {
      await for (final chunk in client) {
        data.addAll(chunk);
      }

      if (data.isNotEmpty) {
        await _processPrintJob(data, clientIP);
      }
    } catch (e) {
      print('Error handling client: $e');
    } finally {
      client.close();
      print('Client disconnected: $clientIP:$clientPort');
    }
  }

  Future<void> _processPrintJob(List<int> data, String clientIP) async {
    final parsedData = parsePrintJob(data);

    final printJob = PrintJob(
      timestamp: DateTime.now(),
      connectionType: ConnectionType.network,
      clientIp: clientIP,
      rawData: data,
      rawHex: parsedData.rawHex,
      renderedText: parsedData.renderedText,
      jobSize: parsedData.jobSize,
      serviceType: '$_port',
      contentBlocks: parsedData.contentBlocks,
    );

    final id = await _databaseService.insertPrintJob(printJob);
    _printJobController.add(printJob.copyWith(id: id));

    print('Print job received: ${parsedData.jobSize} bytes from $clientIP');
  }

  void dispose() {
    stop();
    _printJobController.close();
  }
}
