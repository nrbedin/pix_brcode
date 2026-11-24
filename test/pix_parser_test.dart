import 'package:pix_brcode/pix_brcode.dart';
import 'package:test/test.dart';

// Dados fictícios.
const evp = '123e4567-e12b-12d1-a456-426655440000';
const url = 'pix.exemplo.com.br/qr/v2/9d36b84fc70b478fb95c12729b90ca25';

/// Payload estático de exemplo do Manual do BR Code (Bacen).
const reference = '00020126580014br.gov.bcb.pix'
    '0136123e4567-e12b-12d1-a456-426655440000'
    '5204000053039865802BR5913Fulano de Tal6008BRASILIA'
    '62070503***63041D3D';

String tlv(List<(String, String)> fields) =>
    fields.map((f) => EmvTlv.encode(f.$1, f.$2)).join();

/// Acrescenta `6304` e o CRC16 correto a [body].
String withCrc(String body) => '${body}6304${Crc16.hex('${body}6304')}';

/// Monta um payload com CRC válido a partir dos campos do exemplo do manual.
///
/// [changes] troca o valor de um campo (ou remove, com `null`); [extra] é
/// acrescentado no fim, antes do CRC.
String pix({
  Map<String, String?> changes = const {},
  List<(String, String)> extra = const [],
}) {
  final base = <(String, String)>[
    ('00', '01'),
    ('26', tlv([('00', 'br.gov.bcb.pix'), ('01', evp)])),
    ('52', '0000'),
    ('53', '986'),
    ('58', 'BR'),
    ('59', 'Fulano de Tal'),
    ('60', 'BRASILIA'),
    ('62', tlv([('05', '***')])),
  ];
  final fields = [
    for (final (id, value) in base)
      if (!changes.containsKey(id))
        (id, value)
      else if (changes[id] != null)
        (id, changes[id]!),
    ...extra,
  ];
  return withCrc(tlv(fields));
}

String account(List<(String, String)> subfields) => tlv(subfields);

Matcher throwsParse(String? field, {String? message, int? offset}) => throwsA(
      isA<PixParseException>()
          .having((e) => e.field, 'field', field)
          .having((e) => e.message, 'message', contains(message ?? ''))
          .having(
            (e) => e.offset,
            'offset',
            offset == null ? anything : equals(offset),
          ),
    );

