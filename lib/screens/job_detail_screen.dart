import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/print_job.dart';
import '../parser/escpos_parser.dart';
import '../utils/constants.dart';

class JobDetailScreen extends StatefulWidget {
  final PrintJob printJob;

  const JobDetailScreen({super.key, required this.printJob});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _shareContent() {
    final content = '''
ESC/POS Print Job Details
========================

Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.printJob.timestamp)}
Connection: ${widget.printJob.connectionTypeDisplay}
${widget.printJob.clientIp != null ? 'Client IP: ${widget.printJob.clientIp}' : ''}
Size: ${widget.printJob.jobSize} bytes

--- Rendered Text ---
${widget.printJob.renderedText}

--- Raw Hex ---
${ESCPOSParser.bytesToPrettyHex(widget.printJob.rawData)}
''';

    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Content copied to clipboard')),
    );
  }

  void _copyHex() {
    Clipboard.setData(ClipboardData(text: widget.printJob.rawHex));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hex copied to clipboard')),
    );
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.printJob.renderedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Job Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareContent,
            tooltip: 'Share',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Rendered'),
            Tab(text: 'Raw Hex'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildMetadataCard(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRenderedTab(),
                _buildRawHexTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getConnectionIcon(widget.printJob.connectionType),
                  size: 20,
                  color: AppConstants.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.printJob.connectionTypeDisplay,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMetadataRow(
                'Timestamp', dateFormat.format(widget.printJob.timestamp)),
            _buildMetadataRow('Size', '${widget.printJob.jobSize} bytes'),
            if (widget.printJob.clientIp != null)
              _buildMetadataRow('Client IP', widget.printJob.clientIp!),
            if (widget.printJob.serviceType != null)
              _buildMetadataRow('Port', widget.printJob.serviceType!),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenderedTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Spacer(),
              TextButton.icon(
                onPressed: _copyText,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _buildContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final contentBlocks = widget.printJob.contentBlocks;

    if (contentBlocks.isEmpty) {
      return SelectableText(
        widget.printJob.renderedText.isEmpty
            ? '[Empty print job]'
            : widget.printJob.renderedText,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentBlocks.map((block) {
        if (block.type == PrintContentType.text && block.text != null) {
          return SelectableText(
            block.text!,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          );
        } else if ((block.type == PrintContentType.bitImage ||
                block.type == PrintContentType.rasterImage) &&
            block.imageData != null) {
          return Image.memory(
            block.imageData!,
            fit: BoxFit.contain,
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildRawHexTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Spacer(),
              TextButton.icon(
                onPressed: _copyHex,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: SelectableText(
                ESCPOSParser.bytesToPrettyHex(widget.printJob.rawData),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getConnectionIcon(ConnectionType type) {
    switch (type) {
      case ConnectionType.network:
        return Icons.wifi;
      case ConnectionType.usb:
        return Icons.usb;
      case ConnectionType.bluetooth:
        return Icons.bluetooth;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
