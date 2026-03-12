import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nsd/nsd.dart' as nsd;

class MDNSService {
  bool _isAdvertising = false;
  final List<nsd.Registration> _registrations = [];

  final Set<String> _serviceTypes = {
    '_pdl-datastream._tcp',
    '_ipp._tcp',
    '_printer._tcp',
  };

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;
  bool get isAdvertising => _isAdvertising;

  Set<String> get serviceTypes => _serviceTypes;

  void addServiceType(String type) {
    _serviceTypes.add(type);
  }

  void removeServiceType(String type) {
    _serviceTypes.remove(type);
  }

  void setServiceTypes(Set<String> types) {
    _serviceTypes.clear();
    _serviceTypes.addAll(types);
  }

  Future<void> startAdvertising(int port, String printerName) async {
    if (_isAdvertising) return;

    _isAdvertising = true;
    _statusController.add('Starting mDNS advertising...');

    for (final serviceType in _serviceTypes) {
      await _advertiseService(printerName, serviceType, port);
    }

    _statusController
        .add('mDNS services configured: ${_serviceTypes.length} types');
  }

  Future<void> _advertiseService(String name, String type, int port) async {
    try {
      // Provide TXT records to help apps identify this as a Star Micronics or standard printer
      final service = nsd.Service(
        name: name,
        type: type,
        port: port,
        txt: {
          'usb_MFG': Uint8List.fromList(utf8.encode('Star Micronics')),
          'usb_MDL': Uint8List.fromList(utf8.encode('TSP100')),
          'ty': Uint8List.fromList(utf8.encode('Star Printer Emulator')),
          'note': Uint8List.fromList(utf8.encode('Virtual Device')),
        },
      );
      final registration = await nsd.register(service);
      _registrations.add(registration);
      print('Service advertised: $name ($type) on port $port');
    } catch (e) {
      print('Error advertising $type: $e');
    }
  }

  Future<void> stopAdvertising() async {
    for (final reg in _registrations) {
      try {
        await nsd.unregister(reg);
      } catch (e) {
        print('Error unregistering mDNS service: $e');
      }
    }
    _registrations.clear();
    _isAdvertising = false;
    _statusController.add('mDNS advertising stopped');
  }

  void dispose() {
    stopAdvertising();
    _statusController.close();
  }
}

class MDNSServiceType {
  static const String pdlDatastream = '_pdl-datastream._tcp';
  static const String ipp = '_ipp._tcp';
  static const String printer = '_printer._tcp';

  static const Map<String, String> serviceNames = {
    pdlDatastream: 'ESC/POS (Port 9100)',
    ipp: 'Internet Printing',
    printer: 'LPR/LPD Printer',
  };

  static const Map<String, int> defaultPorts = {
    pdlDatastream: 9100,
    ipp: 631,
    printer: 515,
  };
}
