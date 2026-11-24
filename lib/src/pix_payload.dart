import 'crc16.dart';
import 'emv_tlv.dart';
import 'pix_key.dart';

/// IDs dos campos EMV usados pelo BR Code.
abstract final class PixFieldId {
  /// Versão do payload (`01`).
  static const payloadFormat = '00';

  /// Método de iniciação: `11` reutilizável, `12` uso único.
  static const pointOfInitiation = '01';

  /// Template com as informações da conta Pix.
  static const merchantAccount = '26';

  /// GUI do arranjo Pix, dentro do template 26.
  static const gui = '00';

  /// Chave Pix, dentro do template 26.
  static const key = '01';

  /// Informação adicional, dentro do template 26.
  static const description = '02';

  /// URL de cobrança (QR dinâmico), dentro do template 26.
  static const url = '25';

  /// Código de categoria do estabelecimento (MCC).
  static const merchantCategoryCode = '52';

  /// Moeda (ISO 4217).
  static const currency = '53';

  /// Valor da transação.
  static const amount = '54';

  /// País do recebedor.
  static const countryCode = '58';

  /// Nome do recebedor.
  static const merchantName = '59';

  /// Cidade do recebedor.
  static const merchantCity = '60';

  /// CEP do recebedor.
  static const postalCode = '61';

  /// Template de dados adicionais.
  static const additionalData = '62';

  /// Identificador da transação (txid), dentro do template 62.
  static const txid = '05';

  /// CRC16 do payload.
  static const crc = '63';
}

/// Um payload Pix BR Code, estático ([StaticPixPayload]) ou dinâmico
/// ([DynamicPixPayload]).
///
/// Os dois tipos validam os campos na construção e lançam [ArgumentError]
/// com o nome do parâmetro inválido. Textos (nome, cidade, descrição) têm os
/// acentos removidos e precisam ficar em ASCII imprimível.
sealed class PixPayload {
  PixPayload._({
    required String merchantName,
    required String merchantCity,
    required this.amount,
    required String? postalCode,
  })  : merchantName = _text(
          merchantName,
          'merchantName',
          maxLength: maxMerchantNameLength,
        ),
        merchantCity = _text(
          merchantCity,
          'merchantCity',
          maxLength: maxMerchantCityLength,
        ),
        postalCode = _postalCode(postalCode) {
    _checkAmount(amount);
  }

  /// GUI do arranjo Pix no template 26.
  static const String gui = 'br.gov.bcb.pix';

  /// Tamanho máximo do nome do recebedor.
  static const int maxMerchantNameLength = 25;

  /// Tamanho máximo da cidade do recebedor.
  static const int maxMerchantCityLength = 15;

  /// Maior valor que cabe nos 13 caracteres do campo 54.
  static const double maxAmount = 9999999999.99;

  /// Nome do recebedor, sem acentos.
  final String merchantName;

  /// Cidade do recebedor, sem acentos.
  final String merchantCity;

  /// Valor em reais. `null` deixa o pagador escolher o valor.
  final double? amount;

  /// CEP com 8 dígitos, opcional.
  final String? postalCode;

  /// Valor do campo 01, ou `null` para omiti-lo.
  String? get _pointOfInitiation;

  /// Subcampos do template 26, depois do GUI.
  List<EmvField> get _accountFields;

  /// Valor do campo 62.05.
  String get _txidValue;

  /// Monta o payload completo, com o CRC16 no final.
  ///
  /// É a string usada no "Pix Copia e Cola" e no conteúdo do QR Code.
  String encode() {
    final pointOfInitiation = _pointOfInitiation;
    final amount = this.amount;
    final postalCode = this.postalCode;

    final body = EmvTlv.encodeAll([
      const EmvField(PixFieldId.payloadFormat, '01'),
      if (pointOfInitiation != null)
        EmvField(PixFieldId.pointOfInitiation, pointOfInitiation),
      EmvField(
        PixFieldId.merchantAccount,
        EmvTlv.encodeAll([
          const EmvField(PixFieldId.gui, gui),
          ..._accountFields,
        ]),
      ),
      const EmvField(PixFieldId.merchantCategoryCode, '0000'),
      const EmvField(PixFieldId.currency, '986'),
      if (amount != null)
        EmvField(PixFieldId.amount, amount.toStringAsFixed(2)),
      const EmvField(PixFieldId.countryCode, 'BR'),
      EmvField(PixFieldId.merchantName, merchantName),
      EmvField(PixFieldId.merchantCity, merchantCity),
      if (postalCode != null) EmvField(PixFieldId.postalCode, postalCode),
      EmvField(
        PixFieldId.additionalData,
        EmvField(PixFieldId.txid, _txidValue).encode(),
      ),
    ]);

    final withCrcHeader = '$body${PixFieldId.crc}04';
    return '$withCrcHeader${Crc16.hex(withCrcHeader)}';
  }

  @override
  String toString() => encode();
}

/// BR Code estático: a chave Pix vai no próprio payload.
final class StaticPixPayload extends PixPayload {
  /// Cria um payload estático.
  ///
  /// - [description]: informação adicional mostrada ao pagador (campo
  ///   `26.02`), limitada pelo espaço que sobra no template 26.
  /// - [txid]: até 25 caracteres `[A-Za-z0-9]`; `null` usa `***`.
  /// - [singleUse]: marca o QR como de uso único (campo 01 = `12`). Por
  ///   padrão o campo é omitido, o que indica QR reutilizável.
  StaticPixPayload({
    required this.key,
    required super.merchantName,
    required super.merchantCity,
    super.amount,
    String? description,
    String? txid,
    super.postalCode,
    this.singleUse = false,
  })  : description = description == null
            ? null
            : _text(description, 'description', maxLength: 99),
        txid = _txid(txid),
        super._() {
    final description = this.description;
    if (description != null) {
      // GUI (4 + 14) + chave (4 + n) + descrição (4 + m) cabem em 99.
      final available = EmvTlv.maxValueLength - 18 - (4 + key.value.length) - 4;
      if (description.length > available) {
        throw ArgumentError.value(
          description,
          'description',
          'tem ${description.length} caracteres; com esta chave cabem no '
              'máximo ${available < 0 ? 0 : available}',
        );
      }
    }
  }

