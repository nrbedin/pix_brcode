// App mínimo que demonstra um pagamento Pix no front:
// pedir cobrança ao backend → validar o BR Code com pix_brcode → mostrar o
// QR com qr_flutter → esperar a confirmação → mostrar o resultado.
//
// O backend aqui é simulado (FakePixGateway). Para usar um backend real,
// implemente PixGateway com chamadas HTTP ao seu servidor.

import 'package:flutter/material.dart';

import 'src/checkout_controller.dart';
import 'src/checkout_page.dart';
import 'src/fake_pix_gateway.dart';

void main() {
  runApp(PixCheckoutDemoApp(gateway: FakePixGateway()));
}

/// App de demonstração.
class PixCheckoutDemoApp extends StatefulWidget {
  /// Cria o app usando [gateway] como backend.
  const PixCheckoutDemoApp({required this.gateway, super.key});

  /// Backend simulado.
  final FakePixGateway gateway;

  @override
  State<PixCheckoutDemoApp> createState() => _PixCheckoutDemoAppState();
}

class _PixCheckoutDemoAppState extends State<PixCheckoutDemoApp> {
  late final CheckoutController _controller =
      CheckoutController(widget.gateway);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pix Checkout Demo',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00897B),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF00897B),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: CheckoutPage(
        controller: _controller,
        onSimulatePayment: widget.gateway.simulatePayment,
      ),
    );
  }
}
