// Runs inside the real example app on a device/emulator, so it checks that
// the bundled liboqs is found in an actual app bundle.
import 'package:easy_liboqs/easy_liboqs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled liboqs loads and a KEM round trip works', (tester) async {
    EasyLiboqs.init();
    expect(bundledLiboqsVersion(), isNotEmpty);

    final algs = LibOQS.getSupportedKEMAlgorithms();
    expect(algs, isNotEmpty);

    final kem = KEM.create(algs.first)!;
    final kp = kem.generateKeyPair();
    final enc = kem.encapsulate(kp.publicKey);
    final dec = kem.decapsulate(enc.ciphertext, kp.secretKey);

    expect(dec, enc.sharedSecret);

    kp.dispose();
    kem.dispose();
  });
}