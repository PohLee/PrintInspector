import 'dart:async';
import 'package:usb_serial/usb_serial.dart';
import '../models/print_job.dart';
import '../parser/escpos_parser.dart';
import '../services/database_service.dart';

class UsbService {
  static final UsbService _instance = UsbService._internal();
  factory UsbService() => _instance;
  UsbService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final StreamController<PrintJob> _printJobController =
      StreamController<PrintJob>.broadcast();

  List<UsbDevice> _devices = [];
  UsbPort? _connectedPort;
  UsbDevice? _connectedDevice;
  bool _isRunning = false;

  // Buffer to accumulate streaming chunks into a full print job.
  final List<int> _dataBuffer = [];
  Timer? _flushTimer;
  static const _flushIdleMs = 200;

  Stream<PrintJob> get onPrintJob => _printJobController.stream;
  List<UsbDevice> get devices => _devices;
  bool get isRunning => _isRunning;

  Stream<UsbEvent>? get usbEvents => UsbSerial.usbEventStream;

  Future<List<UsbDevice>> discoverDevices() async {
    _devices = await UsbSerial.listDevices();
    return _devices;
  }

  Future<bool> startListening(UsbDevice device) async {
    if (_isRunning) {
      await stopListening();
    }

    try {
      _connectedPort = await device.create();
      if (await _connectedPort!.open() != true) {
        return false;
      }

      _connectedDevice = device;

      await _connectedPort!.setPortParameters(
        9600,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _connectedPort!.inputStream?.listen(
        _onChunkReceived,
        onError: (error) {
          print('USB error: $error');
        },
      );

      _isRunning = true;
      print('USB listening started on ${device.productName}');
      return true;
    } catch (e) {
      print('Failed to start USB listening: $e');
      return false;
    }
  }

  /// Accumulate incoming bytes and reset the idle-flush timer.
  void _onChunkReceived(List<int> chunk) {
    if (chunk.isEmpty) return;
    _dataBuffer.addAll(chunk);
    _flushTimer?.cancel();
    _flushTimer =
        Timer(const Duration(milliseconds: _flushIdleMs), _flushBuffer);
  }

  /// Called when no new data has arrived for [_flushIdleMs] ms —
  /// treat the accumulated buffer as one complete print job.
  void _flushBuffer() async {
    if (_dataBuffer.isEmpty) return;
    final data = List<int>.from(_dataBuffer);
    _dataBuffer.clear();

    try {
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
        serviceType: _connectedDevice?.productName ?? 'USB',
        contentBlocks: parsedData.contentBlocks,
      );

      final id = await _databaseService.insertPrintJob(printJob);
      _printJobController.add(printJob.copyWith(id: id));

      print('USB print job received: ${printJob.jobSize} bytes');
    } catch (e) {
      print('Error processing USB print job: $e');
    }
  }

  Future<void> stopListening() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _dataBuffer.clear();
    await _connectedPort?.close();
    _connectedPort = null;
    _connectedDevice = null;
    _isRunning = false;
    print('USB listening stopped');
  }

  Future<void> dispose() async {
    await stopListening();
    _printJobController.close();
  }
}
