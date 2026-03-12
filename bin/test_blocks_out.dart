import 'package:print_inspector/parser/escpos_parser.dart';

void main() {
    String hexStr = "1B 33 00 1B 2A 01 04 00 FF FF FF FF 0A 1B 2A 01 04 00 FF FF FF FF 0A";
    List<int> bytes = hexStr.split(' ').map((s) => int.parse(s, radix: 16)).toList();

    final parser = ESCPOSParser();
    parser.parse(bytes);
    print("Blocks: ${parser.contentBlocks.length}");
    for (var b in parser.contentBlocks) {
      if (b.type == PrintContentType.text) {
        print('TEXT: [${b.text}]');
      } else {
        print('IMAGE: ${b.width}x${b.height}');
      }
    }
}
