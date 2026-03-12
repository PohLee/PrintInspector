import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class PrintContentBlock {
  final PrintContentType type;
  final String? text;
  final Uint8List? imageData;
  final int? width;
  final int? height;

  PrintContentBlock({
    required this.type,
    this.text,
    this.imageData,
    this.width,
    this.height,
  });
}

enum PrintContentType {
  text,
  bitImage,
  rasterImage,
}

class ESCPOSParser {
  static final ESC = 0x1B;
  static final GS = 0x1D;
  static final FS = 0x1C;
  static final DLE = 0x10;
  static final CAN = 0x18;
  static final SP = 0x20;
  static final CR = 0x0D;
  static final LF = 0x0A;
  static final FF = 0x0C;
  static final HT = 0x09;
  static final VT = 0x0B;

  static const Map<int, String> _codePagePC437 = {
    0x80: 'Ç',
    0x81: 'ü',
    0x82: 'é',
    0x83: 'â',
    0x84: 'ä',
    0x85: 'à',
    0x86: 'å',
    0x87: 'ç',
    0x88: 'ê',
    0x89: 'ë',
    0x8A: 'è',
    0x8B: 'ï',
    0x8C: 'î',
    0x8D: 'ì',
    0x8E: 'Ä',
    0x8F: 'Å',
    0x90: 'É',
    0x91: 'æ',
    0x92: 'Æ',
    0x93: 'ô',
    0x94: 'ö',
    0x95: 'ò',
    0x96: 'û',
    0x97: 'ù',
    0x98: 'ÿ',
    0x99: 'Ö',
    0x9A: 'Ü',
    0x9B: '¢',
    0x9C: '£',
    0x9D: '¥',
    0x9E: '₧',
    0x9F: 'ƒ',
    0xA0: 'á',
    0xA1: 'í',
    0xA2: 'ó',
    0xA3: 'ú',
    0xA4: 'ñ',
    0xA5: 'Ñ',
    0xA6: 'ª',
    0xA7: 'º',
    0xA8: '¿',
    0xA9: '⌐',
    0xAA: '¬',
    0xAB: '½',
    0xAC: '¼',
    0xAD: '¡',
    0xAE: '«',
    0xAF: '»',
    0xB0: '░',
    0xB1: '▒',
    0xB2: '▓',
    0xB3: '│',
    0xB4: '┤',
    0xB5: '╡',
    0xB6: '╢',
    0xB7: '╖',
    0xB8: '╕',
    0xB9: '╗',
    0xBA: '╝',
    0xBB: '╜',
    0xBC: '╛',
    0xBD: '┐',
    0xBE: '└',
    0xBF: '┴',
    0xC0: '┬',
    0xC1: '├',
    0xC2: '─',
    0xC3: '┼',
    0xC4: '═',
    0xC5: '╞',
    0xC6: '╟',
    0xC7: '╚',
    0xC8: '╔',
    0xC9: '╩',
    0xCA: '╦',
    0xCB: '╠',
    0xCC: '═',
    0xCD: '╬',
    0xCE: '╧',
    0xCF: '╨',
    0xD0: '╤',
    0xD1: '╥',
    0xD2: '╙',
    0xD3: '╘',
    0xD4: '╒',
    0xD5: '╕',
    0xD6: '╣',
    0xD7: '║',
    0xD8: '╗',
    0xD9: '╝',
    0xDA: '╜',
    0xDB: '╛',
    0xDC: '┐',
    0xDD: '└',
    0xDE: '┴',
    0xDF: '┬',
    0xE0: '├',
    0xE1: '─',
    0xE2: '┼',
    0xE3: '╞',
    0xE4: '╟',
    0xE5: '╚',
    0xE6: '╔',
    0xE7: '╩',
    0xE8: '╦',
    0xE9: '╠',
    0xEA: '═',
    0xEB: '╬',
    0xEC: '╧',
    0xED: '╨',
    0xEE: '╤',
    0xEF: '╥',
    0xF0: '╙',
    0xF1: '╘',
    0xF2: '╒',
    0xF3: '╕',
    0xF4: '╣',
    0xF5: '║',
    0xF6: '╗',
    0xF7: '╝',
    0xF8: 'Έ',
    0xF9: 'Ή',
    0xFA: 'Ί',
    0xFB: 'Ό',
    0xFC: 'Ύ',
    0xFD: 'Ώ',
    0xFE: '·',
    0xFF: ' ',
  };

  static Map<int, String> _getCodePage(int codeTable) {
    switch (codeTable) {
      case 0:
        return _codePagePC437;
      default:
        return _codePagePC437;
    }
  }

  final StringBuffer _output = StringBuffer();
  final List<String> _lines = [];
  final List<PrintContentBlock> _contentBlocks = [];
  int _codeTable = 0;
  int _lineSpacing = 30;