  /// Tamanho máximo do txid em um BR Code estático.
  static const int maxTxidLength = 25;

  /// Chave Pix do recebedor.
  final PixKey key;

  /// Informação adicional, sem acentos.
  final String? description;

  /// Identificador da transação, ou `null` quando ausente (`***`).
  final String? txid;

  /// Se o QR é de uso único.
  final bool singleUse;

  @override
  String? get _pointOfInitiation => singleUse ? '12' : null;

  @override
  List<EmvField> get _accountFields {
    final description = this.description;
    return [
      EmvField(PixFieldId.key, key.value),
      if (description != null) EmvField(PixFieldId.description, description),
    ];
  }

  @override
  String get _txidValue => txid ?? '***';
}

/// BR Code dinâmico: o payload aponta para uma URL de cobrança no PSP.
final class DynamicPixPayload extends PixPayload {
  /// Cria um payload dinâmico.
  ///
  /// [url] é a localização da cobrança. O prefixo `https://`, se houver, é
  /// removido, porque o BR Code guarda a URL sem o esquema.
  DynamicPixPayload({
    required String url,
    required super.merchantName,
    required super.merchantCity,
    super.amount,
    super.postalCode,
  })  : url = _url(url),
        super._();

  /// Tamanho máximo da URL, sem `https://`.
  static const int maxUrlLength = 77;

  /// URL da cobrança, sem `https://`.
  final String url;

  @override
  String? get _pointOfInitiation => '12';

  @override
  List<EmvField> get _accountFields => [EmvField(PixFieldId.url, url)];

  @override
  String get _txidValue => '***';
}

const Map<String, String> _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n', //
  'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', //
  'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E', //
  'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I', //
  'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O', //
  'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', //
  'Ç': 'C', 'Ñ': 'N',
};

final RegExp _printableAscii = RegExp(r'^[\x20-\x7E]+$');
final RegExp _txidPattern = RegExp(r'^[A-Za-z0-9]+$');
final RegExp _postalCodePattern = RegExp(r'^\d{8}$');

/// Remove acentos, apara espaços e valida tamanho e caracteres.
String _text(String input, String name, {required int maxLength}) {
  final value =
      input.trim().split('').map((char) => _accents[char] ?? char).join();
  if (value.isEmpty) {
    throw ArgumentError.value(input, name, 'não pode ser vazio');
  }
  if (!_printableAscii.hasMatch(value)) {
    throw ArgumentError.value(
      input,
      name,
      'só aceita letras sem acento, números, espaços e símbolos ASCII',
    );
  }
  if (value.length > maxLength) {
    throw ArgumentError.value(
      input,
      name,
      'tem ${value.length} caracteres; o máximo é $maxLength',
    );
  }
  return value;
}

void _checkAmount(double? amount) {
  if (amount == null) return;
  if (amount.isNaN || amount.isInfinite || amount <= 0) {
    throw ArgumentError.value(amount, 'amount', 'deve ser maior que zero');
  }
  if (amount > PixPayload.maxAmount) {
    throw ArgumentError.value(
      amount,
      'amount',
      'o máximo é ${PixPayload.maxAmount.toStringAsFixed(2)}',
    );
  }
  if (amount.toStringAsFixed(2) == '0.00') {
    throw ArgumentError.value(
      amount,
      'amount',
      'arredondado para 2 casas fica zero',
    );
  }
}

String? _postalCode(String? input) {
  if (input == null) return null;
  final digits = input.trim().replaceAll('-', '');
  if (!_postalCodePattern.hasMatch(digits)) {
    throw ArgumentError.value(input, 'postalCode', 'CEP deve ter 8 dígitos');
  }
  return digits;
}

String? _txid(String? input) {
  if (input == null) return null;
  final value = input.trim();
  if (value == '***') return null;
  if (!_txidPattern.hasMatch(value)) {
    throw ArgumentError.value(
      input,
      'txid',
      'só aceita letras sem acento e números',
    );
  }
  if (value.length > StaticPixPayload.maxTxidLength) {
    throw ArgumentError.value(
      input,
      'txid',
      'tem ${value.length} caracteres; o máximo é '
          '${StaticPixPayload.maxTxidLength}',
    );
  }
  return value;
}

String _url(String input) {
  var value = input.trim();
  if (value.toLowerCase().startsWith('https://')) {
    value = value.substring('https://'.length);
  }
  if (value.isEmpty) {
    throw ArgumentError.value(input, 'url', 'não pode ser vazia');
  }
  if (value.contains('://')) {
    throw ArgumentError.value(input, 'url', 'só aceita https');
  }
  if (!RegExp(r'^[\x21-\x7E]+$').hasMatch(value)) {
    throw ArgumentError.value(
      input,
      'url',
      'não pode ter espaços nem caracteres fora do ASCII',
    );
  }
  if (value.length > DynamicPixPayload.maxUrlLength) {
    throw ArgumentError.value(
      input,
      'url',
      'tem ${value.length} caracteres sem https://; o máximo é '
          '${DynamicPixPayload.maxUrlLength}',
    );
  }
  return value;
}
