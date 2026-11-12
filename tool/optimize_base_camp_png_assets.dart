import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const _root = 'assets/images/themes/base_camp';

Future<void> main() async {
  final files =
      Directory(_root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.png'))
          .toList()
        ..sort((a, b) => a.lengthSync().compareTo(b.lengthSync()));
  var beforeTotal = 0;
  var afterTotal = 0;
  var changed = 0;
  for (final file in files) {
    final before = await file.readAsBytes();
    beforeTotal += before.length;
    final source = image.decodePng(before);
    if (source == null) {
      stderr.writeln('SKIP decode failed: ${file.path}');
      afterTotal += before.length;
      continue;
    }
    final encoded = image.encodePng(
      source,
      level: 6,
      filter: image.PngFilter.paeth,
    );
    final verified = image.decodePng(encoded);
    final exact =
        verified != null &&
        verified.width == source.width &&
        verified.height == source.height &&
        _sameBytes(
          source.getBytes(order: image.ChannelOrder.rgba),
          verified.getBytes(order: image.ChannelOrder.rgba),
        );
    if (!exact || encoded.length >= before.length) {
      stdout.writeln(
        'KEEP\t${before.length}\t${file.path}'
        '${exact ? '' : '\tPIXEL_MISMATCH'}',
      );
      afterTotal += before.length;
      continue;
    }
    await file.writeAsBytes(encoded, flush: true);
    changed++;
    afterTotal += encoded.length;
    stdout.writeln(
      'OPTIMIZED\t${before.length}\t${encoded.length}\t${file.path}',
    );
  }
  stdout.writeln(
    'SUMMARY\tfiles=${files.length}\tchanged=$changed\t'
    'before=$beforeTotal\tafter=$afterTotal\tsaved=${beforeTotal - afterTotal}',
  );
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
