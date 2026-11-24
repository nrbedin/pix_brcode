/// Erro ao falar com o backend de cobranças.
final class CheckoutException implements Exception {
  /// Cria o erro com uma [message] para o usuário.
  const CheckoutException(this.message);

  /// Motivo do erro.
  final String message;

  @override
  String toString() => message;
}
