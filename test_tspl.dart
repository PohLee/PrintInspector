import '../lib/parser/escpos_parser.dart';
import '../lib/parser/tspl_parser.dart';

void main() {
  List<int> tsplData = [
    83, 73, 90, 69, 32, 52, 44, 32, 51, 13, 10,  // SIZE 4, 3
    71, 65, 80, 32, 48, 44, 32, 48, 13, 10,      // GAP 0, 0
    67, 76, 83, 13, 10,                          // CLS
    84, 69, 88, 84, 32, 49, 48, 48, 44, 49, 48, 48, 44, 34, 51, 34, 44, 48, 44, 49, 44, 49, 44, 34, 72, 101, 108, 108, 111, 34, 13, 10 // TEXT 100,100,"3",0,1,1,"Hello"
  ];
  
  final job = parsePrintJob(tsplData);
  print(job.renderedText);
  print("Content blocks: \${job.contentBlocks.length}");
}
