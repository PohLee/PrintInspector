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

  static const Color primaryColor = Color(0xFF6366F1); // Modern Indigo
  static const Color secondaryColor = Color(0xFFEC4899); // Pink for accents
  static const Color accentColor = Color(0xFF10B981); // Emerald Green
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color backgroundColor = Color(0xFFF8FAFC); // Very light grey-blue
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const double cardElevation = 0.0; // Use shadows or borders for modern look
  static const double borderRadius = 16.0;

  static const IconData serverIcon = Icons.dns_rounded;
  static const IconData historyIcon = Icons.history_rounded;
  static const IconData settingsIcon = Icons.settings_rounded;
  static const IconData printIcon = Icons.print_rounded;
  static const IconData usbIcon = Icons.usb_rounded;
  static const IconData networkIcon = Icons.wifi_rounded;
}
