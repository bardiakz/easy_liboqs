# easy_liboqs

Post-quantum cryptography ([liboqs](https://openquantumsafe.org/)) for Dart and Flutter, with the native library bundled automatically. It wraps [`oqs`](https://pub.dev/packages/oqs) and re-exports its API, so there are no library paths or per-platform setup steps.

## Install

```bash
dart pub add easy_liboqs      # or: flutter pub add easy_liboqs
```

## Use

```dart
import 'package:easy_liboqs/easy_liboqs.dart';

void main() {
  EasyLiboqs.init();

  final kem = KEM.create('ML-KEM-768')!;
  final keys = kem.generateKeyPair();
  final enc = kem.encapsulate(keys.publicKey);
  final secret = kem.decapsulate(enc.ciphertext, keys.secretKey);
  // secret == enc.sharedSecret

  keys.dispose();
  kem.dispose();
}
```

Everything from `oqs` (KEM, signatures, algorithm discovery) is available through this one import. See the [`oqs` docs](https://pub.dev/packages/oqs) for the full API.

## Platforms

| Platform | Status |
|---|---|
| Linux x64, arm64 | supported |
| macOS arm64, x64 | supported |
| Windows x64 | supported |
| Android | supported (CI-tested on x86_64 only) |
| iOS | not yet |
| Web | not supported |

## How it works

A [build hook](https://dart.dev/tools/hooks) downloads the prebuilt liboqs archive from [`liboqs-binaries`](https://github.com/bardiakz/liboqs-binaries), verifies its SHA-256, and bundles the right binary for your target. The first build needs network access (about 74 MB, cached afterwards).

## Versions

`easy_liboqs` mirrors `oqs`: same version number, with `oqs` pinned exactly.

| easy_liboqs | oqs | liboqs |
|---|---|---|
| 4.1.1 | 4.1.1 | 0.16.0 |

## License

MIT, see [LICENSE](LICENSE). The bundled liboqs binaries are MIT licensed, see [LICENSE.liboqs](LICENSE.liboqs).