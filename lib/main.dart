import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlatformHooks.initOptional();
  runApp(const ProviderScope(child: XmuRollcallApp()));
}
