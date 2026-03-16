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
  late TransformationController _transformationController;
  double _currentScale = 0.8;
  final GlobalKey _viewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _transformationController = TransformationController();
    _transformationController.value = Matrix4.identity()..scale(_currentScale);

    _transformationController.addListener(() {
      final newScale = _transformationController.value.getMaxScaleOnAxis();
      if ((newScale - _currentScale).abs() > 0.01) {
        setState(() {
          _currentScale = newScale;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetZoom();
    });
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

  void _updateZoom(double delta) {
    final RenderBox? renderBox = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final width = renderBox.size.width;
    final currentY = _transformationController.value.getTranslation().y;
    
    setState(() {
      _currentScale = (_currentScale + delta).clamp(0.1, 4.0);
      _transformationController.value = Matrix4.identity()
        ..translate((width - 380 * _currentScale) / 2, currentY, 0)
        ..scale(_currentScale);
    });
  }

  void _resetZoom() {
    final RenderBox? renderBox = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final width = renderBox.size.width;
    setState(() {
      _currentScale = 0.8;
      _transformationController.value = Matrix4.identity()
        ..translate((width - 380 * _currentScale) / 2, 0, 0)
        ..scale(_currentScale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Print Job Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppConstants.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareContent,
            tooltip: 'Share',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorColor: AppConstants.primaryColor,
          labelColor: AppConstants.primaryColor,
          unselectedLabelColor: AppConstants.textSecondary,
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

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
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
              const SizedBox(width: 12),
              Text(
                widget.printJob.connectionTypeDisplay,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMetadataRow('Timestamp', dateFormat.format(widget.printJob.timestamp)),
          _buildMetadataRow('Size', '${widget.printJob.jobSize} bytes'),
          if (widget.printJob.clientIp != null)
            _buildMetadataRow('Client IP', widget.printJob.clientIp!),
          if (widget.printJob.serviceType != null)
            _buildMetadataRow('Port', widget.printJob.serviceType!),
        ],
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
              style: const TextStyle(
                fontSize: 12,
                color: AppConstants.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppConstants.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _updateZoom(-0.1),
            icon: const Icon(Icons.zoom_out_rounded, size: 20),
            tooltip: 'Zoom Out',
            color: AppConstants.textPrimary,
          ),
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(_currentScale * 100).toInt()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold,
                color: AppConstants.primaryColor,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _updateZoom(0.1),
            icon: const Icon(Icons.zoom_in_rounded, size: 20),
            tooltip: 'Zoom In',
            color: AppConstants.textPrimary,
          ),
          IconButton(
            onPressed: _resetZoom,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Reset Zoom (80%)',
            color: AppConstants.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildRenderedTab() {
    return Container(
      key: _viewerKey,
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.symmetric(horizontal: 5000, vertical: 1000),
                minScale: 0.1,
                maxScale: 4.0,
                constrained: false,
                panAxis: PanAxis.vertical,
                child: Container(
                  width: 380,
                  margin: const EdgeInsets.symmetric(vertical: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    child: _buildContent(),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'copy_text',
                  onPressed: _copyText,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                  backgroundColor: AppConstants.surfaceColor,
                  foregroundColor: AppConstants.primaryColor,
                  elevation: 4,
                ),
                const SizedBox(height: 16),
                _buildZoomToolbar(),
              ],
            ),
          ),
        ],
      ),
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
          color: Colors.black,
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
              color: Colors.black,
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
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy Hex'),
                style: TextButton.styleFrom(
                  foregroundColor: AppConstants.primaryColor,
                ),
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
                color: const Color(0xFF0F172A), // Modern dark slate
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: SelectableText(
                ESCPOSParser.bytesToPrettyHex(widget.printJob.rawData),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF10B981), // Emerald for hex
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
        return AppConstants.networkIcon;
      case ConnectionType.usb:
        return AppConstants.usbIcon;
      case ConnectionType.bluetooth:
        return Icons.bluetooth_rounded;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transformationController.dispose();
    super.dispose();
  }
}
