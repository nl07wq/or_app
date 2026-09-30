import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

/// Sandbox-only source authority. The PNG cels are user supplied, untouched,
/// transparent-black silhouettes. No generated or interpolated pose exists.
abstract final class BirdV1SourceSet {
  static const assets = <String>[
    'assets/animations/sandbox/bird_v1/frame_01.png',
    'assets/animations/sandbox/bird_v1/frame_02.png',
    'assets/animations/sandbox/bird_v1/frame_03.png',
    'assets/animations/sandbox/bird_v1/frame_04.png',
    'assets/animations/sandbox/bird_v1/frame_05.png',
    'assets/animations/sandbox/bird_v1/frame_06.png',
  ];

  /// The approved six-cel forward loop: 01 → 02 → 03 → 04 → 05 → 06.
  static const cycle = <int>[0, 1, 2, 3, 4, 5];
  /// Ends at the same baseline at the 06 → 01 seam.
  static const bobOffsets = <double>[0, -1, -2, -2, -1, 0];
  static const flutterOffsets = <double>[0, -1, 1, -1, 1, 0];
}

class BirdV1Sandbox extends StatefulWidget {
  const BirdV1Sandbox({super.key});

  @override
  State<BirdV1Sandbox> createState() => _BirdV1SandboxState();
}

class _BirdV1SandboxState extends State<BirdV1Sandbox> {
  Timer? _timer;
  var _sourceExpanded = false;
  var _cycleExpanded = false;
  var _frame = 0;
  var _cycle = 0;
  var _playing = false;

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _play() {
    _timer?.cancel();
    setState(() => _playing = true);
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() { _cycle = (_cycle + 1) % BirdV1SourceSet.cycle.length; _frame = BirdV1SourceSet.cycle[_cycle]; });
    });
  }

  void _pause() { _timer?.cancel(); setState(() => _playing = false); }

  Widget _frameButtons(String prefix) => Wrap(
    spacing: 8, runSpacing: 8,
    children: [for (var i = 0; i < 6; i++) OutlinedButton(
      key: ValueKey('$prefix-${i + 1}'),
      onPressed: () { _pause(); setState(() => _frame = i); },
      child: Text('FRAME ${(i + 1).toString().padLeft(2, '0')}'),
    )],
  );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _BirdDisclosure('bird-v1-source-disclosure', Icons.document_scanner_outlined, 'BIRD V1 — NEW 6-POSE SOURCE SET', _sourceExpanded, () => setState(() => _sourceExpanded = !_sourceExpanded)),
    if (_sourceExpanded) ...[AppSpacing.gapSM, OperationCard(key: const ValueKey('bird-v1-source-audit'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('FRAME ${(_frame + 1).toString().padLeft(2, '0')} · USER-SUPPLIED TRANSPARENT BLACK SILHOUETTE'),
      AppSpacing.gapSM, BirdV1Frame(frame: _frame, leftToRight: true, height: 210), AppSpacing.gapSM, _frameButtons('bird-v1-source-frame'),
      const Text('SIX ORIGINAL PNG CELS · SAME FIXED RUNTIME RECT · NO POSE INTERPOLATION'),
    ]))],
    AppSpacing.gapLG,
    _BirdDisclosure('bird-v1-cycle-disclosure', Icons.motion_photos_on_outlined, 'BIRD V1 BODY-REGISTERED FLAP CYCLE', _cycleExpanded, () => setState(() => _cycleExpanded = !_cycleExpanded)),
    if (_cycleExpanded) ...[AppSpacing.gapSM, OperationCard(key: const ValueKey('bird-v1-flap-cycle'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(_playing ? 'PLAYING · 80ms / POSE' : 'PAUSED · 80ms / POSE'),
      BirdV1Frame(frame: _frame, leftToRight: true, height: 170, bob: BirdV1SourceSet.bobOffsets[_cycle]),
      Wrap(spacing: 8, children: [OutlinedButton(key: const ValueKey('bird-v1-play'), onPressed: _play, child: const Text('PLAY')), OutlinedButton(onPressed: _pause, child: const Text('PAUSE')), OutlinedButton(key: const ValueKey('bird-v1-restart'), onPressed: () { _pause(); setState(() { _frame = 0; _cycle = 0; }); _play(); }, child: const Text('RESTART'))]),
      AppSpacing.gapSM, _frameButtons('bird-v1-cycle-frame'),
      const Text('01 → 02 → 03 → 04 → 05 → 06 → 01 → LOOP · fixed body rect registration.'),
    ]))],
  ]);
}

class _BirdDisclosure extends StatelessWidget {
  const _BirdDisclosure(this.keyName, this.icon, this.title, this.expanded, this.onTap);
  final String keyName; final IconData icon; final String title; final bool expanded; final VoidCallback onTap;
  @override Widget build(BuildContext context) => OperationCard(child: InkWell(key: ValueKey(keyName), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Text(title)), Icon(expanded ? Icons.expand_less : Icons.expand_more)]))));
}

