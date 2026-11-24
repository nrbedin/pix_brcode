import 'package:pix_brcode/pix_brcode.dart';
import 'package:test/test.dart';

// Dados fictícios.
const evp = '123e4567-e12b-12d1-a456-426655440000';

/// Payload estático de exemplo do Manual do BR Code (Bacen).
const reference = '00020126580014br.gov.bcb.pix'
    '0136123e4567-e12b-12d1-a456-426655440000'
    '5204000053039865802BR5913Fulano de Tal6008BRASILIA'
    '62070503***63041D3D';

Matcher throwsArg(String name, [String? messagePart]) => throwsA(
      isA<ArgumentError>().having((e) => e.name, 'name', name).having(
            (e) => e.message.toString(),
            'message',
            contains(messagePart ?? ''),
          ),
    );

/// Lê os campos de primeiro nível do payload, em um mapa ID → valor.
Map<String, String> fieldsOf(String payload) => {
      for (final field in EmvTlv.decode(payload)) field.id: field.value,
    };

Map<String, String> subfieldsOf(String payload, String id) => {
      for (final field in EmvTlv.decode(fieldsOf(payload)[id]!))
        field.id: field.value,
    };

StaticPixPayload staticPayload({
  String key = evp,
  String name = 'Fulano de Tal',
  String city = 'BRASILIA',
  double? amount,
  String? description,
  String? txid,
  String? postalCode,
  bool singleUse = false,
}) =>
    StaticPixPayload(
      key: PixKey.parse(key),
      merchantName: name,
      merchantCity: city,
      amount: amount,
      description: description,
      txid: txid,
      postalCode: postalCode,
      singleUse: singleUse,
    );

