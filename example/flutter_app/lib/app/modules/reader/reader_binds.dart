import 'package:flutter_modular/flutter_modular.dart';

import 'presentation/controller/reader_controller.dart';
import 'presentation/mobx/reader_store.dart';

/// Dependências do módulo de leitura.
final readerBinds = <Bind>[
  Bind.lazySingleton<ReaderStore>((i) => ReaderStore()),
  Bind.lazySingleton<ReaderController>(
    (i) => ReaderController(i<ReaderStore>()),
  ),
];
