import 'package:flutter_test/flutter_test.dart';
import 'package:print_inspector/parser/escpos_parser.dart';

void main() {
  test('Bit image (ESC *) is not parsed as empty but emits [BIT IMAGE ...]',
      () {
    // 00 1B 40 1B 32 1B 33 00 1B 61 01 1B 2A 21 40 02 00 00 ...
    // ESC @ / ESC 2 / ESC 3 0 / ESC a 1 / ESC * 33 64 2
    List<int> bytes = [
      0x00,
      0x1B,
      0x40,
      0x1B,
      0x32,
      0x1B,
      0x33,
      0x00,
      0x1B,
      0x61,
      0x01,
      0x1B,
      0x2A,
      0x21,
      0x40,
      0x02
    ];

    // Fill the remainder with zeros (3 * 576 = 1728 bytes of data)
    bytes.addAll(List.filled(1728, 0));

    // Add LF at the end
    bytes.add(0x0A);

    // Also test it with a few text characters before and after to ensure spacing
    List<int> job = [];
    job.addAll('Hello\n'.codeUnits);
    job.addAll(bytes);
    job.addAll('World\n'.codeUnits);

    final parser = ESCPOSParser();
    final result = parser.parse(job);
    final blocks = parser.contentBlocks;

    print('Rendered result:');
    print(result);
    print('Content blocks: ${blocks.length}');
    for (var block in blocks) {
      print(
          'Block type: ${block.type}, imageData: ${block.imageData?.length ?? 0} bytes');
    }

    expect(blocks.any((b) => b.type == PrintContentType.bitImage), isTrue,
        reason: 'Parser should produce bit image block');
    expect(
        blocks.any((b) =>
            b.type == PrintContentType.text &&
            b.text?.contains('Hello') == true),
        isTrue);
    expect(
        blocks.any((b) =>
            b.type == PrintContentType.text &&
            b.text?.contains('World') == true),
        isTrue);
  });
}
