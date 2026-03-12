import 'dart:convert';
import '../parser/escpos_parser.dart';

enum ConnectionType {
  network,
  usb,
  bluetooth,
}

class PrintJob {
  final int? id;
  final DateTime timestamp;
  final ConnectionType connectionType;
  final String? clientIp;
  final int? vendorId;
  final int? productId;
  final List<int> rawData;
  final String rawHex;
  final String renderedText;
  final int jobSize;
  final String? serviceType;
  final List<PrintContentBlock> contentBlocks;

  PrintJob({
    this.id,
    required this.timestamp,
    required this.connectionType,
    this.clientIp,
    this.vendorId,
    this.productId,
    required this.rawData,
    required this.rawHex,
    required this.renderedText,
    required this.jobSize,
    this.serviceType,
    required this.contentBlocks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'connection_type': connectionType.name,
      'client_ip': clientIp,
      'vendor_id': vendorId,
      'product_id': productId,
      'raw_data': rawData,
      'raw_hex': rawHex,
      'rendered_text': renderedText,
      'job_size': jobSize,
      'service_type': serviceType,
      'content_blocks': jsonEncode(contentBlocks
          .map((cb) => {
                'type': cb.type.index,
                'text': cb.text,
                'imageData':
                    cb.imageData != null ? base64Encode(cb.imageData!) : null,
                'width': cb.width,
                'height': cb.height,
              })
          .toList()),
    };
  }

  factory PrintJob.fromMap(Map<String, dynamic> map) {
    List<PrintContentBlock> contentBlocks = [];
    if (map['content_blocks'] != null) {
      try {
        final List<dynamic> decoded =
            jsonDecode(map['content_blocks'] as String);
        contentBlocks = decoded.map((item) {
          return PrintContentBlock(
            type: PrintContentType.values[item['type'] as int],
            text: item['text'] as String?,
            imageData: item['imageData'] != null
                ? base64Decode(item['imageData'] as String)
                : null,
            width: item['width'] as int?,
            height: item['height'] as int?,
          );
        }).toList();
      } catch (_) {
        contentBlocks = [];
      }
    }
    return PrintJob(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      connectionType: ConnectionType.values.firstWhere(
        (e) => e.name == map['connection_type'],
        orElse: () => ConnectionType.network,
      ),
      clientIp: map['client_ip'] as String?,
      vendorId: map['vendor_id'] as int?,
      productId: map['product_id'] as int?,
      rawData: List<int>.from(map['raw_data']),
      rawHex: map['raw_hex'] as String,
      renderedText: map['rendered_text'] as String,
      jobSize: map['job_size'] as int,
      serviceType: map['service_type'] as String?,
      contentBlocks: contentBlocks,
    );
  }

  PrintJob copyWith({
    int? id,
    DateTime? timestamp,
    ConnectionType? connectionType,
    String? clientIp,
    int? vendorId,
    int? productId,
    List<int>? rawData,
    String? rawHex,
    String? renderedText,
    int? jobSize,
    String? serviceType,
    List<PrintContentBlock>? contentBlocks,
  }) {
    return PrintJob(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      connectionType: connectionType ?? this.connectionType,
      clientIp: clientIp ?? this.clientIp,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      rawData: rawData ?? this.rawData,
      rawHex: rawHex ?? this.rawHex,
      renderedText: renderedText ?? this.renderedText,
      jobSize: jobSize ?? this.jobSize,
      serviceType: serviceType ?? this.serviceType,
      contentBlocks: contentBlocks ?? this.contentBlocks,
    );
  }

  String get connectionTypeDisplay {
    switch (connectionType) {
      case ConnectionType.network:
        return 'Network';
      case ConnectionType.usb:
        return 'USB';
      case ConnectionType.bluetooth:
        return 'Bluetooth';
    }
  }

  String get renderType {
    if (contentBlocks.isEmpty) return 'Text';
    bool hasText = false;
    bool hasImage = false;
    for (final block in contentBlocks) {
      if (block.type == PrintContentType.text) hasText = true;
      if (block.type == PrintContentType.bitImage || block.type == PrintContentType.rasterImage) hasImage = true;
    }
    if (hasText && hasImage) return 'Mixed';
    if (hasImage) return 'Image';
    return 'Text';
  }
}
