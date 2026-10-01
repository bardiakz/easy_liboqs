// hook/build.dart
//
// Downloads the prebuilt liboqs all-platforms archive from liboqs-binaries,
// verifies its sha256, and bundles the right binary for the current target
// as a code asset. Runs once per target OS/architecture.
//
// NOTE: written against the hooks/code_assets API docs; not yet compiled.
// If a call name differs in your installed version, fix it here.
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    // Re-run the hook whenever versions.yaml changes.
    final versionsUri = input.packageRoot.resolve('versions.yaml');
    output.dependencies.add(versionsUri);
    final v = _readFlatYaml(File.fromUri(versionsUri));

    final liboqs = _require(v, 'liboqs');
    final repo = _require(v, 'binaries_repo');
    final tag = _require(v, 'binaries_tag');
    final sha = _require(v, 'sha256'); // mandatory: never bundle unverified code

    final archiveRoot = await _ensureArchive(
      cacheDir: Directory.fromUri(input.outputDirectoryShared),
      url: 'https://github.com/$repo/releases/download/$tag/'
          'liboqs-$liboqs-all-platforms.tar.gz',
      liboqs: liboqs,
      expectedSha256: sha,
    );

    final target = _select(input.config.code);
    final source = File.fromUri(archiveRoot.uri.resolve(target.pathInArchive));
    if (!source.existsSync()) {
      throw StateError('Not found in archive: ${target.pathInArchive}');
    }

    // Same file name for every architecture (required by Flutter), written to
    // the per-target output directory.
    final dest = input.outputDirectory.resolve(target.fileName);
    await Directory.fromUri(input.outputDirectory).create(recursive: true);
    await source.copy(File.fromUri(dest).path);

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        // Must match the Dart file holding the @Native bindings.
        name: 'src/probe.dart',
        linkMode: DynamicLoadingBundled(),
        file: dest,
      ),
    );
  });
}

// --- platform selection -----------------------------------------------------

({String pathInArchive, String fileName}) _select(CodeConfig c) {
  final arch = c.targetArchitecture;
  String pick(Map<Architecture, String> m) =>
      m[arch] ?? (throw UnsupportedError('Unsupported architecture: $arch'));

  switch (c.targetOS) {
    case OS.linux:
      final a = pick({Architecture.x64: 'x86_64', Architecture.arm64: 'aarch64'});
      return (pathInArchive: 'linux/$a/liboqs.so', fileName: 'liboqs.so');
    case OS.macOS:
      final a = pick({Architecture.x64: 'x86_64', Architecture.arm64: 'arm64'});
      return (pathInArchive: 'macos/$a/liboqs.dylib', fileName: 'liboqs.dylib');
    case OS.windows:
      pick({Architecture.x64: 'x86_64'});
      return (pathInArchive: 'windows/x86_64/oqs.dll', fileName: 'oqs.dll');
    case OS.android:
      final abi = pick({
        Architecture.arm: 'armeabi-v7a',
        Architecture.arm64: 'arm64-v8a',
        Architecture.ia32: 'x86',
        Architecture.x64: 'x86_64',
      });
      return (pathInArchive: 'android/$abi/liboqs.so', fileName: 'liboqs.so');
    default:
      // iOS ships as an XCFramework; the device/simulator slices must be picked
      // per SDK (input.config.code.iOS.targetSdk). Inspect the xcframework first.
      throw UnsupportedError('Unsupported target OS: ${c.targetOS}');
  }
}

// --- download, verify, extract ---------------------------------------------

Future<Directory> _ensureArchive({
  required Directory cacheDir,
  required String url,
  required String liboqs,
  required String expectedSha256,
}) async {
  await cacheDir.create(recursive: true);
  final root = Directory.fromUri(cacheDir.uri.resolve('liboqs-$liboqs/'));
  final marker = File.fromUri(cacheDir.uri.resolve('liboqs-$liboqs.verified'));

  // Already downloaded, verified and extracted for this exact hash.
  if (root.existsSync() &&
      marker.existsSync() &&
      marker.readAsStringSync().trim() == expectedSha256.toLowerCase()) {
    return root;
  }

  stderr.writeln('easy_liboqs: downloading $url');
  final bytes = await _download(url);

  final actual = sha256.convert(bytes).toString();
  if (actual != expectedSha256.toLowerCase()) {
    throw StateError(
      'sha256 mismatch for $url\n  expected $expectedSha256\n  actual   $actual',
    );
  }

  if (root.existsSync()) root.deleteSync(recursive: true);
  final tar = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
  final base = cacheDir.absolute.path;
  for (final f in tar) {
    if (!f.isFile) continue;
    final out = File.fromUri(cacheDir.uri.resolve(f.name));
    // Refuse entries that would escape the cache directory.
    if (!out.absolute.path.startsWith(base)) {
      throw StateError('Unsafe path in archive: ${f.name}');
    }
    out.createSync(recursive: true);
    out.writeAsBytesSync(f.content as List<int>);
  }
  if (!root.existsSync()) {
    throw StateError('Archive did not contain liboqs-$liboqs/');
  }
  marker.writeAsStringSync(expectedSha256.toLowerCase());
  return root;
}

Future<Uint8List> _download(String url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url)); // follows redirects
    final res = await req.close();
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  } finally {
    client.close();
  }
}

// --- versions.yaml (flat `key: value  # comment`) ---------------------------

Map<String, String> _readFlatYaml(File f) {
  final re = RegExp(r'^([A-Za-z0-9_]+):\s*"?([^"#\s]*)"?');
  final out = <String, String>{};
  for (final line in f.readAsLinesSync()) {
    final m = re.firstMatch(line);
    if (m != null) out[m.group(1)!] = m.group(2)!;
  }
  return out;
}

String _require(Map<String, String> v, String key) {
  final value = v[key];
  if (value == null || value.isEmpty) {
    throw StateError('versions.yaml: missing "$key"');
  }
  return value;
}