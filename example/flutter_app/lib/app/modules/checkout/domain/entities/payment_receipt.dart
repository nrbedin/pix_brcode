/// Dados do pagamento recebido, para o comprovante.
final class PaymentReceipt {
  /// Cria o comprovante.
  const PaymentReceipt({
    required this.endToEndId,
    required this.amount,
    required this.paidAt,
    required this.payerName,
  });

  /// Identificador único da transação no SPI (32 caracteres, começa com E).
  final String endToEndId;

  /// Valor pago.
  final double amount;

  /// Momento do pagamento.
  final DateTime paidAt;

  /// Nome do pagador.
  final String payerName;
}
