import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Câmera que lê um QR Code e devolve o texto dele com `pop`.
class ScanPage extends StatefulWidget {
  /// Cria a tela.
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Evita dois `pop` se a câmera mandar o mesmo QR em sequência.
  var _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;
    _done = true;
    Modular.to.pop(raw);
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR Code'),
        actions: [
          // No navegador a lanterna não é controlável.
          if (!kIsWeb)
            IconButton(
              tooltip: 'Lanterna',
              onPressed: _scanner.toggleTorch,
              icon: const Icon(Icons.flashlight_on),
            ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
            errorBuilder: (context, error, _) => _ScanError(error),
          ),
          const IgnorePointer(child: _Viewfinder()),
        ],
      ),
    );
  }
}

/// Moldura quadrada no meio da câmera, com a dica embaixo.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide * 0.7;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aponte para o QR Code Pix',
              style: TextStyle(color: Colors.white),
            ),
          ],
        );
      },
    );
  }
}

class _ScanError extends StatelessWidget {
  const _ScanError(this.error);

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Sem permissão para usar a câmera. Libere nas configurações do '
            'aparelho ou volte e cole o código.',
      MobileScannerErrorCode.unsupported =>
        'Este aparelho não tem câmera disponível. Volte e cole o código.',
      _ => 'Não foi possível abrir a câmera. Volte e cole o código.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
