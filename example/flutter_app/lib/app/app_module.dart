import 'package:flutter_modular/flutter_modular.dart';

import 'modules/checkout/checkout_module.dart';
import 'modules/checkout/data/datasources/fake_pix_datasource.dart';
import 'modules/checkout/data/datasources/pix_datasource.dart';

/// Módulo raiz.
///
/// Registra o backend usado pelo app. Aqui é sempre o [FakePixDatasource];
/// testes passam um com tempos menores. Para um backend real, troque por
/// uma implementação de [PixDatasource] com Dio e remova o
/// [PaymentSimulator].
class AppModule extends Module {
  /// Cria o módulo raiz com [datasource] como backend.
  AppModule({FakePixDatasource? datasource})
      : _datasource = datasource ?? FakePixDatasource();

  final FakePixDatasource _datasource;

  @override
  List<Bind> get binds => [
        Bind.instance<PixDatasource>(_datasource),
        Bind.instance<PaymentSimulator>(_datasource),
      ];

  @override
  List<ModularRoute> get routes => [
        ModuleRoute('/', module: CheckoutModule()),
      ];
}
