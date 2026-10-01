// lib/easy_liboqs.dart
import 'dart:io' show Platform;

import 'package:oqs/oqs.dart';

import 'src/probe.dart';

export 'package:oqs/oqs.dart';
export 'src/probe.dart' show bundledLiboqsPath, bundledLiboqsVersion;

/// Setup helper: makes sure the bundled liboqs is available and that `oqs`
/// uses exactly that file, then initializes `oqs`.
class EasyLiboqs {
  EasyLiboqs._();

  static bool _initialized = false;

  static void init() {
    if (_initialized) return;

    // Throws if the bundled native library was not resolved.
    bundledLiboqsVersion();

    // Point oqs at the very same file (cached by LibOQSLoader), so it never
    // falls back to searching system paths.
    if (!Platform.isWindows) {
      LibOQSLoader.loadLibrary(explicitPath: bundledLiboqsPath());
    }
    // TODO: Windows path lookup (see probe.dart).

    LibOQS.init();
    _initialized = true;
  }
}