  String _getCharForByte(int byte) {
    if (byte < 0x80) {
      if (byte == 0x09) return '\t';
      if (byte == 0x0A) return '\n';
      if (byte == 0x0D) return '\r';
      return String.fromCharCode(byte);
    }

    // For high bytes (0x80-0xFF), always look up in the active code page.
    // Passing them raw as Unicode codepoints produces mojibake.
    final codePage = _getCodePage(_codeTable);
    return codePage[byte] ?? String.fromCharCode(byte);
  }

  bool _containsValidPrintableChars(String text) {
    if (text.isEmpty) return false;
    int printableCount = 0;
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 32 || code == 9 || code == 10 || code == 13) {
        printableCount++;
      }
    }
    return printableCount > text.length * 0.5;
  }

  String _filterNonPrintable(String text) {
    StringBuffer filtered = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 32 || code == 9 || code == 10 || code == 13) {
        filtered.writeCharCode(code);
      } else if (code == 0x0A || code == 0x0D) {
        filtered.writeCharCode(code);
      }
    }
    return filtered.toString();
  }

  String _tryDecodeWithFallback(List<int> data) {
    if (data.isEmpty) return '';

    try {
      final decoded = utf8.decode(data, allowMalformed: true);
      if (_containsValidPrintableChars(decoded)) {
        return _filterNonPrintable(decoded);
      }
    } catch (_) {}

    try {
      final decoded = latin1.decode(data);
      if (_containsValidPrintableChars(decoded)) {
        return _filterNonPrintable(decoded);
      }
    } catch (_) {}

    StringBuffer sb = StringBuffer();
    for (int i = 0; i < data.length; i++) {
      int byte = data[i] & 0xFF;
      if (byte >= 32 && byte != 0x7F) {
        sb.write(String.fromCharCode(byte));
      } else if (byte == 0x0A || byte == 0x0D) {
        sb.write(String.fromCharCode(byte));
      } else if (byte == 0x09) {
        sb.write('\t');
      }
    }
    return sb.toString();
  }

  void _resetState() {
    _codeTable = 0;
    _lineSpacing = 30;
  }

  void _flushCurrentLine() {
    String line = _output.toString();
    if (line.isNotEmpty) {
      _contentBlocks
          .add(PrintContentBlock(type: PrintContentType.text, text: line));
      _lines.add(line);
      _output.clear();
    }
  }

  Uint8List? _decodeBitImage(
      List<int> data, int width, int height, int bytesPerCol) {
    try {
      final image = img.Image(width: width, height: height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          int byteIndex = (x * bytesPerCol) + (y ~/ 8);
          int bitIndex = 7 - (y % 8);
          if (byteIndex < data.length) {
            int byte = data[byteIndex];
            bool pixelSet = (byte & (1 << bitIndex)) != 0;
            image.setPixel(
                x,
                y,
                pixelSet
                    ? img.ColorUint8.rgb(0, 0, 0)
                    : img.ColorUint8.rgb(255, 255, 255));
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
            bool pixelSet = (byte & (1 << bitIndex)) != 0;
            image.setPixel(
                x,
                y,
                pixelSet
                    ? img.ColorUint8.rgb(0, 0, 0)
                    : img.ColorUint8.rgb(255, 255, 255));
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

  String parse(List<int> data) {
    _output.clear();
    _lines.clear();
    _contentBlocks.clear();
    _resetState();

    int i = 0;
    while (i < data.length) {
      int byte = data[i] & 0xFF;

      if (byte == ESC) {
        if (i + 1 < data.length) {
          i = _parseESC(data, i);
        } else {
          i++;
        }
      } else if (byte == GS) {
        if (i + 1 < data.length) {
          i = _parseGS(data, i);
        } else {
          i++;
        }
      } else if (byte == FS) {
        if (i + 1 < data.length) {
          i = _parseFS(data, i);
        } else {
          i++;
        }
      } else if (byte == DLE) {
        if (i + 1 < data.length) {
          i = _parseDLE(data, i);
        } else {
          i++;
        }
      } else if (byte == HT) {
        _output.write('\t');
        i++;
      } else if (byte == LF) {
        _flushCurrentLine();
        if (_lineSpacing > 0) {
          _output.write('\n');
        }
        i++;
      } else if (byte == CR) {
        _flushCurrentLine();
        i++;
      } else if (byte == FF) {
        _flushCurrentLine();
        _output.write('\f');
        i++;
      } else if (byte == CAN) {
        _output.clear();
        i++;
      } else if (byte >= 0x20) {
        _output.write(_getCharForByte(byte));
        i++;
      } else {
        i++;
      }
    }

    _flushCurrentLine();
    String result = _lines.join('\n');

    if (result.isEmpty || _isMostlyGarbled(result)) {
      return _tryDecodeWithFallback(data);
    }

    return result;
  }

  List<PrintContentBlock> get contentBlocks =>
      List.unmodifiable(_contentBlocks);

  bool _isMostlyGarbled(String text) {
    if (text.isEmpty) return false;
    int garbledCount = 0;
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code < 32 && code != 9 && code != 10 && code != 13) {
        garbledCount++;
      }
    }
    return garbledCount > text.length * 0.1;
  }

  int _parseESC(List<int> data, int index) {
    int cmd = data[index + 1] & 0xFF;

    switch (cmd) {
      case 0x40:
        _resetState();
        _flushCurrentLine();
        return index + 2;
      case 0x21:
        return index + 3;
      case 0x24:
        return index + 4;
      case 0x2A:
        // ESC * m nL nH [data]
        // m   = mode (index+2): dots per column: 8 for m=0/1, 24 for m=32/33
        // nL/nH (index+3/4) = number of columns
        // Data length = ceil(dotsPerCol / 8) * n
        if (index + 4 < data.length) {
          int m = data[index + 2] & 0xFF;
          int nL = data[index + 3] & 0xFF;
          int nH = data[index + 4] & 0xFF;
          int n = nL + (nH << 8);
          int dotsPerCol = (m == 32 || m == 33) ? 24 : 8;
          int bytesPerCol = (dotsPerCol + 7) ~/ 8;
          int dataLen = bytesPerCol * n;
          if (index + 5 + dataLen <= data.length) {
            List<int> imageData = data.sublist(index + 5, index + 5 + dataLen);
            Uint8List? pngData =
                _decodeBitImage(imageData, n, dotsPerCol, bytesPerCol);
            if (pngData != null) {
              _flushCurrentLine();
              _contentBlocks.add(PrintContentBlock(
                type: PrintContentType.bitImage,
                imageData: pngData,
                width: n,
                height: dotsPerCol,
              ));
            } else {
              _output.write('[BIT IMAGE ${n}x${dotsPerCol}]');
            }
          }
          return index + 5 + dataLen;
        }
        return index + 5;
      case 0x2D:
        return index + 3;
      case 0x31:
        return index + 3;
      case 0x32:
        _lineSpacing = 30;
        return index + 2;
      case 0x33:
        if (index + 2 < data.length) {
          _lineSpacing = data[index + 2] & 0xFF;
          return index + 3;
        }
        return index + 2;
      case 0x34:
        return index + 3;
      case 0x45:
        return index + 3;
      case 0x47:
        return index + 3;
      case 0x4A:
        _flushCurrentLine();
        return index + 3;
      case 0x4D:
        return index + 3;
      case 0x52:
        return index + 3;
      case 0x54:
        return index + 3;
      case 0x56:
        return index + 3;
      case 0x61:
        return index + 3;
      case 0x64:
        _flushCurrentLine();
        return index + 3;
      case 0x74:
        _codeTable = data[index + 2] & 0xFF;
        return index + 3;
      case 0x7B:
        return index + 3;
      default:
        return index + 2;
    }
  }

  int _parseGS(List<int> data, int index) {
    int cmd = data[index + 1] & 0xFF;

    switch (cmd) {
      case 0x21:
        return index + 3;
      case 0x24:
        return index + 4;
      case 0x28:
        // GS ( X pL pH ...
        // The payload length is pL + (pH << 8), not a fixed 5 bytes.
        if (index + 3 < data.length) {
          int pL = data[index + 2] & 0xFF;
          int pH = data[index + 3] & 0xFF;
          int payloadLen = pL + (pH << 8);
          _output.write('[GS ( FUNCTION: $payloadLen bytes]');
          return index + 4 + payloadLen;
        }
        return index + 4;
      case 0x33:
        return index + 3;
      case 0x34:
        return index + 3;
      case 0x38:
        // GS 8 L p1 p2 p3 p4 m fn [parameters]
        // Length is 4 bytes: p1 + p2*256 + p3*65536 + p4*16777216
        if (index + 6 < data.length) {
          int p1 = data[index + 3] & 0xFF;
          int p2 = data[index + 4] & 0xFF;
          int p3 = data[index + 5] & 0xFF;
          int p4 = data[index + 6] & 0xFF;
          int payloadLen = p1 + (p2 << 8) + (p3 << 16) + (p4 << 24);
          _output.write('[GS 8 L FUNCTION: $payloadLen bytes]');
          return index + 7 + payloadLen;
        }
        return index + 7;
      case 0x42:
        return index + 3;
      case 0x48:
        return index + 3;
      case 0x4B:
        return index + 5;
      case 0x4C:
        return index + 4;
      case 0x56:
        if (data[index + 2] == 0x00 || data[index + 2] == 0x01) {
          _output.write('[PAPER CUT - FULL]\n');
        } else if (data[index + 2] == 0x30 || data[index + 2] == 0x31) {
          _output.write('[PAPER CUT - FULL]\n');
        } else if (data[index + 2] == 0x32 || data[index + 2] == 0x33) {
          _output.write('[PAPER CUT - PARTIAL]\n');
        }
        return index + 3;
      case 0x57:
        return index + 4;
      case 0x61:
        return index + 3;
      case 0x6B:
        // GS k k n [data] NUL  (k=type, n=length for type >= 65)
        // For barcode types 0-6 (old-style), data ends at NUL (0x00).
        // For types 65+ (A-J), next byte is explicit length n.
        if (index + 2 < data.length) {
          int barcodeType = data[index + 2] & 0xFF;
          if (barcodeType >= 65) {
            // New-style: GS k m n d1..dn
            if (index + 3 < data.length) {
              int n = data[index + 3] & 0xFF;
              if (index + 4 + n <= data.length) {
                List<int> barcodeData = data.sublist(index + 4, index + 4 + n);
                String text = String.fromCharCodes(
                    barcodeData.where((b) => b >= 0x20).toList());
                _output.write('[BARCODE: $text]\n');
              }
              return index + 4 + n;
            }
            return index + 3;
          } else {
            // Old-style: GS k k d1..dn NUL
            int j = index + 3;
            while (j < data.length && (data[j] & 0xFF) != 0x00) {
              j++;
            }
            if (j < data.length) {
              List<int> barcodeData = data.sublist(index + 3, j);
              String text = String.fromCharCodes(
                  barcodeData.where((b) => b >= 0x20).toList());
              _output.write('[BARCODE: $text]\n');
              return j + 1; // skip past NUL
            }
            return j;
          }
        }
        return index + 3;
      case 0x72:
        return index + 3;
      case 0x76:
        // GS v 0   m xL xH yL yH [data]
        // index+2 = sub-command (0x30=0, 0x31=1, etc.)
        // index+3/4 = xL/xH = width in BYTES
        // index+5/6 = yL/yH = height in DOTS (rows)
        // data length = widthBytes * height
        if (index + 6 < data.length) {
          int xL = data[index + 3] & 0xFF;
          int xH = data[index + 4] & 0xFF;
          int yL = data[index + 5] & 0xFF;
          int yH = data[index + 6] & 0xFF;
          int widthBytes = xL + (xH << 8);
          int height = yL + (yH << 8);
          int dataLen = widthBytes * height;
          if (index + 7 + dataLen <= data.length) {
            List<int> imageData = data.sublist(index + 7, index + 7 + dataLen);
            Uint8List? pngData =
                _decodeRasterImage(imageData, widthBytes, height);
            if (pngData != null) {
              _flushCurrentLine();
              _contentBlocks.add(PrintContentBlock(
                type: PrintContentType.rasterImage,
                imageData: pngData,
                width: widthBytes * 8,
                height: height,
              ));
            } else {
              _output.write('[IMAGE ${widthBytes * 8}x$height]\n');
            }
          }
          return index + 7 + dataLen;
        }
        return index + 7;
      case 0x77:
        return index + 3;
      default:
        return index + 2;
    }
  }

  int _parseFS(List<int> data, int index) {
    // FS commands are typically 2 bytes; skip cmd byte.
    return index + 2;
  }

  int _parseDLE(List<int> data, int index) {
    return index + 2;
  }

  static String bytesToHex(List<int> data) {
    return data
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  static String bytesToPrettyHex(List<int> data) {
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < data.length; i++) {
      if (i > 0) {
        if (i % 16 == 0) {
          sb.write('\n');
        } else if (i % 8 == 0) {
          sb.write('  ');
        } else {
          sb.write(' ');
        }
      }
      sb.write(data[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return sb.toString();
  }
}

class PrintJobData {
  final List<int> rawData;
  final String renderedText;
  final String rawHex;
  final int jobSize;
  final List<PrintContentBlock> contentBlocks;

  PrintJobData({
    required this.rawData,
    required this.renderedText,
    required this.rawHex,
    required this.jobSize,
    required this.contentBlocks,
  });
}

PrintJobData parsePrintJob(List<int> data) {
  final parser = ESCPOSParser();
  final renderedText = parser.parse(data);
  final rawHex = ESCPOSParser.bytesToHex(data);
  final contentBlocks = parser.contentBlocks;

  return PrintJobData(
    rawData: data,
    renderedText: renderedText,
    rawHex: rawHex,
    jobSize: data.length,
    contentBlocks: contentBlocks,
  );
}
