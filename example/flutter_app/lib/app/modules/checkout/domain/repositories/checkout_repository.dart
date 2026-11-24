import '../entities/charge_event.dart';
import '../entities/pix_charge.dart';

/// Contrato com o backend de cobranças Pix.
///
/// Erros chegam como `CheckoutException`.
abstract interface class CheckoutRepository {
  /// Cria uma cobrança de [amount] reais.
  Future<PixCharge> createCharge({required double amount});

  /// Emite as mudanças da cobrança [txid].
  Stream<ChargeEvent> watchCharge(String txid);

  /// Cancela a cobrança [txid].
  Future<void> cancelCharge(String txid);
}
