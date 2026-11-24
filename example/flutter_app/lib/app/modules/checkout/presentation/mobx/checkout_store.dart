import 'package:mobx/mobx.dart';

import 'checkout_state.dart';

part 'checkout_store.g.dart';

/// Estado observável da tela de pagamento.
///
/// Só guarda e expõe o estado; quem decide as transições é o
/// `CheckoutController`.
class CheckoutStore = CheckoutStoreBase with _$CheckoutStore;

/// Base do [CheckoutStore], usada pelo mobx_codegen.
abstract class CheckoutStoreBase with Store {
  /// Estado atual.
  @observable
  CheckoutState state = const EnteringAmount();

  /// Se dá para cancelar a cobrança na tela.
  ///
  /// Depois que o pagamento começou a ser processado, não dá mais.
  @computed
  bool get canCancel => state is CreatingCharge || state is AwaitingPayment;

  /// Troca o estado.
  @action
  void setState(CheckoutState value) => state = value;
}
