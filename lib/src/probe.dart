// lib/src/probe.dart
//
// Tiny @Native binding whose asset id (package:easy_liboqs/src/probe.dart)
// matches the CodeAsset name in hook/build.dart. Calling it proves the
// bundled liboqs was built into the app; dladdr on its address tells us
// which file on disk it came from, so `oqs` can be pointed at the same file.
import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

@Native<Pointer<Utf8> Function()>(symbol: 'OQS_version')
external Pointer<Utf8> _oqsVersion();

/// Version string reported by the bundled liboqs, e.g. "0.16.0".
String bundledLiboqsVersion() => _oqsVersion().toDartString();

// struct Dl_info { const char* dli_fname; void* dli_fbase;
//                  const char* dli_sname; void* dli_saddr; };
final class _DlInfo extends Struct {
  external Pointer<Utf8> fname;
  external Pointer<Void> fbase;
  external Pointer<Utf8> sname;
  external Pointer<Void> saddr;
}

typedef _DladdrNative = Int Function(Pointer<Void>, Pointer<_DlInfo>);
typedef _DladdrDart = int Function(Pointer<Void>, Pointer<_DlInfo>);

/// Absolute path of the bundled liboqs file that the @Native binding resolved
/// to. Linux, macOS, Android and iOS use dladdr. Windows is not done yet.
String bundledLiboqsPath() {
  if (Platform.isWindows) {
    // TODO: GetModuleHandleExW(FROM_ADDRESS | UNCHANGED_REFCOUNT, addr, &h)
    // then GetModuleFileNameW(h, ...) via dart:ffi.
    throw UnsupportedError('bundledLiboqsPath() is not implemented on Windows');
  }

  final address =
      Native.addressOf<NativeFunction<Pointer<Utf8> Function()>>(_oqsVersion);
  final dladdr = DynamicLibrary.process()
      .lookupFunction<_DladdrNative, _DladdrDart>('dladdr');

  final info = calloc<_DlInfo>();
  try {
    if (dladdr(address.cast(), info) == 0 || info.ref.fname == nullptr) {
      throw StateError('dladdr could not locate the bundled liboqs');
    }
    return info.ref.fname.toDartString();
  } finally {
    calloc.free(info);
  }
}