void main() {
  group('PixPayload.parse com o payload de referência', () {
    late PixPayload payload;
    setUp(() => payload = PixPayload.parse(reference));

    test('devolve um StaticPixPayload com os campos do manual', () {
      expect(payload, isA<StaticPixPayload>());
      final static = payload as StaticPixPayload;
      expect(static.key.type, PixKeyType.evp);
      expect(static.key.value, evp);
      expect(static.merchantName, 'Fulano de Tal');
      expect(static.merchantCity, 'BRASILIA');
      expect(static.amount, isNull);
      expect(static.txid, isNull);
      expect(static.description, isNull);
      expect(static.postalCode, isNull);
      expect(static.singleUse, isFalse);
    });

    test('encode devolve a mesma string', () {
      expect(payload.encode(), reference);
    });

    test('aceita CRC em minúsculas e espaços nas pontas', () {
      final lower = '${reference.substring(0, reference.length - 4)}1d3d';
      expect(PixPayload.parse('  $lower\n').encode(), reference);
    });
  });

  group('ida e volta (encode → parse → encode)', () {
    final payloads = <String, PixPayload>{
      'estático completo': StaticPixPayload(
        key: PixKey.parse('fulano@exemplo.com.br'),
        merchantName: 'Fulano de Tal',
        merchantCity: 'Sao Paulo',
        amount: 1234.56,
        description: 'Pedido 42',
        txid: 'PEDIDO42',
        postalCode: '01310100',
        singleUse: true,
      ),
      'estático com CPF': StaticPixPayload(
        key: PixKey.parse('123.456.789-09'),
        merchantName: 'Fulano de Tal',
        merchantCity: 'Recife',
        amount: 0.01,
      ),
      'dinâmico': DynamicPixPayload(
        url: url,
        merchantName: 'Loja Exemplo',
        merchantCity: 'Curitiba',
        amount: 99.9,
        postalCode: '80000000',
      ),
    };

    payloads.forEach((name, original) {
      test(name, () {
        final encoded = original.encode();
        final parsed = PixPayload.parse(encoded);
        expect(parsed.runtimeType, original.runtimeType);
        expect(parsed.encode(), encoded);
        expect(parsed.amount, original.amount);
        expect(parsed.postalCode, original.postalCode);
      });
    });

    test('dinâmico devolve a URL', () {
      final parsed = PixPayload.parse(payloads['dinâmico']!.encode());
      expect((parsed as DynamicPixPayload).url, url);
    });

    test('estático preserva txid, descrição e uso único', () {
      final parsed = PixPayload.parse(payloads['estático completo']!.encode())
          as StaticPixPayload;
      expect(parsed.txid, 'PEDIDO42');
      expect(parsed.description, 'Pedido 42');
      expect(parsed.singleUse, isTrue);
      expect(parsed.key.type, PixKeyType.email);
    });
  });

  group('tolerância', () {
    test('campo 01 = 11 é reutilizável', () {
      final parsed = PixPayload.parse(pix(extra: [('01', '11')]));
      expect((parsed as StaticPixPayload).singleUse, isFalse);
    });

    test('valor sem casas ou com 1 casa decimal', () {
      expect(PixPayload.parse(pix(extra: [('54', '10')])).amount, 10.0);
      expect(PixPayload.parse(pix(extra: [('54', '10.5')])).amount, 10.5);
    });

    test('ignora campos desconhecidos', () {
      final parsed = PixPayload.parse(
        pix(extra: [
          ('27', tlv([('00', 'outro.arranjo')])),
          ('80', 'x')
        ]),
      );
      expect(parsed, isA<StaticPixPayload>());
    });

    test('GUI em maiúsculas e campo 62 ausente', () {
      final payload = pix(changes: {
        '26': account([('00', 'BR.GOV.BCB.PIX'), ('01', evp)]),
        '62': null,
      });
      expect((PixPayload.parse(payload) as StaticPixPayload).txid, isNull);
    });

    test('aceita MCC diferente de 0000', () {
      expect(PixPayload.parse(pix(changes: {'52': '5812'})), isNotNull);
    });
  });

  group('tryParse', () {
    test('devolve null para payload inválido', () {
      expect(PixPayload.tryParse('inválido'), isNull);
      expect(PixPayload.tryParse(reference), isA<StaticPixPayload>());
    });
  });

  group('erros de estrutura', () {
    test('payload vazio', () {
      expect(
          () => PixPayload.parse('   '), throwsParse(null, message: 'vazio'));
    });

    test('erro de TLV é repassado', () {
      expect(() => PixPayload.parse('0002'), throwsParse('00', offset: 4));
    });

    test('CRC errado', () {
      final wrong = '${reference.substring(0, reference.length - 4)}0000';
      expect(
        () => PixPayload.parse(wrong),
        throwsParse('63', message: 'calculado 1D3D', offset: wrong.length - 4),
      );
    });

    test('payload alterado é pego pelo CRC', () {
      final tampered = reference.replaceFirst('BRASILIA', 'BRASILIB');
      expect(() => PixPayload.parse(tampered), throwsParse('63'));
    });

    test('sem CRC no final', () {
      final body = tlv([('00', '01'), ('59', 'Fulano')]);
      expect(() => PixPayload.parse(body), throwsParse('63'));
      expect(
        () => PixPayload.parse('${withCrc(body)}5802BR'),
        throwsParse('63', message: 'terminar'),
      );
    });

    test('CRC com tamanho diferente de 4', () {
      expect(
        () => PixPayload.parse('0002016303ABC'),
        throwsParse('63', message: '4 caracteres'),
      );
    });

    test('não começa pela versão', () {
      expect(
        () =>
            PixPayload.parse(pix(changes: {'00': null}, extra: [('00', '01')])),
        throwsParse('00', message: 'começar', offset: 0),
      );
    });

    test('versão diferente de 01', () {
      expect(
        () => PixPayload.parse(pix(changes: {'00': '02'})),
        throwsParse('00', message: '"02"', offset: 4),
      );
    });

    test('campo repetido', () {
      expect(
        () => PixPayload.parse(pix(extra: [('59', 'Outro Nome')])),
        throwsParse('59', message: 'repetido'),
      );
    });
  });

  group('erros no template 26', () {
    test('ausente', () {
      expect(
        () => PixPayload.parse(pix(changes: {'26': null})),
        throwsParse('26', message: 'ausente'),
      );
    });

    test('TLV interno quebrado traz o caminho', () {
      final broken = '${account([('00', 'br.gov.bcb.pix')])}01';
      expect(
        () => PixPayload.parse(pix(changes: {'26': broken})),
        throwsParse('26', message: 'cabeçalho'),
      );
    });

    test('GUI errado ou ausente', () {
      expect(
        () => PixPayload.parse(pix(changes: {
          '26': account([('00', 'br.gov.bcb.xyz'), ('01', evp)]),
        })),
        throwsParse('26.00', message: 'br.gov.bcb.xyz', offset: 14),
      );
      expect(
        () => PixPayload.parse(pix(changes: {
          '26': account([('01', evp)])
        })),
        throwsParse('26.00', offset: 10),
      );
    });

    test('chave e URL ao mesmo tempo', () {
      final both = account([
        ('00', 'br.gov.bcb.pix'),
        ('01', evp),
        ('25', 'pix.exemplo.com/c/1'),
      ]);
      expect(
        () => PixPayload.parse(pix(changes: {'26': both})),
        throwsParse('26', message: 'só uma'),
      );
    });

    test('sem chave nem URL', () {
      expect(
        () => PixPayload.parse(pix(changes: {
          '26': account([('00', 'br.gov.bcb.pix')]),
        })),
        throwsParse('26', message: 'sem chave'),
      );
    });

    test('chave inválida aponta 26.01 e a posição da chave', () {
      const badKey = '12345678900';
      final payload = pix(changes: {
        '26': account([('00', 'br.gov.bcb.pix'), ('01', badKey)]),
      });
      expect(
        () => PixPayload.parse(payload),
        throwsParse(
          '26.01',
          message: 'verificadores',
          offset: payload.indexOf(badKey),
        ),
      );
    });

    test('descrição com caractere fora do ASCII aponta 26.02', () {
      // O limite de 99 do template já impede descrição longa demais, então
      // o erro alcançável aqui é o de caracteres.
      final payload = pix(changes: {
        '26': account([
          ('00', 'br.gov.bcb.pix'),
          ('01', evp),
          ('02', 'Pedido ✓'),
        ]),
      });
      expect(
        () => PixPayload.parse(payload),
        throwsParse('26.02', offset: payload.indexOf('Pedido')),
      );
    });

    test('URL com outro esquema aponta 26.25', () {
      final payload = pix(changes: {
        '26': account([('00', 'br.gov.bcb.pix'), ('25', 'http://$url')]),
      });
      expect(() => PixPayload.parse(payload), throwsParse('26.25'));
    });
  });

  group('erros nos demais campos', () {
    final cases = <String,
        (Map<String, String?>, List<(String, String)>, String, String)>{
      'moeda diferente de 986': ({'53': '840'}, [], '53', '986'),
      'país diferente de BR': ({'58': 'US'}, [], '58', 'BR'),
      'MCC não numérico': ({'52': 'ABCD'}, [], '52', '4 dígitos'),
      'nome ausente': ({'59': null}, [], '59', 'obrigatório'),
      'cidade ausente': ({'60': null}, [], '60', 'obrigatório'),
      'moeda ausente': ({'53': null}, [], '53', 'obrigatório'),
      'método de iniciação inválido': ({}, [('01', '13')], '01', '"13"'),
      'valor com vírgula': ({}, [('54', '10,50')], '54', 'ponto'),
      'valor com 3 casas': ({}, [('54', '1.234')], '54', 'ponto'),
      'valor zero': ({}, [('54', '0.00')], '54', 'maior que zero'),
      'nome longo demais': ({'59': 'a' * 26}, [], '59', 'máximo é 25'),
      'cidade longa demais': ({'60': 'a' * 16}, [], '60', 'máximo é 15'),
      'CEP inválido': ({}, [('61', '123')], '61', '8 dígitos'),
      'txid inválido': (
        {
          '62': tlv([('05', 'PED-1')])
        },
        [],
        '62.05',
        'letras'
      ),
    };

    cases.forEach((name, c) {
      test(name, () {
        final (changes, extra, field, message) = c;
        expect(
          () => PixPayload.parse(pix(changes: changes, extra: extra)),
          throwsParse(field, message: message),
        );
      });
    });

    test('erro de campo traz a posição do valor', () {
      final payload = pix(changes: {'59': 'a' * 26});
      expect(
        () => PixPayload.parse(payload),
        throwsParse('59', offset: payload.indexOf('a' * 26)),
      );
    });
  });
}
