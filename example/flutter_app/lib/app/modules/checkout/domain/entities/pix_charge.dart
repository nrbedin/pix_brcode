/// Cobrança criada pelo backend.
final class PixCharge {
  /// Cria uma cobrança.
  const PixCharge({
    required this.txid,
    required this.brCode,
    required this.amount,
    required this.expiresIn,
  });

  /// Identificador da cobrança no PSP.
  final String txid;

  /// Texto do "Pix Copia e Cola", que também vai no QR Code.
  final String brCode;

  /// Valor cobrado.
  final double amount;

  /// Tempo até a cobrança expirar.
  final Duration expiresIn;
}
