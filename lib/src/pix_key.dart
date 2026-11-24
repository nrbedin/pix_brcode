/// Tipos de chave Pix aceitos pelo DICT.
enum PixKeyType {
  /// CPF: 11 dígitos, com dígitos verificadores válidos.
  cpf,

  /// CNPJ: 14 caracteres (numérico ou alfanumérico), com dígitos
  /// verificadores válidos.
  cnpj,

  /// Telefone no formato E.164, como `+5511988887777`.
  phone,

  /// E-mail com até 77 caracteres.
  email,

  /// Chave aleatória (EVP): UUID com 36 caracteres.
  evp,
}

/// Uma chave Pix validada e normalizada.
///
/// Use [PixKey.parse] quando o tipo não é conhecido (ele é detectado pelo
/// formato) ou os construtores nomeados quando é. Em todos os casos o
/// [value] fica na forma que vai no BR Code: CPF e CNPJ sem máscara, telefone
/// sem espaços, e-mail e EVP em minúsculas.
final class PixKey {
  const PixKey._(this.type, this.value);

  /// Detecta o tipo da chave pelo formato, valida e normaliza.
  ///
  /// - contém `@` → e-mail;
  /// - começa com `+` → telefone;
  /// - tem formato de UUID → EVP;
  /// - 11 dígitos → CPF; 14 caracteres → CNPJ (máscaras `.`, `-` e `/`
  ///   são aceitas).
  ///
  /// Lança [FormatException] com o motivo se a chave for inválida.
  factory PixKey.parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw FormatException('chave Pix vazia', input);
    }
    if (trimmed.contains('@')) return PixKey.email(trimmed);
    if (trimmed.startsWith('+')) return PixKey.phone(trimmed);
    if (_uuid.hasMatch(trimmed)) return PixKey.evp(trimmed);

    final document = _stripDocumentMask(trimmed);
    if (document.length == 11) return PixKey.cpf(document);
    if (document.length == 14) return PixKey.cnpj(document);

    throw FormatException(
      'formato de chave Pix não reconhecido: esperado CPF, CNPJ, telefone '
      '(+55...), e-mail ou chave aleatória (UUID)',
      input,
    );
  }

  /// Valida um CPF, com ou sem máscara (`123.456.789-09`).
  factory PixKey.cpf(String input) {
    final digits = _stripDocumentMask(input.trim());
    if (!_cpfPattern.hasMatch(digits)) {
      throw FormatException('CPF deve ter 11 dígitos', input);
    }
    if (_allSameCharacter(digits) || !_hasValidCpfCheckDigits(digits)) {
      throw FormatException('CPF com dígitos verificadores inválidos', input);
    }
    return PixKey._(PixKeyType.cpf, digits);
  }

  /// Valida um CNPJ numérico ou alfanumérico, com ou sem máscara
  /// (`11.222.333/0001-81`, `12.ABC.345/01DE-35`).
  factory PixKey.cnpj(String input) {
    final value = _stripDocumentMask(input.trim()).toUpperCase();
    if (!_cnpjPattern.hasMatch(value)) {
      throw FormatException(
        'CNPJ deve ter 12 caracteres (dígitos ou letras) seguidos de 2 '
        'dígitos verificadores',
        input,
      );
    }
    if (_allSameCharacter(value) || !_hasValidCnpjCheckDigits(value)) {
      throw FormatException('CNPJ com dígitos verificadores inválidos', input);
    }
    return PixKey._(PixKeyType.cnpj, value);
  }

  /// Valida um telefone no formato E.164 (`+5511988887777`).
  ///
  /// Espaços, hífens e parênteses são removidos antes da validação.
  factory PixKey.phone(String input) {
    final value = input.trim().replaceAll(RegExp(r'[\s()\-]'), '');
    if (!_phonePattern.hasMatch(value)) {
      throw FormatException(
        'telefone deve estar no formato E.164: "+", código do país e número, '
        'até 15 dígitos (ex.: +5511988887777)',
        input,
      );
    }
    return PixKey._(PixKeyType.phone, value);
  }

  /// Valida um e-mail com até [maxEmailLength] caracteres.
  factory PixKey.email(String input) {
    final value = input.trim().toLowerCase();
    if (value.length > maxEmailLength) {
      throw FormatException(
        'e-mail tem ${value.length} caracteres; o máximo é $maxEmailLength',
        input,
      );
    }
    if (!_emailPattern.hasMatch(value)) {
      throw FormatException('e-mail em formato inválido', input);
    }
    return PixKey._(PixKeyType.email, value);
  }

  /// Valida uma chave aleatória (EVP) no formato UUID.
  factory PixKey.evp(String input) {
    final value = input.trim().toLowerCase();
    if (!_uuid.hasMatch(value)) {
      throw FormatException(
        'chave aleatória deve ser um UUID com 36 caracteres '
        '(ex.: 123e4567-e12b-12d1-a456-426655440000)',
        input,
      );
    }
    return PixKey._(PixKeyType.evp, value);
  }

  /// Como [PixKey.parse], mas devolve `null` em vez de lançar exceção.
  static PixKey? tryParse(String input) {
    try {
      return PixKey.parse(input);
    } on FormatException {
      return null;
    }
  }

  /// Tamanho máximo de uma chave do tipo e-mail.
  static const int maxEmailLength = 77;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final RegExp _cpfPattern = RegExp(r'^\d{11}$');
  static final RegExp _cnpjPattern = RegExp(r'^[0-9A-Z]{12}\d{2}$');
  static final RegExp _phonePattern = RegExp(r'^\+[1-9]\d{1,14}$');
  static final RegExp _emailPattern = RegExp(
    r"^[a-z0-9.!#$&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?"
    r'(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*$',
  );

  /// Tipo detectado ou informado.
  final PixKeyType type;

  /// Valor normalizado, como vai no campo `26.01` do BR Code.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is PixKey && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);

  @override
  String toString() => value;
}

String _stripDocumentMask(String input) => input.replaceAll(
      RegExp(r'[.\-/\s]'),
      '',
    );

bool _allSameCharacter(String value) =>
    value.split('').every((char) => char == value[0]);

bool _hasValidCpfCheckDigits(String cpf) {
  final digits = cpf.codeUnits.map((unit) => unit - 0x30).toList();
  int checkDigit(int length) {
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += digits[i] * (length + 1 - i);
    }
    return (sum * 10) % 11 % 10;
  }

  return checkDigit(9) == digits[9] && checkDigit(10) == digits[10];
}

/// Dígitos verificadores do CNPJ, numérico ou alfanumérico.
///
/// Cada caractere vale seu código ASCII menos 48, então dígitos valem 0 a 9
/// e letras de `A` (17) a `Z` (42), como definido pela Receita Federal.
bool _hasValidCnpjCheckDigits(String cnpj) {
  final values = cnpj.codeUnits.map((unit) => unit - 0x30).toList();
  int checkDigit(int length) {
    var sum = 0;
    var weight = length - 7;
    for (var i = 0; i < length; i++) {
      sum += values[i] * weight;
      weight = weight == 2 ? 9 : weight - 1;
    }
    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }

  return checkDigit(12) == values[12] && checkDigit(13) == values[13];
}
