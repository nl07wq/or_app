import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA icon manifest resolves the generated production icon set', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, Object?>;
    final icons = (manifest['icons']! as List<Object?>)
        .cast<Map<String, Object?>>();

    expect(manifest['background_color'], '#061522');
    expect(manifest['theme_color'], '#061522');
    expect(icons, hasLength(4));
    expect(icons.map((icon) => icon['src']), [
      'icons/Icon-192.png',
      'icons/Icon-512.png',
      'icons/Icon-maskable-192.png',
      'icons/Icon-maskable-512.png',
    ]);
    expect(icons[2]['purpose'], 'maskable');
    expect(icons[3]['purpose'], 'maskable');

    for (final icon in icons) {
      final path = 'web/${icon['src']}';
      final size = int.parse((icon['sizes']! as String).split('x').first);
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(_pngSize(File(path)), (size, size), reason: path);
      expect(icon['type'], 'image/png');
    }
  });

  test('launcher and HTML contracts use the intended icon source', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final index = File('web/index.html').readAsStringSync();

    expect(pubspec, contains('image_path: "assets/icons/orlo_icon.png"'));
    expect(File('assets/icons/orlo_icon.png').existsSync(), isTrue);
    expect(File('web/favicon.png').existsSync(), isTrue);
    expect(index, contains('href="icons/Icon-192.png"'));
    expect(index, contains('href="favicon.png"'));
    expect(index, contains('href="manifest.json"'));
  });
}

(int, int) _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}