class BirdV1Frame extends StatelessWidget {
  const BirdV1Frame({super.key, required this.frame, required this.leftToRight, required this.height, this.bob = 0});
  final int frame; final bool leftToRight; final double height; final double bob;
  @override Widget build(BuildContext context) => SizedBox(height: height, child: Center(child: Transform.translate(offset: Offset(0, bob), child: Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(leftToRight ? 1 : -1, 1, 1), child: ColorFiltered(colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.onSurface.withValues(alpha: .82), BlendMode.srcIn), child: Image.asset(BirdV1SourceSet.assets[frame], key: ValueKey('bird-v1-cel-${frame + 1}'), height: height, fit: BoxFit.contain, filterQuality: FilterQuality.high))))));
}

class BirdV1ProductionPreview extends StatefulWidget { const BirdV1ProductionPreview({super.key}); @override State<BirdV1ProductionPreview> createState() => _BirdV1ProductionPreviewState(); }
class _BirdV1ProductionPreviewState extends State<BirdV1ProductionPreview> {
  Timer? _ticker; var _cycle = 0; var _elapsed = 0; var _playing = false; var _flutter = true; var _ltr = true; var _speed = '1×'; var _count = 1;
  int get _duration => _speed == '0.5×' ? 4400 : 2200;
  @override void dispose() { _ticker?.cancel(); super.dispose(); }
  void _play() { _ticker?.cancel(); setState(() { _playing = true; _elapsed = 0; _cycle = 0; }); _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) { if (!mounted) return; setState(() { _elapsed += 40; _cycle = (_cycle + 1) % BirdV1SourceSet.cycle.length; if (_elapsed >= _duration) { _elapsed = 0; } }); }); }
  Widget _option(String id, String label, bool selected, VoidCallback action) => OutlinedButton(key: ValueKey(id), style: selected ? OutlinedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primaryContainer) : null, onPressed: action, child: Text(label));
  @override Widget build(BuildContext context) { final frame = BirdV1SourceSet.cycle[_cycle]; final bob = BirdV1SourceSet.bobOffsets[_cycle]; final flutter = _flutter ? BirdV1SourceSet.flutterOffsets[_cycle] : 0.0; return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const SectionHeader(icon: Icons.flight_outlined, title: 'BIRD FLIGHT — PRODUCTION PREVIEW V1'), AppSpacing.gapSM,
    OperationCard(key: const ValueKey('bird-v1-production-preview'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('FRAME ${(frame + 1).toString().padLeft(2, '0')} · FLAP BOB ${bob.toStringAsFixed(0)}px · FLUTTER ${_flutter ? 'ON' : 'OFF'} · $_speed · ×$_count · ${_ltr ? 'L→R' : 'R→L'}'),
      SizedBox(height: 112, child: LayoutBuilder(builder: (context, c) => ClipRect(child: Stack(children: [for (var i = 0; i < _count; i++) Positioned(left: _birdLeft(c.maxWidth, i), top: 24 + bob + flutter + (i * 10), width: 56, height: 56, child: BirdV1Frame(frame: (frame + i) % 6, leftToRight: _ltr, height: 56))])))),
      Wrap(spacing: 8, runSpacing: 8, children: [_option('bird-v1-production-play-restart','PLAY / RESTART',_playing,_play), _option('bird-v1-production-flutter-off','FLUTTER OFF',!_flutter,()=>setState(()=>_flutter=false)), _option('bird-v1-production-flutter-on','FLUTTER ON',_flutter,()=>setState(()=>_flutter=true))]),
      AppSpacing.gapSM, Wrap(spacing: 8, runSpacing: 8, children: [_option('bird-v1-production-ltr','L→R',_ltr,()=>setState(()=>_ltr=true)), _option('bird-v1-production-rtl','R→L',!_ltr,()=>setState(()=>_ltr=false)), _option('bird-v1-production-speed-1x','1×',_speed=='1×',()=>setState(()=>_speed='1×')), _option('bird-v1-production-speed-half','0.5×',_speed=='0.5×',()=>setState(()=>_speed='0.5×')), for(final count in [1,2,3]) _option('bird-v1-production-count-$count','×$count',_count==count,()=>setState(()=>_count=count))]),
      const Text('Sandbox-only preview · body-registered source cels · flap-synchronous bob · no Ambient production wiring.'),
    ])),
  ]); }
  double _birdLeft(double width, int instance) { final p = (_elapsed - instance * 160).clamp(0, _duration) / _duration; final start = -60.0; final end = width + 4; final x = start + (end - start) * p; return _ltr ? x : width - 56 - x; }
}
