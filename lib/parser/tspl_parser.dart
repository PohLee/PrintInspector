import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'escpos_parser.dart';

class TSPLParser {
  final List<String> _lines = [];
  final List<PrintContentBlock> _contentBlocks = [];

  String parse(List<int> data) {
    _lines.clear();
    _contentBlocks.clear();

    int i = 0;
    while (i < data.length) {
      // Skip leading control characters but keep CR/LF for separation
      if (data[i] < 32 &&
          data[i] != 0x0A &&
          data[i] != 0x0D &&
          data[i] != 0x09) {
        i++;
        continue;
      }

      if (data[i] == 0x0A || data[i] == 0x0D) {
        i++;
        continue;
      }

      int lineStart = i;
      int lineEnd = i;
      while (lineEnd < data.length &&
          data[lineEnd] != 0x0A &&
          data[lineEnd] != 0x0D) {
        lineEnd++;
      }

      String line =
          utf8.decode(data.sublist(lineStart, lineEnd), allowMalformed: true);
      // Remove replacement characters () and leading/trailing whitespace
      line = line.replaceAll('\uFFFD', '').trim();

      if (line.isEmpty) {
        i = lineEnd;
        continue;
      }

      if (line.startsWith('BITMAP ')) {
        // TSPL BITMAP format: BITMAP X,Y,width,height,mode,bitmap data
        try {
          final paramsStr = line.substring(7);
          final parts = paramsStr.split(',');
          if (parts.length >= 6) {
            int widthBytes = int.parse(parts[2].trim());
            int heightDots = int.parse(parts[3].trim());

            // Find where the raw data starts (right after the 5th comma in the command line)
            int commaCount = 0;
            int dataStartInLine = -1;
            // We need the original raw index, so we scan the raw sublist
            List<int> cmdData = data.sublist(lineStart, lineEnd);
            for (int j = 0; j < cmdData.length; j++) {
              if (cmdData[j] == 0x2C) {
                // ','
                commaCount++;
                if (commaCount == 5) {
                  dataStartInLine = j + 1;
                  break;
                }
              }
            }

            if (dataStartInLine != -1) {
              int absoluteDataStart = lineStart + dataStartInLine;
              int expectedDataLengths = widthBytes * heightDots;

              if (absoluteDataStart + expectedDataLengths <= data.length) {
                String bitmapCmdStr = utf8
                    .decode(data.sublist(lineStart, absoluteDataStart),
                        allowMalformed: true)
                    .replaceAll('\uFFFD', '');
                _lines.add(
                    '$bitmapCmdStr[BITMAP DATA ${expectedDataLengths} bytes]');

                List<int> imageData = data.sublist(
                    absoluteDataStart, absoluteDataStart + expectedDataLengths);
                Uint8List? pngData =
                    _decodeRasterImage(imageData, widthBytes, heightDots);

                _contentBlocks.add(PrintContentBlock(
                  type: PrintContentType.rasterImage,
                  text: '$bitmapCmdStr[BITMAP DATA]',
                  imageData: pngData,
                  width: widthBytes * 8,
                  height: heightDots,
                ));

                i = absoluteDataStart + expectedDataLengths;
                continue;
              }
            }
          }
        } catch (e) {
          // Fallback to normal string processing
        }
      }

      // If we are here, it's a normal command line
      _lines.add(line);
      _processCommand(line);

      i = lineEnd;
    }

    return _lines.join('\n');
  }

  void _processCommand(String line) {
    String upperLine = line.toUpperCase();

    // Instructions that setup the printer
    if (upperLine.startsWith('SIZE ') ||
        upperLine.startsWith('GAP ') ||
        upperLine.startsWith('REFERENCE ') ||
        upperLine.startsWith('DIRECTION ') ||
        upperLine.startsWith('OFFSET ') ||
        upperLine.startsWith('SHIFT ') ||
        upperLine.startsWith('CLS') ||
        upperLine.startsWith('EOP')) {
      _contentBlocks.add(
          PrintContentBlock(type: PrintContentType.instruction, text: line));
      return;
    }

    if (upperLine.startsWith('TEXT ')) {
      _contentBlocks
          .add(PrintContentBlock(type: PrintContentType.text, text: line));
    } else if (upperLine.startsWith('PRINT ')) {
      _contentBlocks.add(PrintContentBlock(type: PrintContentType.pageBreak));
    } else if (upperLine.startsWith('BARCODE ') ||
        upperLine.startsWith('QRCODE ')) {
      _contentBlocks
          .add(PrintContentBlock(type: PrintContentType.text, text: line));
    } else {
      // Fallback for other commands
      _contentBlocks
          .add(PrintContentBlock(type: PrintContentType.text, text: line));
    }
  }

  List<PrintContentBlock> get contentBlocks =>
      List.unmodifiable(_contentBlocks);

  Uint8List? _decodeRasterImage(List<int> data, int widthBytes, int height) {
    try {
      int width = widthBytes * 8;
      final image = img.Image(width: width, height: height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          int byteIndex = (y * widthBytes) + (x ~/ 8);
          int bitIndex = 7 - (x % 8);
          if (byteIndex < data.length) {
            int byte = data[byteIndex];
            // TSPL BITMAP: "1: dot printed, 0: not printed"
            // If it looks inverted (black background, white text), it means 1=Ink resulted in black label.
            // Actually, usually 1=Ink=Black. If the whole background is black, it means the driver sent 1s for background.
            // But usually labels are white. So we should probably swap 0 and 1 interpretation if requested.
            // User said it looks inverted, so we will flip the logic.
            bool pixelSet = (byte & (1 << bitIndex)) != 0;

            // Inverting here: if bit is set (Ink), we want it to be White if the current result is black background.
            // Or more simply, if user says it's inverted, we just flip the colors.
            image.setPixel(
                x,
                y,
                pixelSet
                    ? img.ColorUint8.rgb(
                        255, 255, 255) // White (Inverted from Black)
                    : img.ColorUint8.rgb(
                        0, 0, 0)); // Black (Inverted from White)
          } else {
            image.setPixel(x, y, img.ColorUint8.rgb(255, 255, 255));
          }
        }
      }
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      return null;
    }
  }
}