void main() {
  group('StaticPixPayload.encode', () {
    test('reproduz o payload de referência do manual', () {
      expect(staticPayload().encode(), reference);
    });

    test('toString devolve o payload', () {
      expect(staticPayload().toString(), reference);
    });

    test('inclui valor com 2 casas, txid e descrição', () {
      final payload = staticPayload(
        amount: 10.5,
        txid: 'PEDIDO123',
        description: 'Pedido 123',
      ).encode();

      expect(Crc16.isValid(payload), isTrue);
      expect(fieldsOf(payload)['54'], '10.50');
      expect(subfieldsOf(payload, '62'), {'05': 'PEDIDO123'});
      expect(subfieldsOf(payload, '26'), {
        '00': 'br.gov.bcb.pix',
        '01': evp,
        '02': 'Pedido 123',
      });
    });

    test('mantém a ordem dos campos do manual', () {
      final payload = staticPayload(
        amount: 1,
        postalCode: '01310-100',
        singleUse: true,
      ).encode();
      expect(EmvTlv.decode(payload).map((f) => f.id), [
        '00',
        '01',
        '26',
        '52',
        '53',
        '54',
        '58',
        '59',
        '60',
        '61',
        '62',
        '63',
      ]);
      expect(fieldsOf(payload)['01'], '12');
      expect(fieldsOf(payload)['61'], '01310100');
    });

    test('omite o campo 01 quando reutilizável', () {
      expect(fieldsOf(staticPayload().encode()).containsKey('01'), isFalse);
    });

    test('usa o valor normalizado da chave', () {
      final payload = staticPayload(key: '+55 (11) 98888-7777').encode();
      expect(subfieldsOf(payload, '26')['01'], '+5511988887777');
    });

    test('remove acentos de nome, cidade e descrição', () {
      final payload = staticPayload(
        name: 'José Conceição',
        city: 'São Paulo',
        description: 'Café',
      );
      expect(payload.merchantName, 'Jose Conceicao');
      expect(payload.merchantCity, 'Sao Paulo');
      expect(payload.description, 'Cafe');
      expect(Crc16.isValid(payload.encode()), isTrue);
    });

    test('txid "***" equivale a nenhum txid', () {
      expect(staticPayload(txid: '***').txid, isNull);
      expect(staticPayload(txid: '***').encode(), reference);
    });
  });

  group('StaticPixPayload valida', () {
    test('nome e cidade vazios ou longos demais', () {
      expect(() => staticPayload(name: '  '), throwsArg('merchantName'));
      expect(
        () => staticPayload(name: 'a' * 26),
        throwsArg('merchantName', 'máximo é 25'),
      );
      expect(staticPayload(name: 'a' * 25).merchantName, hasLength(25));
      expect(
        () => staticPayload(city: 'a' * 16),
        throwsArg('merchantCity', 'máximo é 15'),
      );
    });

    test('caracteres fora do ASCII', () {
      expect(() => staticPayload(name: 'Loja 😀'), throwsArg('merchantName'));
      expect(() => staticPayload(city: 'Łódź'), throwsArg('merchantCity'));
      expect(staticPayload(city: 'Kraków').merchantCity, 'Krakow');
    });

    test('valor', () {
      for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => staticPayload(amount: amount),
          throwsArg('amount', 'maior que zero'),
          reason: '$amount',
        );
      }
      expect(() => staticPayload(amount: 0.001), throwsArg('amount', 'zero'));
      expect(
        () => staticPayload(amount: 10000000000),
        throwsArg('amount', 'máximo'),
      );
      expect(
        fieldsOf(staticPayload(amount: PixPayload.maxAmount).encode())['54'],
        '9999999999.99',
      );
    });

    test('txid', () {
      expect(staticPayload(txid: 'a' * 25).txid, hasLength(25));
      expect(() => staticPayload(txid: 'a' * 26), throwsArg('txid', '25'));
      expect(() => staticPayload(txid: 'PED-1'), throwsArg('txid', 'letras'));
    });

    test('CEP', () {
      expect(() => staticPayload(postalCode: '1234'), throwsArg('postalCode'));
      expect(
        () => staticPayload(postalCode: '0131010A'),
        throwsArg('postalCode'),
      );
    });

    test('descrição limitada pelo espaço no template 26', () {
      // GUI (18) + chave EVP (4 + 36) + cabeçalho da descrição (4) = 62.
      expect(staticPayload(description: 'a' * 37).description, hasLength(37));
      expect(
        () => staticPayload(description: 'a' * 38),
        throwsArg('description', 'cabem no máximo 37'),
      );
    });

    test('descrição não cabe com e-mail de 77 caracteres', () {
      final email = '${'a' * 65}@exemplo.com';
      expect(
        () => staticPayload(key: email, description: 'x'),
        throwsArg('description', 'cabem no máximo 0'),
      );
    });
  });

  group('DynamicPixPayload', () {
    const url = 'pix.exemplo.com.br/qr/v2/9d36b84fc70b478fb95c12729b90ca25';

    DynamicPixPayload dynamicPayload({String url = url, double? amount}) =>
        DynamicPixPayload(
          url: url,
          merchantName: 'Fulano de Tal',
          merchantCity: 'BRASILIA',
          amount: amount,
        );

    test('usa URL no template 26, campo 01 = 12 e txid ***', () {
      final payload = dynamicPayload().encode();
      expect(Crc16.isValid(payload), isTrue);
      expect(fieldsOf(payload)['01'], '12');
      expect(subfieldsOf(payload, '26'), {
        '00': 'br.gov.bcb.pix',
        '25': url,
      });
      expect(subfieldsOf(payload, '62'), {'05': '***'});
    });

    test('aceita valor', () {
      expect(fieldsOf(dynamicPayload(amount: 99.9).encode())['54'], '99.90');
    });

    test('remove https:// da URL', () {
      expect(dynamicPayload(url: 'HTTPS://$url').url, url);
    });

    test('rejeita URL vazia, com outro esquema, espaços ou longa demais', () {
      expect(() => dynamicPayload(url: 'https://'), throwsArg('url', 'vazia'));
      expect(
        () => dynamicPayload(url: 'http://$url'),
        throwsArg('url', 'https'),
      );
      expect(
        () => dynamicPayload(url: 'pix.exemplo.com/a b'),
        throwsArg('url', 'espaços'),
      );
      expect(dynamicPayload(url: 'a' * 77).url, hasLength(77));
      expect(
        () => dynamicPayload(url: 'a' * 78),
        throwsArg('url', 'máximo é 77'),
      );
    });
  });
}
