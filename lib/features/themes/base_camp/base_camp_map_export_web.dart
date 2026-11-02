// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

void exportBaseCampMapJson(String json) {
  final blob = html.Blob(<Object>[json], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = 'base-camp-map-v1.json'
    ..click();
  html.Url.revokeObjectUrl(url);
}
