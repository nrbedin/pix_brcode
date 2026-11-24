import '../../domain/entities/charge_event.dart';
import '../../domain/entities/pix_charge.dart';
import '../../domain/exceptions/checkout_exception.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../datasources/pix_datasource.dart';
import '../models/charge_event_model.dart';
import '../models/pix_charge_model.dart';

/// Implementação de [CheckoutRepository] sobre um [PixDatasource].
///
/// Converte JSON em entidades e qualquer erro técnico em
/// [CheckoutException] com uma mensagem para o usuário.
final class CheckoutRepositoryImpl implements CheckoutRepository {
  /// Cria o repositório.
  const CheckoutRepositoryImpl(this._datasource);

  final PixDatasource _datasource;

  @override
  Future<PixCharge> createCharge({required double amount}) async {
    try {
      final json = await _datasource.createCharge(amount: amount);
      return PixChargeModel.fromJson(json).toEntity();
    } on DatasourceException catch (e) {
      throw CheckoutException('O servidor não respondeu ($e).');
    } on FormatException catch (e) {
      throw CheckoutException('Resposta inesperada do servidor: ${e.message}');
    }
  }

  @override
  Stream<ChargeEvent> watchCharge(String txid) => _datasource
          .watchCharge(txid)
          .map((json) => ChargeEventModel.fromJson(json).toEntity())
          .handleError(
        (Object error) {
          throw CheckoutException('Falha ao acompanhar a cobrança: $error');
        },
        test: (error) => error is! CheckoutException,
      );

  @override
  Future<void> cancelCharge(String txid) async {
    try {
      await _datasource.cancelCharge(txid);
    } on DatasourceException {
      // Cancelar é melhor esforço: a cobrança expira sozinha no PSP.
    }
  }
}
