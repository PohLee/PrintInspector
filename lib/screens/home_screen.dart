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
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _navigateToHistory,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;
          final isWideTablet = constraints.maxWidth >= 900;

          if (isWideTablet) {
            return _buildWideTabletLayout();
          } else if (isTablet) {
            return _buildTabletLayout();
          }
          return _buildPhoneLayout();
        },
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildServerStatusCard(),
          const SizedBox(height: 16),
          _buildServerControlCard(),
          const SizedBox(height: 16),
          _buildQuickStatsCard(),
          const SizedBox(height: 16),
          _buildConnectionInfoCard(),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildServerStatusCard(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildServerControlCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildQuickStatsCard()),
                ],
              ),
              const SizedBox(height: 16),
              _buildConnectionInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideTabletLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildServerStatusCard(),
                    const SizedBox(height: 20),
                    _buildServerControlCard(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildQuickStatsCard(),
                    const SizedBox(height: 20),
                    _buildConnectionInfoCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerStatusCard() {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              _isServerRunning ? Icons.cloud_done : Icons.cloud_off,
              size: 64,
              color: _isServerRunning
                  ? AppConstants.accentColor
                  : AppConstants.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              _isServerRunning ? 'Server Running' : 'Server Stopped',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isServerRunning
                        ? AppConstants.accentColor
                        : AppConstants.errorColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerControlCard() {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Control',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _toggleServer,
                icon: Icon(_isServerRunning ? Icons.stop : Icons.play_arrow),
                label: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isServerRunning
                      ? AppConstants.errorColor
                      : AppConstants.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.print,
                    label: 'Total Jobs',
                    value: _printJobCount.toString(),
                    color: AppConstants.primaryColor,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.usb,
                    label: 'Port',
                    value: _settingsService.tcpPort.toString(),
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _navigateToHistory,
                icon: const Icon(Icons.history),
                label: const Text('View Print History'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildConnectionInfoCard() {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Info',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                Icons.wifi,
                'Network',
                _isServerRunning
                    ? 'Port ${_settingsService.tcpPort}'
                    : 'Not active'),
            const Divider(),
            _buildUsbInfoRow(),
            const Divider(),
            _buildInfoRow(Icons.broadcast_on_home, 'mDNS',
                _settingsService.mdnsEnabled ? 'Enabled' : 'Disabled'),
            const Divider(),
            _buildInfoRow(Icons.print, 'Star Protocol',
                _settingsService.starEnabled ? 'Enabled' : 'Disabled'),
          ],
        ),
      ),
    );
  }

  Widget _buildUsbInfoRow() {
    if (!_settingsService.usbEnabled) {
      return _buildInfoRow(Icons.usb, 'USB', 'Disabled');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.usb, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            const Expanded(child: Text('USB')),
            if (_isUsbListening)
              const Text('Listening', style: TextStyle(color: Colors.green))
            else
              const Text('Not active'),
            const SizedBox(width: 8),
            if (_isUsbListening)
              IconButton(
                icon: const Icon(Icons.stop, size: 20),
                onPressed: _stopUsbListening,
                tooltip: 'Stop USB',
              )
            else
              IconButton(
                icon: const Icon(Icons.play_arrow, size: 20),
                onPressed: _usbDevices.isNotEmpty
                    ? () => _startUsbListening(_usbDevices.first)
                    : _loadUsbDevices,
                tooltip: _usbDevices.isNotEmpty ? 'Start USB' : 'Scan USB',
              ),
          ],
        ),
        if (_usbDevices.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._usbDevices.map((device) => Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 4),
                child: Text(
                  (device.productName?.isNotEmpty == true
                          ? device.productName!
                          : device.deviceName) ??
                      'USB Device',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              )),
        ] else if (_settingsService.usbEnabled) ...[
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4),
            child: TextButton.icon(
              onPressed: _loadUsbDevices,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Scan for USB devices'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
          ),
        ],
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
