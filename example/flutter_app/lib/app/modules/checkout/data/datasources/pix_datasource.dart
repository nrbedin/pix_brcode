/// Acesso ao **seu** backend de cobranças, em JSON.
///
/// Os campos seguem os nomes da API Pix do Bacen (`txid`, `calendario`,
/// `status`, `pixCopiaECola`, `pix[].endToEndId`), que é o que um backend
/// costuma repassar ao app.
///
/// Uma implementação real usaria Dio ou http:
/// - [createCharge] → `POST /cobrancas` no backend, que chama `PUT /cob/{txid}`
///   na API Pix do PSP (com certificado e OAuth2, que nunca ficam no app);
/// - [watchCharge] → WebSocket, Server-Sent Events ou polling no backend, que
///   recebe o webhook do PSP;
/// - [cancelCharge] → `DELETE /cobrancas/{txid}` no backend.
abstract interface class PixDatasource {
  /// Cria a cobrança e devolve o JSON da resposta.
  Future<Map<String, dynamic>> createCharge({required double amount});

  /// Emite um JSON a cada mudança da cobrança.
  Stream<Map<String, dynamic>> watchCharge(String txid);

  /// Cancela a cobrança.
  Future<void> cancelCharge(String txid);
}

/// Aciona um pagamento simulado. Só existe no backend fake.
abstract interface class PaymentSimulator {
  /// Simula o pagador pagando a cobrança [txid] no app do banco.
  void simulatePayment(String txid);
}

/// Erro de comunicação com o backend (rede, HTTP, resposta inesperada).
final class DatasourceException implements Exception {
  /// Cria o erro.
  const DatasourceException(this.message);

  /// Detalhe técnico do erro.
  final String message;

  @override
  String toString() => message;
}
