// Deterministically bakes the Product Owner's final Geometry Tuner feedback.
// Shell commands only invoke this tool; all geometry math lives in Dart.
import 'dart:io';
import 'dart:math' as math;

const _baseline = '58bf285';
const _svgRoot = 'assets/body_map';
const _number = r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?';
final _tokens = RegExp('[A-Za-z]|$_number');

class GeometrySpec {
  const GeometrySpec(
    this.x,
    this.y,
    this.width,
    this.height, {
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotationDeg = 0,
  });
  final double x, y, width, height, scaleX, scaleY, rotationDeg;
}

String _format(double value) => value
    .toStringAsFixed(8)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

// CURRENT uses the same bounds-centre resize/scale/rotation convention as Tuner.
String _transformCurrent(String d, GeometrySpec spec) {
  final tokens = _tokens.allMatches(d).map((m) => m.group(0)!).toList();
  final values = <double>[];
  for (final token in tokens) {
    final value = double.tryParse(token);
    if (value != null) values.add(value);
  }
  if (values.isEmpty || values.length.isOdd) {
    throw StateError('Invalid CURRENT path');
  }
  final xs = <double>[], ys = <double>[];
  for (var i = 0; i < values.length; i += 2) {
    xs.add(values[i]);
    ys.add(values[i + 1]);
  }
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  final baseWidth = maxX - minX, baseHeight = maxY - minY;
  if (baseWidth <= 0 || baseHeight <= 0) {
    throw StateError('Zero CURRENT bounds');
  }
  final centerX = (minX + maxX) / 2, centerY = (minY + maxY) / 2;
  final scaleX = spec.width / baseWidth * spec.scaleX;
  final scaleY = spec.height / baseHeight * spec.scaleY;
  final radians = spec.rotationDeg * math.pi / 180;
  final cosine = math.cos(radians), sine = math.sin(radians);
  var index = 0;
  final result = StringBuffer();
  while (index < tokens.length) {
    final command = tokens[index++];
    final count = switch (command) {
      'M' || 'L' => 2,
      'C' => 6,
      'Z' => 0,
      _ => throw StateError('Unsupported SVG command $command'),
    };
    result.write(command);
    for (var coordinate = 0; coordinate < count; coordinate += 2) {
      final x = double.parse(tokens[index++]),
          y = double.parse(tokens[index++]);
      final dx = x - centerX, dy = y - centerY;
      result.write(
        ' ${_format(spec.x + scaleX * cosine * dx - scaleY * sine * dy)}'
        ' ${_format(spec.y + scaleX * sine * dx + scaleY * cosine * dy)}',
      );
    }
    result.write(' ');
  }
  return result.toString().trim();
}

String _ellipse(GeometrySpec spec) {
  final radiusX = spec.width * spec.scaleX / 2,
      radiusY = spec.height * spec.scaleY / 2;
  const kappa = .5522847498;
  final radians = spec.rotationDeg * math.pi / 180;
  final cosine = math.cos(radians), sine = math.sin(radians);
  String point(double x, double y) =>
      '${_format(spec.x + x * cosine - y * sine)} ${_format(spec.y + x * sine + y * cosine)}';
  return 'M ${point(0, -radiusY)} C ${point(kappa * radiusX, -radiusY)} '
      '${point(radiusX, -kappa * radiusY)} ${point(radiusX, 0)} '
      'C ${point(radiusX, kappa * radiusY)} ${point(kappa * radiusX, radiusY)} ${point(0, radiusY)} '
      'C ${point(-kappa * radiusX, radiusY)} ${point(-radiusX, kappa * radiusY)} ${point(-radiusX, 0)} '
      'C ${point(-radiusX, -kappa * radiusY)} ${point(-kappa * radiusX, -radiusY)} ${point(0, -radiusY)} Z';
}

