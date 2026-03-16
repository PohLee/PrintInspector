import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/print_job_service.dart';
import '../models/print_job.dart';
import '../parser/escpos_parser.dart';
import '../utils/constants.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final PrintJobService _printJobService = PrintJobService();
  StreamSubscription<PrintJob>? _printJobSubscription;
  List<PrintJob> _printJobs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  PrintJob? _selectedJob;
  late TransformationController _transformationController;
  double _currentScale = 0.8;
  final GlobalKey _viewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.value = Matrix4.identity()..scale(_currentScale);
    _loadPrintJobs();
    _listenToPrintJobs();
    
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

  void _listenToPrintJobs() {
    _printJobSubscription = _printJobService.onPrintJob.listen((newJob) {
      _loadPrintJobs(newSelectedJob: newJob);
    });
  }

  Future<void> _loadPrintJobs({PrintJob? newSelectedJob}) async {
    if (!mounted) return;
    if (_printJobs.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    List<PrintJob> jobs;
    if (_searchQuery.isEmpty) {
      jobs = await _databaseService.getAllPrintJobs();
    } else {
      jobs = await _databaseService.searchPrintJobs(_searchQuery);
    }

    if (!mounted) return;
    setState(() {
      _printJobs = jobs;
      _isLoading = false;
      
      if (newSelectedJob != null) {
        _selectedJob = newSelectedJob;
      } else if (_selectedJob != null) {
        // Refresh selected job if it still exists
        final stillExists = jobs.where((j) => j.id == _selectedJob!.id).toList();
        if (stillExists.isNotEmpty) {
          _selectedJob = stillExists.first;
        } else {
          _selectedJob = jobs.isNotEmpty ? jobs.first : null;
        }
      } else if (jobs.isNotEmpty) {
        _selectedJob = jobs.first;
      }
    });
  }

  Future<void> _deletePrintJob(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Print Job'),
        content: const Text('Are you sure you want to delete this print job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseService.deletePrintJob(id);
      if (_selectedJob?.id == id) {
        _selectedJob = null;
      }
      _loadPrintJobs();
    }
  }

  Future<void> _deleteAllPrintJobs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Print Jobs'),
        content: const Text(
            'Are you sure you want to delete all print jobs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseService.deleteAllPrintJobs();
      _selectedJob = null;
      _loadPrintJobs();
    }
  }

  void _showJobInfoBottomSheet(BuildContext context, PrintJob job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildJobInfoSheet(context, job),
    );
  }

  Widget _buildJobInfoSheet(BuildContext context, PrintJob job) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Print Job Info',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_getConnectionIcon(job.connectionType), color: colorScheme.primary),
            title: const Text('Connection'),
            subtitle: Text(job.connectionTypeDisplay),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print, color: colorScheme.primary),
            title: const Text('Render Type'),
            subtitle: Text(job.renderType),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.straighten, color: colorScheme.primary),
            title: const Text('Job Size'),
            subtitle: Text('${job.jobSize} bytes'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.access_time, color: colorScheme.primary),
            title: const Text('Timestamp'),
            subtitle: Text(dateFormat.format(job.timestamp)),
          ),
          if (job.clientIp != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.computer, color: colorScheme.primary),
              title: const Text('Client IP'),
              subtitle: Text(job.clientIp!),
            ),
          if (job.serviceType != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.router, color: colorScheme.primary),
              title: const Text('Service Type / Port'),
              subtitle: Text(job.serviceType!),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _copyHex(job);
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Raw Hex'),
            ),
          ),
        ],
      ),
    );
  }

  void _copyHex(PrintJob job) {
    Clipboard.setData(ClipboardData(text: job.rawHex));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Raw Hex copied to clipboard')),
    );
  }

  void _copyText(PrintJob job) {
    Clipboard.setData(ClipboardData(text: job.renderedText));
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
        title: const Text('Print History'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppConstants.textPrimary,
        actions: [
          if (_printJobs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _deleteAllPrintJobs,
              tooltip: 'Delete All',
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;
          
          if (isTablet) {
            return Row(
              children: [
                SizedBox(
                  width: 320,
                  child: _buildSideList(),
                ),
                Container(width: 1, color: Colors.black.withOpacity(0.05)),
                Expanded(
                  child: _buildMainView(),
                ),
              ],
            );
          } else {
            return _buildMobileView();
          }
        },
      ),
    );
  }
  
  Widget _buildMobileView() {
    if (_selectedJob == null) {
      return _buildSideList();
    }
    
    return Column(
      children: [
        Container(
          color: AppConstants.surfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(onPressed: () {
                setState(() { _selectedJob = null; });
              }, icon: const Icon(Icons.arrow_back_rounded)),
              const Expanded(child: Text("Job Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppConstants.textPrimary))),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => _showJobInfoBottomSheet(context, _selectedJob!),
                tooltip: 'Job Info',
              ),
            ],
          )
        ),
        const Divider(height: 1),
        Expanded(child: _buildJobContent(_selectedJob!)),
      ],
    );
  }

  Widget _buildSideList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppConstants.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search print jobs...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppConstants.primaryColor),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() { _searchQuery = ''; });
                        _loadPrintJobs();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppConstants.surfaceColor,
            ),
            onChanged: (q) {
              setState(() { _searchQuery = q; });
              _loadPrintJobs();
            },
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _printJobs.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadPrintJobs,
                      child: ListView.builder(
                        itemCount: _printJobs.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemBuilder: (context, index) {
                          final job = _printJobs[index];
                          final isSelected = MediaQuery.of(context).size.width >= 600 && _selectedJob?.id == job.id;
                          return _buildListTileCard(job, isSelected);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildMainView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_printJobs.isEmpty || _selectedJob == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.print_rounded, size: 80, color: AppConstants.textSecondary.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text('Select a print job to view details', style: TextStyle(color: AppConstants.textSecondary))
          ],
        )
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: AppConstants.surfaceColor,
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Print Sample', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppConstants.textPrimary)),
                  const SizedBox(height: 4),
                  Text(DateFormat('MMM dd, yyyy HH:mm:ss').format(_selectedJob!.timestamp), style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
                ],
              ),
              const Spacer(),
              _buildJobActionButtons(_selectedJob!),
            ],
          ),
        ),
        Expanded(child: _buildJobContent(_selectedJob!)),
      ],
    );
  }

  Widget _buildJobActionButtons(PrintJob job) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _copyText(job),
          icon: const Icon(Icons.copy_rounded, color: AppConstants.primaryColor),
          tooltip: 'Copy Text',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _showJobInfoBottomSheet(context, job),
          icon: const Icon(Icons.info_outline_rounded, color: AppConstants.primaryColor),
          tooltip: 'Job Info',
        ),
      ],
    );
  }

  Widget _buildZoomToolbar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _updateZoom(-0.1),
            icon: const Icon(Icons.zoom_out_rounded, size: 18),
            tooltip: 'Zoom Out',
            color: AppConstants.textPrimary,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
          ),
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${(_currentScale * 100).toInt()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.bold,
                color: AppConstants.primaryColor,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _updateZoom(0.1),
            icon: const Icon(Icons.zoom_in_rounded, size: 18),
            tooltip: 'Zoom In',
            color: AppConstants.textPrimary,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
          ),
          IconButton(
            onPressed: _resetZoom,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Reset Zoom (80%)',
            color: AppConstants.textSecondary,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildJobContent(PrintJob job) {
    return Container(
      key: _viewerKey,
      width: double.infinity,
      color: AppConstants.backgroundColor,
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
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    child: _buildPrintoutContent(job),
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
                  heroTag: 'history_copy_text',
                  onPressed: () => _copyText(job),
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

  Widget _buildPrintoutContent(PrintJob job) {
    final contentBlocks = job.contentBlocks;
    if (contentBlocks.isEmpty) {
      return SelectableText(
        job.renderedText.isEmpty ? '[Empty print job]' : job.renderedText,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5, color: Colors.black),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentBlocks.map((block) {
        if (block.type == PrintContentType.text && block.text != null) {
          return SelectableText(
            block.text!,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5, color: Colors.black),
          );
        } else if ((block.type == PrintContentType.bitImage || block.type == PrintContentType.rasterImage) && block.imageData != null) {
          return Image.memory(
            block.imageData!,
            fit: BoxFit.contain,
            width: double.infinity,
            alignment: Alignment.centerLeft,
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildListTileCard(PrintJob job, bool isSelected) {
    final dateFormat = DateFormat('MMM dd HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: isSelected ? AppConstants.primaryColor : Colors.black.withOpacity(0.05),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        onTap: () {
          setState(() {
            _selectedJob = job;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isSelected ? AppConstants.primaryColor : AppConstants.textSecondary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getConnectionIcon(job.connectionType),
                      size: 20,
                      color: isSelected ? AppConstants.primaryColor : AppConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormat.format(job.timestamp),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected ? AppConstants.primaryColor : AppConstants.textPrimary,
                          ),
                        ),
                        Text(
                          job.connectionTypeDisplay,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppConstants.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildRenderTypeChip(job, isSelected),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.straighten_rounded, size: 14, color: AppConstants.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${job.jobSize} bytes',
                    style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                  ),
                  const Spacer(),
                  if (job.id != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () => _deletePrintJob(job.id!),
                      color: AppConstants.errorColor.withOpacity(0.7),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRenderTypeChip(PrintJob job, bool isSelected) {
    IconData icon = Icons.text_snippet_rounded;
    Color chipColor = (isSelected ? AppConstants.primaryColor : AppConstants.textSecondary).withOpacity(0.1);
    Color textColor = isSelected ? AppConstants.primaryColor : AppConstants.textSecondary;
    
    if (job.renderType == 'Image') {
      icon = Icons.image_rounded;
    }
    if (job.renderType == 'Mixed') {
      icon = Icons.collections_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            job.renderType,
            style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.print_disabled_rounded, size: 64, color: AppConstants.textSecondary.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('No print jobs yet', style: TextStyle(color: AppConstants.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Incoming prints will appear here', style: TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
        ],
      ),
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

  String _truncateText(String text, int maxLength) {
    if (text.isEmpty) return 'No text content';
    if (text.length <= maxLength) return text.replaceAll('\n', ' ');
    return '${text.substring(0, maxLength).replaceAll('\n', ' ')}...';
  }

  @override
  void dispose() {
    _printJobSubscription?.cancel();
    _searchController.dispose();
    _transformationController.dispose();
    super.dispose();
  }
}
