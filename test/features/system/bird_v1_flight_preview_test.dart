import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/bird_v1_flight_preview.dart';

void main() {
  test('Bird V1 retains six supplied source cels and a reverse flap loop', () {
    expect(BirdV1SourceSet.assets, hasLength(6));
    expect(BirdV1SourceSet.cycle, const [0, 1, 2, 3, 4, 5, 4, 3, 2, 1]);
    expect(BirdV1SourceSet.bobOffsets, hasLength(BirdV1SourceSet.cycle.length));
    expect(BirdV1SourceSet.flutterOffsets, hasLength(BirdV1SourceSet.cycle.length));
  });
}
