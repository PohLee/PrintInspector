import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pageWidthController = TextEditingController();
  final TextEditingController _dpiController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.loadSettings();
    _portController.text = _settingsService.tcpPort.toString();
    _nameController.text = _settingsService.printerName;
    _pageWidthController.text = _settingsService.pageWidth.toString();
    _dpiController.text = _settingsService.dpi.toString();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    int port = int.tryParse(_portController.text) ?? 9100;
    // Clamp to valid port range
    if (port < AppConstants.minPort || port > AppConstants.maxPort) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Port must be between ${AppConstants.minPort} and ${AppConstants.maxPort}. Reverting to 9100.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      port = 9100;
      _portController.text = '9100';
    }
    final pageWidth = int.tryParse(_pageWidthController.text) ?? 80;
    final dpi = int.tryParse(_dpiController.text) ?? 203;
    await _settingsService.setTcpPort(port);
    await _settingsService.setPrinterName(_nameController.text);
    await _settingsService.setPageWidth(pageWidth);
    await _settingsService.setDpi(dpi);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  void _showPortPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Port'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPortOption(9100, '9100 (Standard ESC/POS)'),
            _buildPortOption(9101, '9101'),
            _buildPortOption(515, '515 (LPR)'),
            _buildPortOption(631, '631 (IPP)'),
            const Divider(),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Custom Port',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPortOption(int port, String label) {
    return ListTile(
      title: Text(label),
      leading: Radio<int>(
        value: port,
        groupValue: int.tryParse(_portController.text) ?? 9100,
        onChanged: (value) {
          _portController.text = value.toString();
          Navigator.pop(context);
          setState(() {});
        },
      ),
      onTap: () {
        _portController.text = port.toString();
        Navigator.pop(context);
        setState(() {});
      },
    );
  }

  void _showMDNSServicePicker() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('mDNS Service Types'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: AppConstants.mDNSServiceTypes.entries.map((entry) {
                return CheckboxListTile(
                  title: Text(entry.value),
                  subtitle: Text(entry.key),
                  value: _settingsService.mdnsServiceTypes.contains(entry.key),
                  onChanged: (checked) async {
                    final types =
                        Set<String>.from(_settingsService.mdnsServiceTypes);
                    if (checked == true) {
                      types.add(entry.key);
                    } else {
                      types.remove(entry.key);
                    }
                    try {
                      await _settingsService.setMdnsServiceTypes(types);
                    } catch (e) {
                      print('Error saving mDNS service types: $e');
                    }
                    setDialogState(() {});
                    setState(() {});
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Printer Configuration'),
            _buildSettingsCard([
              _buildTextField(
                controller: _nameController,
                label: 'Printer Name',
                icon: Icons.edit,
                helperText: 'Name displayed for discovery',
              ),
              const Divider(),
              _buildPortSetting(),
              const Divider(),
              _buildTextField(
                controller: _pageWidthController,
                label: 'Page Width (mm)',
                icon: Icons.straighten,
                helperText: 'Common: 58, 80, 82, 100',
              ),
              const Divider(),
              _buildTextField(
                controller: _dpiController,
                label: 'DPI (dots per inch)',
                icon: Icons.grid_on,
                helperText: 'Common: 180, 203, 300',
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle('Connection Options'),
            _buildSettingsCard([
              _buildSwitchTile(
                title: 'Network Server',
                subtitle: 'Enable TCP/IP server for receiving print jobs',
                icon: Icons.wifi,
                value: _settingsService.networkEnabled,
                onChanged: (value) {
                  _settingsService.setNetworkEnabled(value);
                  setState(() {});
                },
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'USB Host',
                subtitle: 'Enable USB host mode (Android only)',
                icon: Icons.usb,
                value: _settingsService.usbEnabled,
                onChanged: (value) {
                  _settingsService.setUsbEnabled(value);
                  setState(() {});
                },
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'Star Protocol',
                subtitle: 'Enable Star printer protocol support',
                icon: Icons.print,
                value: _settingsService.starEnabled,
                onChanged: (value) {
                  _settingsService.setStarEnabled(value);
                  setState(() {});
                },
              ),
              const Divider(),
              _buildMDNSSetting(),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle('Auto Start'),
            _buildSettingsCard([
              _buildSwitchTile(
                title: 'Start TCP/IP Printer Server on App Launch',
                subtitle:
                    'Automatically start the network print server when the app opens',
                icon: Icons.play_circle,
                value: _settingsService.autoStart,
                onChanged: (value) {
                  _settingsService.setAutoStart(value);
                  setState(() {});
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle('About'),
            _buildSettingsCard([
              _buildInfoTile(
                title: 'Version',
                value: AppConstants.appVersion,
                icon: Icons.info_outline,
              ),
              const Divider(),
              _buildInfoTile(
                title: 'ESC/POS Commands',
                value: 'Full Support',
                icon: Icons.check_circle_outline,
              ),
            ]),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadius),
                  ),
                ),
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildPortSetting() {
    return ListTile(
      leading: const Icon(Icons.settings_ethernet),
      title: const Text('TCP Port'),
      subtitle: Text('${_settingsService.tcpPort}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showPortPicker,
    );
  }

  Widget _buildMDNSSetting() {
    return ListTile(
      leading: const Icon(Icons.broadcast_on_home),
      title: const Text('mDNS Service Types'),
      subtitle: Text('${_settingsService.mdnsServiceTypes.length} enabled'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showMDNSServicePicker,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppConstants.primaryColor),
      title: Text(title),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
      ),
    );
  }

  @override
  void dispose() {
    _portController.dispose();
    _nameController.dispose();
    _pageWidthController.dispose();
    _dpiController.dispose();
    super.dispose();
  }
}
