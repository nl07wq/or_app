import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/bird_v1_flight_preview.dart';

void main() {
  test('Bird V1 retains six supplied source cels and a forward flap loop', () {
    expect(BirdV1SourceSet.assets, hasLength(6));
    expect(BirdV1SourceSet.cycle, const [0, 1, 2, 3, 4, 5]);
    expect(BirdV1SourceSet.cycle, isNot(containsAllInOrder([5, 4])));
    expect(BirdV1SourceSet.bobOffsets, hasLength(BirdV1SourceSet.cycle.length));
    expect(BirdV1SourceSet.flutterOffsets, hasLength(BirdV1SourceSet.cycle.length));
  });

  testWidgets('Bird V1 source cels are registered app assets', (tester) async {
    for (final asset in BirdV1SourceSet.assets) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: asset);
    }
  });
}