// ROUNDED_RECT uses Tuner's implicit 20% radius when cornerRadius is zero.
String _roundedRect(GeometrySpec spec) {
  final width = spec.width * spec.scaleX, height = spec.height * spec.scaleY;
  final radius = math.min(width, height) * .2, control = radius * .5522847498;
  final left = spec.x - width / 2, right = spec.x + width / 2;
  final top = spec.y - height / 2, bottom = spec.y + height / 2;
  return 'M ${_format(left + radius)} ${_format(top)} L ${_format(right - radius)} ${_format(top)} '
      'C ${_format(right - radius + control)} ${_format(top)} ${_format(right)} ${_format(top + radius - control)} ${_format(right)} ${_format(top + radius)} '
      'L ${_format(right)} ${_format(bottom - radius)} C ${_format(right)} ${_format(bottom - radius + control)} ${_format(right - radius + control)} ${_format(bottom)} ${_format(right - radius)} ${_format(bottom)} '
      'L ${_format(left + radius)} ${_format(bottom)} C ${_format(left + radius - control)} ${_format(bottom)} ${_format(left)} ${_format(bottom - radius + control)} ${_format(left)} ${_format(bottom - radius)} '
      'L ${_format(left)} ${_format(top + radius)} C ${_format(left)} ${_format(top + radius - control)} ${_format(left + radius - control)} ${_format(top)} ${_format(left + radius)} ${_format(top)} Z';
}

Map<String, String> _paths(String svg) => {
  for (final match in RegExp(r'<path id="([^"]+)" d="([^"]+)"').allMatches(svg))
    match.group(1)!: match.group(2)!,
};

String _baselineSvg(String side) {
  final result = Process.runSync('git', [
    'show',
    '$_baseline:$_svgRoot/body_map_$side.svg',
  ]);
  if (result.exitCode != 0) {
    throw StateError('Cannot read $_baseline $side SVG: ${result.stderr}');
  }
  return result.stdout as String;
}

final _frontCurrent = <String, GeometrySpec>{
  'front-chest-left': const GeometrySpec(86.5, 99.5, 25, 35.1),
  'front-chest-right': const GeometrySpec(113.5, 99.5, 25, 35.1),
  'front-core': const GeometrySpec(100, 149, 40, 53),
  'front-biceps-left': const GeometrySpec(
    62.5,
    114,
    16.58,
    33.58,
    rotationDeg: -5,
  ),
  'front-biceps-right': const GeometrySpec(
    137.5,
    114,
    16.58,
    33.58,
    rotationDeg: 5,
  ),
  'front-forearm-left': const GeometrySpec(57, 155, 12.89, 45.11),
  'front-forearm-right': const GeometrySpec(143, 155, 12.89, 45.11),
  'front-quadriceps-left': const GeometrySpec(83.5, 217.49, 20.55, 63.72),
  'front-quadriceps-right': const GeometrySpec(116.5, 217.49, 20.55, 63.72),
};
final _backCurrent = <String, GeometrySpec>{
  'back-lats-left': const GeometrySpec(85.98, 116, 27.04, 67),
  'back-lats-right': const GeometrySpec(114.02, 116, 27.04, 67),
  'back-triceps-left': const GeometrySpec(
    62.5,
    114,
    16.63,
    33.08,
    rotationDeg: -5,
  ),
  'back-triceps-right': const GeometrySpec(
    137.5,
    114,
    16.63,
    33.08,
    rotationDeg: 5,
  ),
  'back-forearm-left': const GeometrySpec(57, 155, 12.89, 45.11),
  'back-forearm-right': const GeometrySpec(143, 155, 12.89, 45.11),
  'back-glutes-left': const GeometrySpec(86, 169.5, 24.5, 34.5),
  'back-glutes-right': const GeometrySpec(114, 169.5, 24.5, 34.5),
  'back-hamstrings-left': const GeometrySpec(83.5, 218.5, 20, 55),
  'back-hamstrings-right': const GeometrySpec(116.5, 218.5, 20, 55),
  'back-calves-left': const GeometrySpec(83, 275, 18, 51.5),
  'back-calves-right': const GeometrySpec(117, 275, 18, 51.5),
};
final _frontEllipses = <String, GeometrySpec>{
  'front-shoulder-left': const GeometrySpec(
    70.5,
    85,
    11.4,
    18.44,
    scaleX: .75,
    rotationDeg: 28,
  ),
  'front-shoulder-right': const GeometrySpec(
    129.5,
    85,
    11.4,
    18.44,
    scaleX: .75,
    rotationDeg: -28,
  ),
};
final _backEllipses = <String, GeometrySpec>{
  'back-shoulder-left': const GeometrySpec(
    70.5,
    85,
    11.4,
    18.44,
    scaleX: .75,
    rotationDeg: 28,
  ),
  'back-shoulder-right': const GeometrySpec(
    129.5,
    85,
    11.4,
    18.44,
    scaleX: .75,
    rotationDeg: -28,
  ),
};

