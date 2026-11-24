/// Um campo EMV do BR Code, com nome legível e os subcampos, se for um
/// template.
final class BrCodeField {
  /// Cria o campo.
  const BrCodeField({
    required this.path,
    required this.name,
    required this.value,
    this.children = const [],
  });

  /// Caminho de IDs, como `'26.01'`.
  final String path;

  /// O que o campo significa, como "Chave Pix".
  final String name;

  /// Valor bruto. Em templates, é a sequência TLV dos [children].
  final String value;

  /// Subcampos, quando o campo é um template.
  final List<BrCodeField> children;

  /// ID do campo dentro do template (os 2 últimos dígitos do [path]).
  String get id => path.substring(path.length - 2);
}
