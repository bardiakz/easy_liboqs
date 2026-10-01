import 'dart:typed_data';

import 'package:easy_liboqs/easy_liboqs.dart';
import 'package:test/test.dart';

void main() {
  test('bundled liboqs resolves and reports a version', () {
    expect(bundledLiboqsVersion(), isNotEmpty);
  });

  test('KEM round trip', () {
    EasyLiboqs.init();

    final algs = LibOQS.getSupportedKEMAlgorithms();
    expect(algs, isNotEmpty);

    final kem = KEM.create(algs.first)!;
    final kp = kem.generateKeyPair();
    final enc = kem.encapsulate(kp.publicKey);
    final dec = kem.decapsulate(enc.ciphertext, kp.secretKey);

    expect(dec, enc.sharedSecret);

    kp.dispose();
    kem.dispose();
    LibOQS.cleanup();
  });

  test('signature round trip', () {
    EasyLiboqs.init();

    final algs = LibOQS.getSupportedSignatureAlgorithms();
    expect(algs, isNotEmpty);

    final sig = Signature.create(algs.first);
    final kp = sig.generateKeyPair();
    final msg = Uint8List.fromList([1, 2, 3, 4]);
    final s = sig.sign(msg, kp.secretKey);

    expect(sig.verify(msg, s, kp.publicKey), isTrue);

    kp.dispose();
    sig.dispose();
  });
}