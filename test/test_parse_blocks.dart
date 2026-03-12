import 'package:flutter_test/flutter_test.dart';
import 'package:print_inspector/parser/escpos_parser.dart';

void main() {
  test('test blocks', () {
    String hexStr = "00 1B 40 1B 32 1B 33 00 1B 61 01 1B 2A 21 40 02 00 00 00 0A 1B 2A 21 40 02 00 00 00 0A";
    List<int> bytes = hexStr.split(' ').map((s) => int.parse(s, radix: 16)).toList();

    final parser = ESCPOSParser();
    parser.parse(bytes);
    for (var b in parser.contentBlocks) {
      if (b.type == PrintContentType.text) {
        print('TEXT: [${b.text}]');
      } else {
        print('IMAGE: ${b.width}x${b.height}');
      }
    }
  });
}
