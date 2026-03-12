import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'PrintInspector';
  static const String appVersion = '1.0.0';

  static const int defaultPort = 9100;
  static const int minPort = 1;
  static const int maxPort = 65535;

  static const List<int> availablePorts = [9100, 9101, 515, 631];

  static const Map<String, String> mDNSServiceTypes = {
    '_pdl-datastream._tcp': 'ESC/POS (Standard)',
    '_ipp._tcp': 'IPP (Internet Printing)',
    '_printer._tcp': 'LPR/LPD Printer',
  };

  static const Color primaryColor = Color(0xFF2196F3);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);

  static const double cardElevation = 2.0;
  static const double borderRadius = 12.0;

  static const IconData serverIcon = Icons.dns;
  static const IconData historyIcon = Icons.history;
  static const IconData settingsIcon = Icons.settings;
  static const IconData printIcon = Icons.print;
  static const IconData usbIcon = Icons.usb;
  static const IconData networkIcon = Icons.wifi;
}
