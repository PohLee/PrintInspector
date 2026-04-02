import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:path/path.dart' as p;
import 'package:pasteboard/pasteboard.dart';
import '../models/print_job.dart';
import '../parser/escpos_parser.dart';

class PrintJobExporter {
  static Future<void> copyToClipboard(GlobalKey boundaryKey) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RepaintBoundary not found');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to convert image to byte data');
      
      final pngBytes = byteData.buffer.asUint8List();
      await Pasteboard.writeImage(pngBytes);
    } catch (e) {
      debugPrint('Error copying to clipboard: $e');
      rethrow;
    }
  }

  static Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted) return true;
      if (await Permission.manageExternalStorage.request().isGranted) return true;
      // For Android 13+
      if (await Permission.photos.request().isGranted) return true;
      return false;
    }
    return true;
  }

  static Future<void> saveAsImage(GlobalKey boundaryKey, String fileName) async {
    try {
      if (Platform.isAndroid) await _requestPermissions();
      
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RepaintBoundary not found');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to convert image to byte data');
      
      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path, '${fileName}_${DateTime.now().millisecondsSinceEpoch}.png'));
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Rendered Print Job Image');
    } catch (e) {
      debugPrint('Error saving as image: $e');
      rethrow;
    }
  }

  static Future<void> saveAsPdf(PrintJob job, String fileName) async {
    try {
      if (Platform.isAndroid) await _requestPermissions();
      
      final doc = pw.Document();
      
      // Load a monospace font for receipt-like look
      final font = await PdfGoogleFonts.courierPrimeRegular();
      
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.all(12),
          build: (pw.Context context) {
            if (job.contentBlocks.isEmpty) {
              return [
                pw.Text(
                  job.renderedText,
                  style: pw.TextStyle(font: font, fontSize: 9),
                )
              ];
            }
            
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: job.contentBlocks.map((block) {
                  if (block.type == PrintContentType.text && block.text != null) {
                    return pw.Text(
                      block.text!.trimRight(),
                      style: pw.TextStyle(font: font, fontSize: 9),
                    );
                  } else if ((block.type == PrintContentType.bitImage || 
                             block.type == PrintContentType.rasterImage) && 
                             block.imageData != null) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Image(
                        pw.MemoryImage(block.imageData!),
                        fit: pw.BoxFit.contain,
                      ),
                    );
                  } else if (block.type == PrintContentType.pageBreak) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8),
                      child: pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                    );
                  }
                  return pw.SizedBox.shrink();
                }).toList(),
              ),
            ];
          },
        ),
      );

      final pdfBytes = await doc.save();
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path, '${fileName}_${DateTime.now().millisecondsSinceEpoch}.pdf'));
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Print Job PDF');
    } catch (e) {
      debugPrint('Error saving as PDF: $e');
      rethrow;
    }
  }
}
