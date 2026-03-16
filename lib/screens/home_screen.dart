import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import '../services/print_job_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/usb_service.dart';
import '../services/mdns_service.dart';
import '../models/print_job.dart';
import '../utils/constants.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PrintJobService _printJobService = PrintJobService();
  final DatabaseService _databaseService = DatabaseService();
  final SettingsService _settingsService = SettingsService();
  final UsbService _usbService = UsbService();
  final MDNSService _mdnsService = MDNSService();
  StreamSubscription<PrintJob>? _printJobSubscription;

  bool _isServerRunning = false;
  int _printJobCount = 0;
  String _statusMessage = 'Server stopped';
  List<UsbDevice> _usbDevices = [];
  bool _isUsbListening = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPrintJobCount();
    _listenToPrintJobs();
    _loadUsbDevices();
  }

  Future<void> _loadUsbDevices() async {
    if (_settingsService.usbEnabled) {
      try {
        final devices = await _usbService.discoverDevices();
        setState(() {
          _usbDevices = devices;
          _isUsbListening = _usbService.isRunning;
        });
      } catch (e) {
        print('USB discovery error: $e');
      }
    }
  }

  Future<void> _startUsbListening(UsbDevice device) async {
    final success = await _usbService.startListening(device);
    setState(() {
      _isUsbListening = success;
    });
    if (success) {
      _loadPrintJobCount();
    }
  }

  Future<void> _stopUsbListening() async {
    await _usbService.stopListening();
    setState(() {
      _isUsbListening = false;
    });
  }

  void _listenToPrintJobs() {
    _printJobSubscription = _printJobService.onPrintJob.listen((_) {
      _loadPrintJobCount();
    });
  }

  bool get _isTablet {
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 600;
  }

  Future<void> _loadSettings() async {
    await _settingsService.loadSettings();
    _printJobService.setPort(_settingsService.tcpPort);
    _mdnsService.setServiceTypes(_settingsService.mdnsServiceTypes);
    
    if (_settingsService.autoStart && _settingsService.networkEnabled) {
      final success = await _printJobService.startServer();
      if (success && _settingsService.mdnsEnabled) {
        await _mdnsService.startAdvertising(_settingsService.tcpPort, _settingsService.printerName);
      }
      if (mounted) {
        setState(() {
          _isServerRunning = success;
          _statusMessage = success
              ? 'Server running on port ${_settingsService.tcpPort}'
              : 'Failed to start server';
        });
      }
    }
    setState(() {});
  }

  Future<void> _loadPrintJobCount() async {
    final count = await _databaseService.getPrintJobCount();
    setState(() {
      _printJobCount = count;
    });
  }

  Future<void> _toggleServer() async {
    if (_isServerRunning) {
      await _mdnsService.stopAdvertising();
      await _printJobService.stopServer();
      setState(() {
        _isServerRunning = false;
        _statusMessage = 'Server stopped';
      });
    } else {
      final success = await _printJobService.startServer();
      if (success && _settingsService.mdnsEnabled) {
        await _mdnsService.startAdvertising(_settingsService.tcpPort, _settingsService.printerName);
      }
      setState(() {
        _isServerRunning = success;
        _statusMessage = success
            ? 'Server running on port ${_settingsService.tcpPort}'
            : 'Failed to start server';
      });
    }
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    ).then((_) => _loadPrintJobCount());
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) {
      _loadSettings();
      _loadUsbDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildMainStatusCard(),
                const SizedBox(height: 24),
                _buildQuickActionGrid(),
                const SizedBox(height: 24),
                _buildConnectionSection(),
                const SizedBox(height: 80), // Space for FAB-like button
              ]),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildServerToggleButton(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      centerTitle: false,
      elevation: 0,
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Text(
          AppConstants.appName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppConstants.primaryGradient,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(AppConstants.historyIcon, color: Colors.white),
          onPressed: _navigateToHistory,
          tooltip: 'History',
        ),
        IconButton(
          icon: const Icon(AppConstants.settingsIcon, color: Colors.white),
          onPressed: _navigateToSettings,
          tooltip: 'Settings',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMainStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAnimatedStatusIcon(),
          const SizedBox(height: 20),
          Text(
            _isServerRunning ? 'Server Active' : 'Server Inactive',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_isServerRunning ? AppConstants.accentColor : AppConstants.textSecondary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: _isServerRunning ? AppConstants.accentColor : AppConstants.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedStatusIcon() {
    return SizedBox(
      height: 120, // Constant height to prevent card jumping during pulse
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isServerRunning)
            _PulsingRing(color: AppConstants.accentColor),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: (_isServerRunning ? AppConstants.accentColor : AppConstants.errorColor).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isServerRunning ? Icons.radar_rounded : Icons.power_settings_new_rounded,
              size: 40,
              color: _isServerRunning ? AppConstants.accentColor : AppConstants.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Jobs',
            _printJobCount.toString(),
            Icons.receipt_long_rounded,
            AppConstants.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'TCP Port',
            _settingsService.tcpPort.toString(),
            Icons.lan_rounded,
            AppConstants.warningColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppConstants.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Connectivity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textPrimary,
                ),
          ),
        ),
        _buildConnectionCard(
          'Network Discovery',
          _isServerRunning ? 'Active on ${_settingsService.tcpPort}' : 'Disabled',
          AppConstants.networkIcon,
          _isServerRunning ? AppConstants.accentColor : AppConstants.textSecondary,
        ),
        const SizedBox(height: 12),
        _buildUsbConnectionCard(),
        const SizedBox(height: 12),
        _buildConnectionCard(
          'mDNS Advertising',
          _settingsService.mdnsEnabled ? 'Enabled' : 'Disabled',
          Icons.broadcast_on_home_rounded,
          _settingsService.mdnsEnabled ? AppConstants.primaryColor : AppConstants.textSecondary,
        ),
      ],
    );
  }

  Widget _buildConnectionCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsbConnectionCard() {
    final bool isUsbActive = _isUsbListening;
    final Color color = isUsbActive ? AppConstants.accentColor : AppConstants.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(AppConstants.usbIcon, color: AppConstants.primaryColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'USB Port',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    Text(
                      !_settingsService.usbEnabled 
                        ? 'Disabled in settings' 
                        : isUsbActive ? 'Listening' : 'Ready to scan',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_settingsService.usbEnabled)
                IconButton(
                  onPressed: isUsbActive 
                    ? _stopUsbListening 
                    : (_usbDevices.isNotEmpty ? () => _startUsbListening(_usbDevices.first) : _loadUsbDevices),
                  icon: Icon(isUsbActive ? Icons.stop_circle_rounded : Icons.play_circle_rounded),
                  color: isUsbActive ? AppConstants.errorColor : AppConstants.accentColor,
                  iconSize: 32,
                ),
            ],
          ),
          if (_usbDevices.isNotEmpty && _settingsService.usbEnabled) ...[
            const Divider(height: 24),
            ..._usbDevices.map((device) => Padding(
                  padding: const EdgeInsets.only(left: 48, bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.usb_rounded, size: 14, color: AppConstants.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          device.productName ?? device.deviceName,
                          style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildServerToggleButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 200,
      height: 56,
      child: ElevatedButton(
        onPressed: _toggleServer,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isServerRunning ? AppConstants.errorColor : AppConstants.accentColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: (_isServerRunning ? AppConstants.errorColor : AppConstants.accentColor).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isServerRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
            const SizedBox(width: 12),
            Text(
              _isServerRunning ? 'STOP SERVER' : 'START SERVER',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _printJobSubscription?.cancel();
    _mdnsService.dispose();
    super.dispose();
  }
}

class _PulsingRing extends StatefulWidget {
  final Color color;
  const _PulsingRing({required this.color});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 80 + (40 * _controller.value),
          height: 80 + (40 * _controller.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withOpacity(1 - _controller.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
