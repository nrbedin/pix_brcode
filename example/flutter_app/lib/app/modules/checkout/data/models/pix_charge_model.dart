import '../../domain/entities/pix_charge.dart';

/// Resposta do backend ao criar uma cobrança, no formato da API Pix.
final class PixChargeModel {
  /// Cria o model.
  const PixChargeModel({
    required this.txid,
    required this.pixCopiaECola,
    required this.valorOriginal,
    required this.expiracaoSegundos,
  });

  /// Lê o JSON da resposta. Lança [FormatException] se faltar algum campo.
  factory PixChargeModel.fromJson(Map<String, dynamic> json) {
    try {
      final calendario = json['calendario'] as Map<String, dynamic>;
      final valor = json['valor'] as Map<String, dynamic>;
      return PixChargeModel(
        txid: json['txid'] as String,
        pixCopiaECola: json['pixCopiaECola'] as String,
        valorOriginal: double.parse(valor['original'] as String),
        expiracaoSegundos: calendario['expiracao'] as int,
      );
    } on TypeError catch (e) {
      throw FormatException('resposta de cobrança inválida: $e');
    }
  }

  /// Identificador da cobrança.
  final String txid;

  /// BR Code.
  final String pixCopiaECola;

  /// Valor cobrado.
  final double valorOriginal;

  /// Validade em segundos, contada a partir da criação.
  final int expiracaoSegundos;

  /// Converte para a entidade do domínio.
  PixCharge toEntity() => PixCharge(
        txid: txid,
        brCode: pixCopiaECola,
        amount: valorOriginal,
        expiresIn: Duration(seconds: expiracaoSegundos),
      );
}
