// App mínimo que demonstra um pagamento Pix no front, na estrutura
// flutter_modular + MobX:
//
// pedir cobrança ao backend → validar o BR Code com pix_brcode → mostrar o
// QR com qr_flutter → acompanhar as etapas do pagamento → comprovante.
//
// O backend é simulado (FakePixDatasource). Veja AppModule para trocá-lo.

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'app/app_module.dart';
import 'app/app_widget.dart';

void main() {
  runApp(ModularApp(module: AppModule(), child: const AppWidget()));
}
