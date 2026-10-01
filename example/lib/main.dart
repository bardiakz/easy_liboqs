// example/lib/main.dart
import 'package:easy_liboqs/easy_liboqs.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: Demo()));

class Demo extends StatefulWidget {
  const Demo({super.key});

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  String _out = 'Press the button to run a KEM round trip.';

  void _run() {
    try {
      EasyLiboqs.init();

      final algs = LibOQS.getSupportedKEMAlgorithms();
      final name = algs.contains('ML-KEM-768') ? 'ML-KEM-768' : algs.first;

      final kem = KEM.create(name)!;
      final kp = kem.generateKeyPair();
      final enc = kem.encapsulate(kp.publicKey);
      final dec = kem.decapsulate(enc.ciphertext, kp.secretKey);
      final ok = dec.length == enc.sharedSecret.length &&
          List.generate(dec.length, (i) => dec[i] == enc.sharedSecret[i])
              .every((b) => b);

      final result = 'liboqs ${bundledLiboqsVersion()}\n'
          '$name round trip: ${ok ? 'OK' : 'MISMATCH'}\n'
          'public key ${kem.publicKeyLength} B, '
          'ciphertext ${kem.ciphertextLength} B';

      kp.dispose();
      kem.dispose();
      setState(() => _out = result);
    } catch (e) {
      setState(() => _out = 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('easy_liboqs example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton(onPressed: _run, child: const Text('Run KEM test')),
            const SizedBox(height: 24),
            SelectableText(_out),
          ],
        ),
      ),
    );
  }
}