import 'crc16.dart';
import 'emv_tlv.dart';
import 'pix_key.dart';
import 'pix_parse_exception.dart';
import 'pix_payload.dart';

/// Um campo lido com a posição onde seu valor começa na string original.
typedef _Located = ({String value, int offset});

/// Interpreta [input] como um BR Code Pix.
///
/// Veja [PixPayload.parse].
PixPayload parsePixPayload(String input) => _Parser(input.trim()).parse();

final class _Parser {
  _Parser(this.source);

  final String source;

  static final RegExp _amountPattern = RegExp(r'^\d+(\.\d{1,2})?$');
  static final RegExp _mccPattern = RegExp(r'^\d{4}$');

  PixParseException _error(String message, {String? field, int? offset}) =>
      PixParseException(
        message,
        field: field,
        source: source,
        offset: offset,
      );

  PixPayload parse() {
    if (source.isEmpty) throw _error('payload vazio');

    final fields = _decode(source);
    _checkStructure(fields);

    final account = fields[PixFieldId.merchantAccount];
    if (account == null) {
      throw _error(
        'template 26 (conta Pix) ausente',
        field: PixFieldId.merchantAccount,
      );
    }
    final accountFields = _decode(
      account.value,
      parent: PixFieldId.merchantAccount,
      baseOffset: account.offset,
    );
    _checkGui(accountFields, account.offset);

    _expectValue(
        fields, PixFieldId.currency, '986', 'moeda deve ser 986 (BRL)');
    _expectValue(fields, PixFieldId.countryCode, 'BR', 'país deve ser BR');
    final mcc = _required(fields, PixFieldId.merchantCategoryCode);
    if (!_mccPattern.hasMatch(mcc.value)) {
      throw _error(
        'MCC deve ter 4 dígitos',
        field: PixFieldId.merchantCategoryCode,
        offset: mcc.offset,
      );
    }

    final pointOfInitiation = fields[PixFieldId.pointOfInitiation];
    if (pointOfInitiation != null &&
        pointOfInitiation.value != '11' &&
        pointOfInitiation.value != '12') {
      throw _error(
        'método de iniciação deve ser 11 (reutilizável) ou 12 (uso único), '
        'encontrado "${pointOfInitiation.value}"',
        field: PixFieldId.pointOfInitiation,
        offset: pointOfInitiation.offset,
      );
    }

    final name = _required(fields, PixFieldId.merchantName);
    final city = _required(fields, PixFieldId.merchantCity);
    final amount = _amount(fields[PixFieldId.amount]);
    final postalCode = fields[PixFieldId.postalCode];

    final key = accountFields[PixFieldId.key];
    final url = accountFields[PixFieldId.url];
    if (key != null && url != null) {
      throw _error(
        'template 26 tem chave (26.01) e URL (26.25); use só uma',
        field: PixFieldId.merchantAccount,
        offset: account.offset,
      );
    }

    return _build(
      fields: fields,
      () {
        if (url != null) {
          return DynamicPixPayload(
            url: url.value,
            merchantName: name.value,
            merchantCity: city.value,
            amount: amount,
            postalCode: postalCode?.value,
          );
        }
        if (key == null) {
          throw _error(
            'template 26 sem chave (26.01) nem URL (26.25)',
            field: PixFieldId.merchantAccount,
            offset: account.offset,
          );
        }
        return StaticPixPayload(
          key: _key(key),
          merchantName: name.value,
          merchantCity: city.value,
          amount: amount,
          description: accountFields[PixFieldId.description]?.value,
          txid: _txid(fields),
          postalCode: postalCode?.value,
          singleUse: pointOfInitiation?.value == '12',
        );
      },
      accountFields: accountFields,
    );
  }

  /// Lê os campos de [data] em um mapa ID → valor e posição, rejeitando IDs
  /// repetidos.
  Map<String, _Located> _decode(
    String data, {
    String? parent,
    int baseOffset = 0,
  }) {
    final result = <String, _Located>{};
    var offset = baseOffset;
    for (final field in EmvTlv.decode(
      data,
      parent: parent,
      baseOffset: baseOffset,
    )) {
      final path = parent == null ? field.id : '$parent.${field.id}';
      if (result.containsKey(field.id)) {
        throw _error('campo repetido', field: path, offset: offset);
      }
      result[field.id] = (value: field.value, offset: offset + 4);
      offset += 4 + field.value.length;
    }
    return result;
  }

