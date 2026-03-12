import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/print_job_service.dart';
import '../models/print_job.dart';
import '../parser/escpos_parser.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPrintJobs();
    _listenToPrintJobs();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print History'),
        actions: [
          if (_printJobs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
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
                const VerticalDivider(width: 1, thickness: 1),
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
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(onPressed: () {
                setState(() { _selectedJob = null; });
              }, icon: const Icon(Icons.arrow_back)),
              const Expanded(child: Text("Job Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              IconButton(
                icon: const Icon(Icons.info_outline),
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
            decoration: InputDecoration(
              hintText: 'Search print jobs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() { _searchQuery = ''; });
                        _loadPrintJobs();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                      child: ListView.separated(
                        itemCount: _printJobs.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final job = _printJobs[index];
                          // On mobile, keep it unselected visually when viewing main list? Actually it's fine.
                          // If mobile and in list view, _selectedJob is null, so isSelected is false.
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
            Icon(Icons.print, size: 80, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Select a print job to view details', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
          ],
        )
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Print Result', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(DateFormat('MMM dd, yyyy HH:mm:ss').format(_selectedJob!.timestamp), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _copyText(_selectedJob!),
                icon: const Icon(Icons.copy, size: 20),
                label: const Text('Copy Rendered'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showJobInfoBottomSheet(context, _selectedJob!),
                icon: const Icon(Icons.info_outline, size: 20),
                label: const Text('Job Info'),
              ),
            ],
          ),
        ),
        Expanded(child: _buildJobContent(_selectedJob!)),
      ],
    );
  }

  Widget _buildJobContent(PrintJob job) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _buildPrintoutContent(job),
          ),
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MMM dd HH:mm');

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected ? BorderSide(color: colorScheme.primary.withOpacity(0.5), width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                      color: isSelected ? colorScheme.primary.withOpacity(0.1) : colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getConnectionIcon(job.connectionType),
                      size: 20,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormat.format(job.timestamp),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.primary,
                              ),
                        ),
                        Text(
                          job.connectionTypeDisplay,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isSelected ? colorScheme.onPrimaryContainer.withOpacity(0.8) : colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _buildRenderTypeChip(job, isSelected),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${job.jobSize} bytes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected ? colorScheme.onPrimaryContainer.withOpacity(0.7) : colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const Spacer(),
                  if (job.id != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        // Prevent the card tap
                        _deletePrintJob(job.id!);
                      },
                      color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    IconData icon = Icons.text_snippet;
    Color chipColor = isSelected ? colorScheme.primary.withOpacity(0.2) : colorScheme.surfaceVariant;
    Color textColor = isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;
    
    if (job.renderType == 'Image') {
      icon = Icons.image;
      if (!isSelected) {
        chipColor = colorScheme.secondaryContainer;
        textColor = colorScheme.onSecondaryContainer;
      }
    }
    if (job.renderType == 'Mixed') {
      icon = Icons.collections;
      if (!isSelected) {
        chipColor = colorScheme.tertiaryContainer;
        textColor = colorScheme.onTertiaryContainer;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            job.renderType,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
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
          Icon(
            Icons.print_disabled,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No print jobs yet' : 'No results found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Print jobs will appear here when received'
                : 'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                ),
          ),
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
    super.dispose();
  }
}
