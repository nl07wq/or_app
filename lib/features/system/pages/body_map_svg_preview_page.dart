import 'package:flutter/material.dart';

import '../../training/services/training_history_domain_service.dart';
import '../../training/widgets/body_map_svg_prototype.dart';

class BodyMapSvgPreviewPage extends StatefulWidget {
  const BodyMapSvgPreviewPage({super.key});
  @override
  State<BodyMapSvgPreviewPage> createState() => _BodyMapSvgPreviewPageState();
}

class _BodyMapSvgPreviewPageState extends State<BodyMapSvgPreviewPage> {
  SvgBodyMapSide side = SvgBodyMapSide.front;
  MuscleGroup? selected;
  bool support = false;
  RecoveryStatus? recoveryStatus;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BODY MAP SVG PREVIEW')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<SvgBodyMapSide>(
                segments: const [
                  ButtonSegment(value: SvgBodyMapSide.front, label: Text('前面')),
                  ButtonSegment(value: SvgBodyMapSide.back, label: Text('背面')),
                ],
                selected: {side},
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  setState(() {
                    side = value.first;
                    selected = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              SvgBodyMapPrototype(
                side: side,
                recoveryByMuscle: const {},
                previewStatuses: recoveryStatus == null
                    ? const {}
                    : {MuscleGroup.shoulders: recoveryStatus!},
                supportMuscles: support ? {MuscleGroup.shoulders} : const {},
                selectedMuscle: selected,
                onSelected: (muscle) => setState(() => selected = muscle),
              ),
              const SizedBox(height: 12),
              Text(
                selected == null
                    ? 'TAP A MUSCLE REGION'
                    : 'SELECTED: ${selected!.name.toUpperCase()}',
              ),
              SwitchListTile(
                title: const Text('SUPPORT OUTLINE PREVIEW'),
                value: support,
                onChanged: (value) => setState(() => support = value),
              ),
              DropdownButtonFormField<RecoveryStatus>(
                key: ValueKey(
                  'body-map-recovery-fixture-${recoveryStatus?.name ?? 'neutral'}',
                ),
                initialValue: recoveryStatus,
                decoration: const InputDecoration(
                  labelText: 'RECOVERY FILL PREVIEW',
                ),
                items: const [
                  DropdownMenuItem<RecoveryStatus>(
                    value: RecoveryStatus.recovering,
                    child: Text('回復中'),
                  ),
                  DropdownMenuItem<RecoveryStatus>(
                    value: RecoveryStatus.nearReady,
                    child: Text('回復目安に接近'),
                  ),
                  DropdownMenuItem<RecoveryStatus>(
                    value: RecoveryStatus.estimatedReady,
                    child: Text('回復目安到達'),
                  ),
                ],
                onChanged: (value) => setState(() => recoveryStatus = value),
              ),
              TextButton(
                onPressed: () => setState(() => recoveryStatus = null),
                child: const Text('NEUTRAL / データなし'),
              ),
              const Text(
                'Prototype only — production Recovery Body Map is unchanged.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
