import 'package:flutter_modular/flutter_modular.dart';

import 'checkout_binds.dart';
import 'presentation/pages/checkout_page.dart';

/// Módulo de pagamento Pix: gera a cobrança, mostra o QR e acompanha o
/// pagamento.
class CheckoutModule extends Module {
  @override
  List<Bind> get binds => checkoutBinds;

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (context, args) => const CheckoutPage()),
      ];
}
