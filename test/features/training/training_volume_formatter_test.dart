import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/services/training_volume_formatter.dart';

void main() {
  test('formats kg below one tonne and tonnes at or above one tonne', () {
    expect(TrainingVolumeFormatter.format(0), '0 kg');
    expect(TrainingVolumeFormatter.format(450), '450 kg');
    expect(TrainingVolumeFormatter.format(950), '950 kg');
    expect(TrainingVolumeFormatter.format(1000), '1 t');
    expect(TrainingVolumeFormatter.format(1250), '1.25 t');
    expect(TrainingVolumeFormatter.format(10000), '10 t');
    expect(TrainingVolumeFormatter.format(11554.4), '11.6 t');
    expect(TrainingVolumeFormatter.format(56162.5), '56.2 t');
  });

  test('uses compact non-wrapping axis labels', () {
    expect(TrainingVolumeFormatter.axisLabel(0), '0kg');
    expect(TrainingVolumeFormatter.axisLabel(5777.2), '5.8t');
    expect(TrainingVolumeFormatter.axisLabel(11554.4), '11.6t');
    expect(TrainingVolumeFormatter.axisLabel(17331.7), '17.3t');
  });
}
