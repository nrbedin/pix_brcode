import 'dart:convert';

/// CRC16-CCITT usado pelo BR Code (variante "CCITT-FALSE").
///
/// Polinômio `0x1021`, valor inicial `0xFFFF`, sem reflexão de bits e sem
/// XOR final. É calculado sobre os bytes UTF-8 de todo o payload, incluindo
/// o ID e o tamanho do campo de CRC (`6304`), e gravado como 4 dígitos
/// hexadecimais maiúsculos no final.
abstract final class Crc16 {
  static const int _polynomial = 0x1021;
  static const int _initialValue = 0xFFFF;

  /// Calcula o CRC16 de [bytes] e devolve um inteiro de 0 a `0xFFFF`.
  static int compute(List<int> bytes) {
    var crc = _initialValue;
    for (final byte in bytes) {
      crc ^= (byte & 0xFF) << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0 ? (crc << 1) ^ _polynomial : crc << 1;
        crc &= 0xFFFF;
      }
    }
    return crc;
  }

  /// Calcula o CRC16 de [input] (codificado em UTF-8) e devolve 4 dígitos
  /// hexadecimais maiúsculos, como aparece no BR Code.
  static String hex(String input) => compute(
        utf8.encode(input),
      ).toRadixString(16).toUpperCase().padLeft(4, '0');

  /// Indica se os 4 últimos caracteres de [payload] são o CRC16 correto do
  /// restante da string.
  ///
  /// A comparação ignora maiúsculas e minúsculas. Devolve `false` se o
  /// payload tiver menos de 4 caracteres.
  static bool isValid(String payload) {
    if (payload.length < 4) return false;
    final body = payload.substring(0, payload.length - 4);
    final crc = payload.substring(payload.length - 4).toUpperCase();
    return hex(body) == crc;
  }
}
