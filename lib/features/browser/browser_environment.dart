import 'dart:async';
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Keep each account's browser process for the app session. Disposing it when
/// a page closes would discard session cookies between two campus websites.
final browserEnvironmentProvider =
    FutureProvider.family<WebViewEnvironment, String>((ref, profileName) async {
      var disposed = false;
      WebViewEnvironment? environment;
      ref.onDispose(() {
        disposed = true;
        final value = environment;
        if (value != null) unawaited(value.dispose().catchError((Object _) {}));
      });
      final directory = await getApplicationSupportDirectory();
      final profile = Directory('${directory.path}/web_profiles/$profileName');
      await profile.create(recursive: true);
      final value = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: profile.path),
      );
      if (disposed) {
        await value.dispose();
        throw StateError('Browser profile was disposed');
      }
      environment = value;
      return value;
    });
