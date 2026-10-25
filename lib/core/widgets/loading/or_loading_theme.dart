import 'package:flutter/widgets.dart';
import 'or_loading_tokens.dart';

@immutable
class OrLoadingThemeData {
  final OrLoadingTokens tokens;
  const OrLoadingThemeData({this.tokens = const OrLoadingTokens()});
  OrLoadingThemeData copyWith({OrLoadingTokens? tokens}) =>
      OrLoadingThemeData(tokens: tokens ?? this.tokens);
}

class OrLoadingTheme extends InheritedWidget {
  final OrLoadingThemeData data;
  const OrLoadingTheme({super.key, required this.data, required super.child});
  static OrLoadingThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OrLoadingTheme>()?.data ??
      const OrLoadingThemeData();
  @override
  bool updateShouldNotify(OrLoadingTheme oldWidget) => data != oldWidget.data;
}
