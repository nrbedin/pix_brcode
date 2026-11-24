import 'package:flutter_modular/flutter_modular.dart';

import 'presentation/pages/reader_page.dart';
import 'presentation/pages/scan_page.dart';
import 'reader_binds.dart';

/// Módulo de leitura de BR Code: pela câmera ou colando o "copia e cola".
class ReaderModule extends Module {
  /// Rota da câmera, relativa ao módulo.
  static const scanRoute = '/scan';

  @override
  List<Bind> get binds => readerBinds;

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (context, args) => const ReaderPage()),
        ChildRoute(scanRoute, child: (context, args) => const ScanPage()),
      ];
}
