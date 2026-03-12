import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/print_job.dart';
import 'printer_server.dart';
import 'star_printer_service.dart';
import 'usb_service.dart';

class PrintJobService {
  static final PrintJobService _instance = PrintJobService._internal();
  factory PrintJobService() => _instance;
  PrintJobService._internal();

  final PrinterServer _printerServer = PrinterServer();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final UsbService _usbService = UsbService();
  final StreamController<PrintJob> _allJobsController = StreamController<PrintJob>.broadcast();

  Stream<PrintJob> get onPrintJob => _allJobsController.stream;
  bool get isServerRunning => _printerServer.isRunning;
  int get port => _printerServer.port;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannel();

    _listenToAllPrintJobs();

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  Future<void> _createNotificationChannel() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'print_jobs',
            'Print Jobs',
            description: 'Notifications for received print jobs',
            importance: Importance.high,
          ),
        );
  }

  StreamSubscription<PrintJob>? _networkSubscription;
  StreamSubscription<PrintJob>? _usbSubscription;
  StreamSubscription<PrintJob>? _starSubscription;
  bool _initialized = false;
  final StarPrinterService _starService = StarPrinterService();

  void _listenToAllPrintJobs() {
    _networkSubscription?.cancel();
    _networkSubscription = _printerServer.onPrintJob.listen((printJob) {
      _allJobsController.add(printJob);
      _showNotification(printJob);
    });

    _usbSubscription?.cancel();
    _usbSubscription = _usbService.onPrintJob.listen((printJob) {
      _allJobsController.add(printJob);
      _showNotification(printJob);
    });

    _starSubscription?.cancel();
    _starSubscription = _starService.onPrintJob.listen((printJob) {
      _allJobsController.add(printJob);
      _showNotification(printJob);
    });
  }

  Future<bool> startServer() async {
    final success = await _printerServer.start();
    return success;
  }

  Future<void> stopServer() async {
    await _printerServer.stop();
  }

  void setPort(int port) {
    _printerServer.setPort(port);
  }

  Future<void> _showNotification(PrintJob printJob) async {
    const androidDetails = AndroidNotificationDetails(
      'print_jobs',
      'Print Jobs',
      channelDescription: 'Notifications for received print jobs',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        printJob.id ?? DateTime.now().millisecondsSinceEpoch,
        'New Print Job',
        'Received ${printJob.jobSize} bytes from ${printJob.clientIp ?? "unknown"}',
        details,
      );
    } catch (e) {
      print('Notification error: $e');
    }
  }

  Future<void> requestNotificationPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  void dispose() {
    _networkSubscription?.cancel();
    _usbSubscription?.cancel();
    _printerServer.dispose();
  }
}
