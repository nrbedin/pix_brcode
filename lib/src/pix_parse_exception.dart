/// Erro ao interpretar um payload BR Code.
///
/// [field] identifica o campo com problema pelo caminho de IDs EMV, como
/// `'54'` (valor) ou `'26.01'` (chave Pix dentro do template 26). É `null`
/// quando o erro não pertence a um campo específico.
///
/// [offset] é a posição, na string original, onde o problema foi encontrado.
class PixParseException extends FormatException {
  /// Cria a exceção com uma [message] descritiva.
  const PixParseException(
    String message, {
    this.field,
    Object? source,
    int? offset,
  }) : super(message, source, offset);

  /// Caminho de IDs do campo inválido, como `'26.01'`.
  final String? field;

  @override
  String toString() {
    final buffer = StringBuffer('PixParseException');
    if (field != null) buffer.write(' (campo $field)');
    buffer.write(': $message');
    if (offset != null) buffer.write(' (posição $offset)');
    return buffer.toString();
  }
}
