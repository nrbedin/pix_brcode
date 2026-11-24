import 'package:pix_brcode/pix_brcode.dart';
import 'package:test/test.dart';

/// Payload estático de exemplo do Manual do BR Code (Bacen), com chave EVP e
/// recebedor fictícios.
const reference = '00020126580014br.gov.bcb.pix'
    '0136123e4567-e12b-12d1-a456-426655440000'
    '5204000053039865802BR5913Fulano de Tal6008BRASILIA'
    '62070503***63041D3D';

Matcher throwsParse({String? field, int? offset}) => throwsA(
      isA<PixParseException>()
          .having((e) => e.field, 'field', field)
          .having((e) => e.offset, 'offset', offset),
    );

void main() {
  group('EmvTlv.encode', () {
    test('monta ID, tamanho com 2 dígitos e valor', () {
      expect(EmvTlv.encode('58', 'BR'), '5802BR');
      expect(EmvTlv.encode('59', 'Fulano de Tal'), '5913Fulano de Tal');
    });

    test('aceita o tamanho máximo de 99', () {
      final value = 'a' * 99;
      expect(EmvTlv.encode('25', value), '2599$value');
    });

    test('rejeita valor acima de 99 caracteres', () {
      expect(() => EmvTlv.encode('25', 'a' * 100), throwsArgumentError);
    });

    test('rejeita valor vazio', () {
      expect(() => EmvTlv.encode('05', ''), throwsArgumentError);
    });

    test('rejeita ID que não tem 2 dígitos', () {
      for (final id in ['5', '580', 'AB', '-1']) {
        expect(() => EmvTlv.encode(id, 'x'), throwsArgumentError, reason: id);
      }
    });

    test('EmvField.encode e encodeAll serializam na ordem', () {
      const fields = [EmvField('00', '01'), EmvField('58', 'BR')];
      expect(fields.first.encode(), '000201');
      expect(EmvTlv.encodeAll(fields), '0002015802BR');
    });
  });

  group('EmvTlv.decode', () {
    test('lê o payload de referência campo a campo', () {
      final fields = EmvTlv.decode(reference);
      expect(fields.map((f) => f.id), [
        '00',
        '26',
        '52',
        '53',
        '58',
        '59',
        '60',
        '62',
        '63',
      ]);
      expect(fields[5], const EmvField('59', 'Fulano de Tal'));
      expect(fields.last.value, '1D3D');
    });

    test('lê templates aninhados', () {
      final account = EmvTlv.decode(reference)[1];
      expect(EmvTlv.decode(account.value, parent: '26'), const [
        EmvField('00', 'br.gov.bcb.pix'),
        EmvField('01', '123e4567-e12b-12d1-a456-426655440000'),
      ]);
    });

    test('encode e decode são inversos', () {
      final fields = EmvTlv.decode(reference);
      expect(EmvTlv.encodeAll(fields), reference);
    });

    test('string vazia devolve lista vazia', () {
      expect(EmvTlv.decode(''), isEmpty);
    });

    test('cabeçalho incompleto', () {
      expect(() => EmvTlv.decode('000201580'), throwsParse(offset: 6));
    });

    test('ID não numérico', () {
      expect(() => EmvTlv.decode('000201AB02BR'), throwsParse(offset: 6));
    });

    test('tamanho não numérico aponta o campo', () {
      expect(
        () => EmvTlv.decode('000201580XBR'),
        throwsParse(field: '58', offset: 8),
      );
    });

    test('tamanho 00 é rejeitado', () {
      expect(() => EmvTlv.decode('5800'), throwsParse(field: '58', offset: 2));
    });

    test('valor menor que o tamanho declarado', () {
      expect(
        () => EmvTlv.decode('5905Ana'),
        throwsParse(field: '59', offset: 4),
      );
    });

    test('erro em template aninhado traz o caminho e a posição original', () {
      // Campo 01 do template 26 declara 36 caracteres, mas só tem 5.
      const template = '0014br.gov.bcb.pix0136abcde';
      expect(
        () => EmvTlv.decode(template, parent: '26', baseOffset: 10),
        throwsParse(field: '26.01', offset: 10 + 18 + 4),
      );
    });
  });

  group('PixParseException', () {
    test('toString traz campo, mensagem e posição', () {
      const e = PixParseException('valor inválido', field: '54', offset: 12);
      expect(
        e.toString(),
        'PixParseException (campo 54): valor inválido (posição 12)',
      );
    });

    test('toString sem campo nem posição', () {
      expect(
        const PixParseException('payload vazio').toString(),
        'PixParseException: payload vazio',
      );
    });

    test('é um FormatException', () {
      expect(const PixParseException('x'), isA<FormatException>());
    });
  });
}
