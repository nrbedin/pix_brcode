import 'package:flutter_modular/flutter_modular.dart';

import 'core/share/share_service.dart';
import 'modules/checkout/checkout_module.dart';
import 'modules/checkout/data/datasources/fake_pix_datasource.dart';
import 'modules/checkout/data/datasources/pix_datasource.dart';
import 'modules/reader/reader_module.dart';

/// Módulo raiz.
///
/// Registra o backend e o compartilhamento usados pelo app. O backend é
/// sempre o [FakePixDatasource]; testes passam um com tempos menores e um
/// [ShareService] falso. Para um backend real, troque por uma implementação
/// de [PixDatasource] com Dio e remova o [PaymentSimulator].
class AppModule extends Module {
  /// Cria o módulo raiz com [datasource] como backend.
  AppModule({FakePixDatasource? datasource, ShareService? shareService})
      : _datasource = datasource ?? FakePixDatasource(),
        _shareService = shareService ?? const SharePlusShareService();

  final FakePixDatasource _datasource;
  final ShareService _shareService;

  @override
  List<Bind> get binds => [
        Bind.instance<PixDatasource>(_datasource),
        Bind.instance<PaymentSimulator>(_datasource),
        Bind.instance<ShareService>(_shareService),
      ];

  @override
  List<ModularRoute> get routes => [
        ModuleRoute('/', module: CheckoutModule()),
        ModuleRoute('/reader', module: ReaderModule()),
      ];
}
