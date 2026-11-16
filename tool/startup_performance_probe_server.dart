import 'dart:io';

Future<void> main(List<String> arguments) async {
  final port = arguments.isEmpty ? 8775 : int.parse(arguments.first);
  final release = arguments.length < 2 ? 'startup-performance-probe' : arguments[1];
  final root = Directory(
    arguments.length < 3 ? 'build/web' : arguments[2],
  ).absolute;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Startup probe: http://127.0.0.1:$port/or_app/');
  await for (final request in server) {
    var relative = request.uri.path;
    if (relative.startsWith('/or_app/')) {
      relative = relative.substring('/or_app/'.length);
    } else if (relative == '/or_app') {
      relative = '';
    }
    relative = relative.isEmpty ? 'index.html' : relative;
    final file = File('${root.path}${Platform.pathSeparator}$relative').absolute;
    if (!file.path.startsWith(root.path) || !await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }
    request.response.headers
      ..contentType = _contentType(relative)
      ..set(
        HttpHeaders.cacheControlHeader,
        relative == 'index.html' || relative == 'flutter_bootstrap.js'
            ? 'no-store'
            : 'public, max-age=3600',
      );
    if (relative == 'index.html' || relative == 'flutter_bootstrap.js') {
      var contents = await file.readAsString();
      if (relative == 'index.html') {
        contents = contents.replaceAll('__OR_APP_RELEASE__', release);
      } else {
        contents = contents.replaceAll(
          'main.dart.js',
          'main.dart.js?or_app_release=$release',
        );
      }
      request.response.write(contents);
    } else {
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  }
}

ContentType _contentType(String path) {
  if (path.endsWith('.html')) return ContentType.html;
  if (path.endsWith('.js') || path.endsWith('.mjs')) {
    return ContentType('application', 'javascript', charset: 'utf-8');
  }
  if (path.endsWith('.wasm')) return ContentType('application', 'wasm');
  if (path.endsWith('.json')) return ContentType.json;
  if (path.endsWith('.png')) return ContentType('image', 'png');
  if (path.endsWith('.webp')) return ContentType('image', 'webp');
  if (path.endsWith('.ttf') || path.endsWith('.otf')) {
    return ContentType('font', path.endsWith('.ttf') ? 'ttf' : 'otf');
  }
  return ContentType.binary;
}