  /// Confere versão no início, CRC no fim e o valor do CRC.
  void _checkStructure(Map<String, _Located> fields) {
    final ids = fields.keys.toList();

    if (ids.first != PixFieldId.payloadFormat) {
      throw _error(
        'o payload deve começar pelo campo 00 (versão)',
        field: PixFieldId.payloadFormat,
        offset: 0,
      );
    }
    final version = fields[PixFieldId.payloadFormat]!;
    if (version.value != '01') {
      throw _error(
        'versão do payload deve ser 01, encontrado "${version.value}"',
        field: PixFieldId.payloadFormat,
        offset: version.offset,
      );
    }

    final crc = fields[PixFieldId.crc];
    if (crc == null || ids.last != PixFieldId.crc) {
      throw _error(
        'o payload deve terminar pelo campo 63 (CRC)',
        field: PixFieldId.crc,
        offset: crc?.offset,
      );
    }
    if (crc.value.length != 4) {
      throw _error(
        'CRC deve ter 4 caracteres',
        field: PixFieldId.crc,
        offset: crc.offset,
      );
    }
    final expected = Crc16.hex(source.substring(0, source.length - 4));
    if (crc.value.toUpperCase() != expected) {
      throw _error(
        'CRC inválido: calculado $expected, encontrado ${crc.value}',
        field: PixFieldId.crc,
        offset: crc.offset,
      );
    }
  }

  void _checkGui(Map<String, _Located> accountFields, int accountOffset) {
    final gui = accountFields[PixFieldId.gui];
    if (gui == null || gui.value.toLowerCase() != PixPayload.gui) {
      throw _error(
        'GUI deve ser "${PixPayload.gui}"'
        '${gui == null ? '' : ', encontrado "${gui.value}"'}',
        field: '${PixFieldId.merchantAccount}.${PixFieldId.gui}',
        offset: gui?.offset ?? accountOffset,
      );
    }
  }

  _Located _required(Map<String, _Located> fields, String id) {
    final field = fields[id];
    if (field == null) throw _error('campo obrigatório ausente', field: id);
    return field;
  }

  void _expectValue(
    Map<String, _Located> fields,
    String id,
    String expected,
    String message,
  ) {
    final field = _required(fields, id);
    if (field.value != expected) {
      throw _error(
        '$message, encontrado "${field.value}"',
        field: id,
        offset: field.offset,
      );
    }
  }

  double? _amount(_Located? field) {
    if (field == null) return null;
    if (!_amountPattern.hasMatch(field.value)) {
      throw _error(
        'valor deve usar ponto e até 2 casas decimais (ex.: 10.50), '
        'encontrado "${field.value}"',
        field: PixFieldId.amount,
        offset: field.offset,
      );
    }
    return double.parse(field.value);
  }

  PixKey _key(_Located field) {
    try {
      return PixKey.parse(field.value);
    } on FormatException catch (e) {
      throw _error(
        'chave Pix inválida: ${e.message}',
        field: '${PixFieldId.merchantAccount}.${PixFieldId.key}',
        offset: field.offset,
      );
    }
  }

  String? _txid(Map<String, _Located> fields) {
    final additional = fields[PixFieldId.additionalData];
    if (additional == null) return null;
    final subfields = _decode(
      additional.value,
      parent: PixFieldId.additionalData,
      baseOffset: additional.offset,
    );
    return subfields[PixFieldId.txid]?.value;
  }

  /// Executa [build] e converte os [ArgumentError] dos construtores em
  /// [PixParseException] apontando o campo correspondente.
  PixPayload _build(
    PixPayload Function() build, {
    required Map<String, _Located> fields,
    required Map<String, _Located> accountFields,
  }) {
    try {
      return build();
    } on ArgumentError catch (e) {
      final (path, located) = switch (e.name) {
        'merchantName' => (
            PixFieldId.merchantName,
            fields[PixFieldId.merchantName],
          ),
        'merchantCity' => (
            PixFieldId.merchantCity,
            fields[PixFieldId.merchantCity],
          ),
        'amount' => (PixFieldId.amount, fields[PixFieldId.amount]),
        'postalCode' => (PixFieldId.postalCode, fields[PixFieldId.postalCode]),
        'description' => (
            '${PixFieldId.merchantAccount}.${PixFieldId.description}',
            accountFields[PixFieldId.description],
          ),
        'url' => (
            '${PixFieldId.merchantAccount}.${PixFieldId.url}',
            accountFields[PixFieldId.url],
          ),
        'txid' => (
            '${PixFieldId.additionalData}.${PixFieldId.txid}',
            fields[PixFieldId.additionalData],
          ),
        _ => (null, null),
      };
      throw _error(
        '${e.message}',
        field: path,
        offset: located?.offset,
      );
    }
  }
}
