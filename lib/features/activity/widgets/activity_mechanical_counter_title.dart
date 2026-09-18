import 'package:flutter/material.dart';

/// A compact mechanical totalizer used as the shared Activity AppBar title.
///
/// The motion is intentionally limited to a one-shot, deterministic index on
/// insertion. It has no relationship to Activity state or record data.
class ActivityMechanicalCounterTitle extends StatefulWidget {
  const ActivityMechanicalCounterTitle({super.key});

  static const word = 'ACTIVITY';
  static const width = 136.0;
  static const height = 34.0;
  static const cellCount = word.length;
  static const indexDuration = Duration(milliseconds: 620);

  @override
  State<ActivityMechanicalCounterTitle> createState() =>
      _ActivityMechanicalCounterTitleState();
}

class _ActivityMechanicalCounterTitleState
    extends State<ActivityMechanicalCounterTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _motionEnabled = true;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ActivityMechanicalCounterTitle.indexDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      _motionEnabled = false;
      _controller.value = 1;
      return;
    }
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _motionEnabled) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: ActivityMechanicalCounterTitle.word,
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey('activity-mechanical-counter-title'),
          width: ActivityMechanicalCounterTitle.width,
          height: ActivityMechanicalCounterTitle.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF111315),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF596066), width: .8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < ActivityMechanicalCounterTitle.cellCount;
                    index++
                  )
                    Expanded(
                      child: _MechanicalCounterCell(
                        key: ValueKey('activity-counter-cell-$index'),
                        character: ActivityMechanicalCounterTitle.word[index],
                        index: index,
                        animation: _controller,
                        animate: _motionEnabled,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MechanicalCounterCell extends StatelessWidget {
  const _MechanicalCounterCell({
    super.key,
    required this.character,
    required this.index,
    required this.animation,
    required this.animate,
  });

  final String character;
  final int index;
  final Animation<double> animation;
  final bool animate;

  String get _previousCharacter {
    final code = character.codeUnitAt(0);
    return String.fromCharCode(code == 65 ? 90 : code - 1);
  }

  double _progress() {
    if (!animate) return 1;
    final start = .04 + index * .055;
    return Curves.easeOutCubic.transform(
      ((animation.value - start) / .52).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFFF0EEE4),
      fontFamily: 'ShareTechMono',
      fontSize: 19,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -.4,
      shadows: [Shadow(color: Color(0x33000000), offset: Offset(0, 1))],
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = _progress();
        final indexing = animate && progress < 1;
        return Container(
          key: ValueKey('activity-counter-window-$index'),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF171A1C), Color(0xFF282C2E), Color(0xFF151719)],
              stops: [0, .5, 1],
            ),
            border: Border(
              right: index == ActivityMechanicalCounterTitle.cellCount - 1
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xFF4A5054), width: .55),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final travel = constraints.maxHeight * .72;
              return Stack(
                fit: StackFit.expand,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      height: .7,
                      child: ColoredBox(color: Color(0x77464B4E)),
                    ),
                  ),
                  if (indexing)
                    Transform.translate(
                      key: ValueKey('activity-counter-indexing-$index'),
                      offset: Offset(0, -travel * progress),
                      child: Center(
                        child: Text(_previousCharacter, style: textStyle),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(0, travel * (1 - progress)),
                    child: Center(
                      child: Text(
                        character,
                        key: ValueKey('activity-counter-character-$index'),
                        style: textStyle,
                      ),
                    ),
                  ),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x33757B7D), width: .6),
                          bottom: BorderSide(
                            color: Color(0x99000000),
                            width: .8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
