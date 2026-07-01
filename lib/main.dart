import 'package:flutter/material.dart';

import 'app.dart';
import 'core/repositories/morning_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MorningRepository.load();

  runApp(const OperationRebootApp());
}
