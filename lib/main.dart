import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/print_job_service.dart';
import 'services/usb_service.dart';
import 'services/settings_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  final printJobService = PrintJobService();
  await printJobService.initialize();
  await printJobService.requestNotificationPermission();

  final settingsService = SettingsService();
  await settingsService.loadSettings();

  if (settingsService.usbEnabled) {
    final usbService = UsbService();
    try {
      final devices = await usbService.discoverDevices();
      if (devices.isNotEmpty) {
        await usbService.startListening(devices.first);
      }
    } catch (e) {
      print('USB initialization failed: $e');
    }
  }

  runApp(const App());
}
