import 'dart:io';

Future<void> main(List<String> arguments) async {
  final port = arguments.isEmpty ? 8766 : int.parse(arguments.first);
  final release = arguments.length < 2 ? 'uri-evidence-e2e' : arguments[1];
  final root = Directory('build/web').absolute;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('URI evidence probe server: http://127.0.0.1:$port/or_app/');
  await for (final request in server) {
    var relative = request.uri.path;
    if (relative.startsWith('/or_app/')) {
      relative = relative.substring('/or_app/'.length);
    } else if (relative == '/or_app') {
      relative = '';
    }
    relative = relative.isEmpty ? 'index.html' : relative;
    final candidate = File('${root.path}${Platform.pathSeparator}$relative');
    final resolved = candidate.absolute.path;
    if (!resolved.startsWith(root.path) || !await candidate.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }
    request.response.headers
      ..contentType = _contentType(relative)
      ..set(HttpHeaders.cacheControlHeader, 'no-store');
    if (relative == 'index.html' || relative == 'flutter_bootstrap.js') {
      var contents = await candidate.readAsString();
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
      await request.response.addStream(candidate.openRead());
    }
    await request.response.close();
  }
}

ContentType _contentType(String path) {
  if (path.endsWith('.html')) return ContentType.html;
  if (path.endsWith('.js') || path.endsWith('.mjs')) {
    return ContentType('application', 'javascript', charset: 'utf-8');
  }
  if (path.endsWith('.json')) return ContentType.json;
  if (path.endsWith('.css')) {
    return ContentType('text', 'css', charset: 'utf-8');
  }
  if (path.endsWith('.wasm')) return ContentType('application', 'wasm');
  if (path.endsWith('.png')) return ContentType('image', 'png');
  if (path.endsWith('.webp')) return ContentType('image', 'webp');
  return ContentType.binary;
}
