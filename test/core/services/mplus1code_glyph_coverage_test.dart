import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled M PLUS 1 Code cmap covers representative Japanese UI text', () {
    final cmap = _Format12Cmap.fromTtf(
      File('assets/fonts/MPLUS1Code[wght].ttf').readAsBytesSync(),
    );
    const requiredSamples = [
      '過去の食事履歴を確認・編集できます。',
      '体脂肪率',
      '公休日',
      '有給休暇',
      '勤務',
      '初期化',
      '登録',
      '同期',
      '栄養',
      '検索',
      '0123456789%kg:・。',
    ];
    final missing = <int>{
      for (final sample in requiredSamples)
        for (final codePoint in sample.runes)
          if (!cmap.contains(codePoint)) codePoint,
    };

    expect(missing, isEmpty, reason: 'M PLUS 1 Code UI glyph coverage changed');

    // The official font does not map these two presentation symbols. Flutter's
    // normal platform fallback remains intentional; KleeOne is not used as a
    // hidden fallback for them.
    expect(cmap.contains(0x301c), isFalse); // WAVE DASH: 〜
    expect(cmap.contains(0xff0b), isFalse); // FULLWIDTH PLUS: ＋
  });
}

class _Format12Cmap {
  _Format12Cmap(this._groups);

  final List<({int first, int last})> _groups;

  factory _Format12Cmap.fromTtf(List<int> bytes) {
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final tableCount = data.getUint16(4, Endian.big);
    int? cmapOffset;
    for (var index = 0; index < tableCount; index++) {
      final offset = 12 + (index * 16);
      final tag = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      if (tag == 'cmap') {
        cmapOffset = data.getUint32(offset + 8, Endian.big);
        break;
      }
    }
    if (cmapOffset == null) {
      throw const FormatException('M PLUS 1 Code has no cmap table');
    }

    final encodingCount = data.getUint16(cmapOffset + 2, Endian.big);
    int? subtableOffset;
    for (var index = 0; index < encodingCount; index++) {
      final offset = cmapOffset + 4 + (index * 8);
      final platform = data.getUint16(offset, Endian.big);
      final encoding = data.getUint16(offset + 2, Endian.big);
      if (platform == 3 && encoding == 10) {
        subtableOffset = cmapOffset + data.getUint32(offset + 4, Endian.big);
        break;
      }
    }
    if (subtableOffset == null ||
        data.getUint16(subtableOffset, Endian.big) != 12) {
      throw const FormatException(
        'M PLUS 1 Code has no Unicode format 12 cmap',
      );
    }

    final count = data.getUint32(subtableOffset + 12, Endian.big);
    return _Format12Cmap(
      List.generate(count, (index) {
        final offset = subtableOffset! + 16 + (index * 12);
        return (
          first: data.getUint32(offset, Endian.big),
          last: data.getUint32(offset + 4, Endian.big),
        );
      }),
    );
  }

  bool contains(int codePoint) => _groups.any(
    (group) => group.first <= codePoint && codePoint <= group.last,
  );
}