String _replacePath(String svg, String oldD, String newD, String id) {
  if (!svg.contains(oldD)) throw StateError('Unable to replace $id');
  return svg.replaceFirst(oldD, newD);
}

String _bake(String side) {
  var svg = _baselineSvg(side);
  final baselinePaths = _paths(svg);
  final current = side == 'front' ? _frontCurrent : _backCurrent;
  final ellipses = side == 'front' ? _frontEllipses : _backEllipses;
  for (final entry in current.entries) {
    final base = baselinePaths[entry.key];
    if (base == null) throw StateError('Missing stable ID ${entry.key}');
    svg = _replacePath(
      svg,
      base,
      _transformCurrent(base, entry.value),
      entry.key,
    );
  }
  for (final entry in ellipses.entries) {
    final base = baselinePaths[entry.key];
    if (base == null) throw StateError('Missing stable ID ${entry.key}');
    svg = _replacePath(svg, base, _ellipse(entry.value), entry.key);
  }
  if (side == 'back') {
    final base = baselinePaths['back-trapezius'];
    if (base == null) throw StateError('Missing stable ID back-trapezius');
    const lower = GeometrySpec(100, 77, 35, 29.5, scaleX: 1.4);
    const upper = GeometrySpec(100, 72.5, 18, 13.55, scaleX: 1.01, scaleY: 1.5);
    // Tuner's deterministic compound-path fallback: one stable semantic Path.
    svg = _replacePath(
      svg,
      base,
      '${_roundedRect(upper)} ${_transformCurrent(base, lower)}',
      'back-trapezius',
    );
  }
  return svg;
}

void _validate(String side, String svg) {
  final parsed = _paths(svg);
  final required = side == 'front'
      ? {..._frontCurrent.keys, ..._frontEllipses.keys, 'front-body'}
      : {
          ..._backCurrent.keys,
          ..._backEllipses.keys,
          'back-body',
          'back-trapezius',
        };
  for (final id in required) {
    final d = parsed[id];
    if (d == null || d.isEmpty || d.contains('NaN') || d.contains('Infinity')) {
      throw StateError('Invalid final path $id');
    }
  }
}

void _writeValidated(String side, String svg) {
  final target = File('$_svgRoot/body_map_$side.svg');
  final temporary = File('${target.path}.bake.tmp');
  temporary.writeAsStringSync(svg);
  _validate(side, temporary.readAsStringSync());
  temporary.copySync(target.path);
  temporary.deleteSync();
}

void main(List<String> arguments) {
  final write = arguments.contains('--write');
  final verify = arguments.contains('--verify');
  final front = _bake('front'), back = _bake('back');
  _validate('front', front);
  _validate('back', back);
  stdout.writeln(
    'dry-run: baseline $_baseline; front 11 regions; back 15 regions; composite trapezius valid',
  );
  if (verify) {
    for (final side in ['front', 'back']) {
      final expected = side == 'front' ? front : back;
      final actual = File('$_svgRoot/body_map_$side.svg').readAsStringSync();
      if (actual != expected) {
        throw StateError(
          '$side canonical SVG is not equivalent to $_baseline + final feedback',
        );
      }
    }
    stdout.writeln(
      'equivalence: canonical SVGs exactly match baseline + final feedback',
    );
  }
  if (!write) return;
  _writeValidated('front', front);
  _writeValidated('back', back);
  stdout.writeln('wrote validated canonical Front and Back SVGs');
}
