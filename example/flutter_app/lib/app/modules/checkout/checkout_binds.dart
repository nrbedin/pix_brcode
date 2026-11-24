import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasources/pix_datasource.dart';
import 'data/repositories/checkout_repository_impl.dart';
import 'domain/repositories/checkout_repository.dart';
import 'presentation/controller/checkout_controller.dart';
import 'presentation/mobx/checkout_store.dart';

/// Dependências do módulo de pagamento.
///
/// O [PixDatasource] e o [PaymentSimulator] vêm do `AppModule`, para que o
/// backend possa ser trocado (fake, real ou de teste) sem mexer aqui.
final checkoutBinds = <Bind>[
  Bind.lazySingleton<CheckoutRepository>(
    (i) => CheckoutRepositoryImpl(i<PixDatasource>()),
  ),
  Bind.lazySingleton<CheckoutStore>((i) => CheckoutStore()),
  Bind.lazySingleton<CheckoutController>(
    (i) => CheckoutController(
      i<CheckoutRepository>(),
      i<CheckoutStore>(),
      simulator: i<PaymentSimulator>(),
    ),
    onDispose: (controller) => controller.dispose(),
  ),
];
