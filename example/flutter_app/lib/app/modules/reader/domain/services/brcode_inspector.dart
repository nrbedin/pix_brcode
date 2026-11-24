import 'package:pix_brcode/pix_brcode.dart';

import '../entities/brcode_field.dart';
import '../entities/brcode_reading.dart';

/// Lê um BR Code e monta a árvore de campos para mostrar na tela.
///
/// A validação é toda do pix_brcode: aqui só se dá nome aos campos.
class BrCodeInspector {
  /// Cria o inspetor.
  const BrCodeInspector();

  /// Interpreta [input].
  ///
  /// Lança [PixParseException] (com o campo e a posição) se não for um BR
  /// Code Pix válido.
  BrCodeReading inspect(String input) {
    final source = input.trim();
    final payload = PixPayload.parse(source);
    return BrCodeReading(
      source: source,
      payload: payload,
      fields: _fields(EmvTlv.decode(source), parent: null),
    );
  }

  List<BrCodeField> _fields(List<EmvField> fields, {required String? parent}) {
    return [
      for (final field in fields)
        _field(field, parent == null ? field.id : '$parent.${field.id}'),
    ];
  }

  BrCodeField _field(EmvField field, String path) {
    final children = _isTemplate(path)
        ? _fields(EmvTlv.decode(field.value, parent: path), parent: path)
        : const <BrCodeField>[];
    return BrCodeField(
      path: path,
      name: _name(path),
      value: field.value,
      children: children,
    );
  }

  /// Templates do BR Code: contas de arranjos de pagamento (26 a 51), dados
  /// adicionais (62) e os de uso livre (80 a 99).
  ///
  /// Só os de primeiro nível; dentro deles, tudo é valor.
  static bool _isTemplate(String path) {
    if (path.contains('.')) return false;
    final id = int.parse(path);
    return (id >= 26 && id <= 51) || id == 62 || id >= 80;
  }

  static String _name(String path) {
    final known = _names[path];
    if (known != null) return known;
    final parts = path.split('.');
    final id = int.parse(parts.first);
    if (parts.length == 1) {
      if (id >= 27 && id <= 51) return 'Conta de outro arranjo';
      if (id >= 80) return 'Uso livre';
    }
    return 'Campo não usado pelo Pix';
  }

  static const _names = {
    '00': 'Versão do payload',
    '01': 'Método de iniciação',
    '26': 'Conta Pix',
    '26.00': 'Arranjo (GUI)',
    '26.01': 'Chave Pix',
    '26.02': 'Informação adicional',
    '26.25': 'URL da cobrança',
    '52': 'Categoria do recebedor (MCC)',
    '53': 'Moeda',
    '54': 'Valor',
    '58': 'País',
    '59': 'Nome do recebedor',
    '60': 'Cidade do recebedor',
    '61': 'CEP',
    '62': 'Dados adicionais',
    '62.05': 'Identificador (txid)',
    '63': 'CRC16',
  };
}
