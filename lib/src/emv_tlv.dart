import 'pix_parse_exception.dart';

/// Um campo EMV no formato TLV: [id] de 2 dígitos, tamanho de 2 dígitos e
/// [value].
///
/// Em campos do tipo template (como `26` e `62`), [value] contém outros
/// campos TLV, que podem ser lidos com [EmvTlv.decode].
final class EmvField {
  /// Cria um campo. Não valida nada: use [EmvTlv.encode] para serializar.
  const EmvField(this.id, this.value);

  /// ID de 2 dígitos, de `00` a `99`.
  final String id;

  /// Conteúdo do campo.
  final String value;

  /// Serializa o campo como `ID + tamanho + valor`.
  String encode() => EmvTlv.encode(id, value);

  @override
  bool operator ==(Object other) =>
      other is EmvField && other.id == id && other.value == value;

  @override
  int get hashCode => Object.hash(id, value);

  @override
  String toString() => 'EmvField($id, $value)';
}

/// Leitura e escrita de campos EMV TLV, o formato usado pelo BR Code.
abstract final class EmvTlv {
  /// Maior tamanho que cabe nos 2 dígitos do campo de tamanho.
  static const int maxValueLength = 99;

  static final RegExp _twoDigits = RegExp(r'^\d{2}$');

  /// Serializa um campo como `ID + tamanho + valor`.
  ///
  /// Lança [ArgumentError] se [id] não tiver 2 dígitos ou se [value] estiver
  /// vazio ou tiver mais de [maxValueLength] caracteres.
  static String encode(String id, String value) {
    if (!_twoDigits.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'deve ter 2 dígitos');
    }
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'não pode ser vazio');
    }
    if (value.length > maxValueLength) {
      throw ArgumentError.value(
        value,
        'value',
        'tem ${value.length} caracteres; o máximo é $maxValueLength',
      );
    }
    return '$id${value.length.toString().padLeft(2, '0')}$value';
  }

  /// Serializa uma lista de campos, na ordem dada.
  static String encodeAll(Iterable<EmvField> fields) =>
      fields.map((field) => field.encode()).join();

  /// Lê uma sequência de campos TLV de [data].
  ///
  /// [parent] é o caminho do template que contém [data] (por exemplo `'26'`)
  /// e é usado para montar [PixParseException.field] em templates aninhados.
  /// [baseOffset] é a posição de [data] na string original, para que
  /// [PixParseException.offset] aponte para o lugar certo.
  ///
  /// Lança [PixParseException] se algum ID ou tamanho for inválido ou se o
  /// valor terminar antes do tamanho declarado.
  static List<EmvField> decode(
    String data, {
    String? parent,
    int baseOffset = 0,
  }) {
    final fields = <EmvField>[];
    var position = 0;

    while (position < data.length) {
      final offset = baseOffset + position;

      if (data.length - position < 4) {
        throw PixParseException(
          'cabeçalho de campo incompleto: esperados 4 caracteres '
          '(ID e tamanho), restam ${data.length - position}',
          field: parent,
          offset: offset,
        );
      }

      final id = data.substring(position, position + 2);
      if (!_twoDigits.hasMatch(id)) {
        throw PixParseException(
          'ID de campo inválido "$id": deve ter 2 dígitos',
          field: parent,
          offset: offset,
        );
      }
      final path = parent == null ? id : '$parent.$id';

      final lengthText = data.substring(position + 2, position + 4);
      if (!_twoDigits.hasMatch(lengthText)) {
        throw PixParseException(
          'tamanho inválido "$lengthText": deve ter 2 dígitos',
          field: path,
          offset: offset + 2,
        );
      }
      final length = int.parse(lengthText);
      if (length == 0) {
        throw PixParseException(
          'tamanho 00 não é permitido',
          field: path,
          offset: offset + 2,
        );
      }

      final valueStart = position + 4;
      final valueEnd = valueStart + length;
      if (valueEnd > data.length) {
        throw PixParseException(
          'valor declarado com $length caracteres, mas só restam '
          '${data.length - valueStart}',
          field: path,
          offset: offset + 4,
        );
      }

      fields.add(EmvField(id, data.substring(valueStart, valueEnd)));
      position = valueEnd;
    }

    return fields;
  }
}
