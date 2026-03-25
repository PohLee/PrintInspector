import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../app.dart';
import '../models/print_job.dart';
import '../screens/job_detail_screen.dart';
import 'database_service.dart';
import 'printer_server.dart';
import 'star_printer_service.dart';
import 'usb_service.dart';

class PrintJobService {
  static final PrintJobService _instance = PrintJobService._internal();
  factory PrintJobService() => _instance;
  PrintJobService._internal();

  final PrinterServer _printerServer = PrinterServer();
  final DatabaseService _databaseService = DatabaseService();
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

    // Check if the app was launched from a notification
    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      if (launchDetails?.notificationResponse != null) {
        _onNotificationTapped(launchDetails!.notificationResponse!);
      }
    }

    await _createNotificationChannel();

    _listenToAllPrintJobs();

    _initialized = true;
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    print('Notification tapped: $payload');
    
    final id = int.tryParse(payload);
    if (id == null) return;

    // Wait for navigator to be ready (up to 5 seconds)
    int attempts = 0;
    while (App.navigatorKey.currentState == null && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    final job = await _databaseService.getPrintJobById(id);
    if (job != null && App.navigatorKey.currentState != null) {
      // Clear navigation stack and go to the detail page or just push it?
      // Usually for notification taps, we just push the page.
      App.navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => JobDetailScreen(printJob: job),
        ),
      );
    } else {
      print('Navigation failed: job is null or navigator state still null');
    }
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
      // Notification ID must be a 32-bit integer
      final notificationId = (printJob.id ?? DateTime.now().millisecondsSinceEpoch) % 2147483647;
      
      await _notifications.show(
        notificationId,
        'New Print Job',
        'Received ${printJob.jobSize} bytes from ${printJob.clientIp ?? "unknown"}',
        details,
        payload: printJob.id?.toString(),
      );
    } catch (e) {
      print('Notification error: $e');
    }
  }

  Future<void> forwardJobs(List<PrintJob> jobs) async {
    if (jobs.isEmpty) return;

    // Combine raw data into a single stream
    List<int> combinedData = [];
    for (var job in jobs) {
      combinedData.addAll(job.rawData);
    }

    print('Forwarding ${jobs.length} jobs (${combinedData.length} bytes) to printer service');

    // If a Star printer is connected, forward to it
    if (_starService.connectedPrinter != null) {
      await _starService.printRawData(combinedData, _starService.connectedPrinter!);
    } else {
      // In a real app, this would send to the configured output printer
      // For now, we simulate success
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
