import 'package:pix_brcode/pix_brcode.dart';
import 'package:test/test.dart';

// Todos os documentos e contatos abaixo são fictícios: CPF e CNPJ de exemplo
// com dígitos verificadores válidos, telefone e e-mail inventados.
const cpf = '12345678909';
const cnpj = '11222333000181';
const cnpjAlfanumerico = '12ABC34501DE35';
const evp = '123e4567-e12b-12d1-a456-426655440000';

Matcher throwsFormat(String messagePart) => throwsA(
      isA<FormatException>().having(
        (e) => e.message,
        'message',
        contains(messagePart),
      ),
    );

void main() {
  group('PixKey.parse detecta o tipo', () {
    final cases = {
      '123.456.789-09': (PixKeyType.cpf, cpf),
      cpf: (PixKeyType.cpf, cpf),
      '11.222.333/0001-81': (PixKeyType.cnpj, cnpj),
      '12.abc.345/01de-35': (PixKeyType.cnpj, cnpjAlfanumerico),
      '+55 (11) 98888-7777': (PixKeyType.phone, '+5511988887777'),
      ' Fulano@Exemplo.com.br ': (PixKeyType.email, 'fulano@exemplo.com.br'),
      evp.toUpperCase(): (PixKeyType.evp, evp),
    };

    cases.forEach((input, expected) {
      test('"$input" → ${expected.$1.name}', () {
        final key = PixKey.parse(input);
        expect(key.type, expected.$1);
        expect(key.value, expected.$2);
      });
    });

    test('rejeita chave vazia', () {
      expect(() => PixKey.parse('   '), throwsFormat('vazia'));
    });

    test('rejeita formato desconhecido', () {
      expect(() => PixKey.parse('12345'), throwsFormat('não reconhecido'));
      expect(() => PixKey.parse('fulano'), throwsFormat('não reconhecido'));
    });
  });

  group('CPF', () {
    test('rejeita dígito verificador errado', () {
      expect(() => PixKey.cpf('12345678900'), throwsFormat('verificadores'));
      expect(() => PixKey.cpf('12345678919'), throwsFormat('verificadores'));
    });

    test('rejeita todos os dígitos iguais', () {
      expect(() => PixKey.cpf('11111111111'), throwsFormat('verificadores'));
    });

    test('rejeita tamanho ou caracteres errados', () {
      expect(() => PixKey.cpf('1234567890'), throwsFormat('11 dígitos'));
      expect(() => PixKey.cpf('1234567890A'), throwsFormat('11 dígitos'));
    });

    test('dígito verificador 0 quando o resto é 10', () {
      // 100000001: soma 1×10 + 1×2 = 12; 12×10 mod 11 = 10, então o
      // primeiro dígito verificador é 0.
      expect(PixKey.cpf('100.000.001-08').value, '10000000108');
      expect(() => PixKey.cpf('10000000118'), throwsFormat('verificadores'));
    });
  });

  group('CNPJ', () {
    test('aceita numérico e alfanumérico', () {
      expect(PixKey.cnpj(cnpj).value, cnpj);
      expect(PixKey.cnpj('12ABC34501DE35').value, cnpjAlfanumerico);
    });

    test('rejeita dígito verificador errado', () {
      expect(
          () => PixKey.cnpj('11222333000180'), throwsFormat('verificadores'));
      expect(
          () => PixKey.cnpj('11222333000191'), throwsFormat('verificadores'));
      expect(
          () => PixKey.cnpj('12ABC34501DE36'), throwsFormat('verificadores'));
    });

    test('rejeita todos os caracteres iguais', () {
      expect(
          () => PixKey.cnpj('00000000000000'), throwsFormat('verificadores'));
    });

    test('rejeita letras nos dígitos verificadores', () {
      expect(
          () => PixKey.cnpj('12ABC34501DE3A'), throwsFormat('12 caracteres'));
    });

    test('rejeita tamanho errado', () {
      expect(() => PixKey.cnpj('1122233300018'), throwsFormat('12 caracteres'));
    });
  });

  group('telefone', () {
    test('aceita E.164 e remove separadores', () {
      expect(PixKey.phone('+5511988887777').value, '+5511988887777');
      expect(PixKey.phone('+55 11 98888-7777').value, '+5511988887777');
    });

    test('rejeita sem "+", com código 0 ou longo demais', () {
      expect(() => PixKey.phone('5511988887777'), throwsFormat('E.164'));
      expect(() => PixKey.phone('+0511988887777'), throwsFormat('E.164'));
      expect(() => PixKey.phone('+5511988887777123'), throwsFormat('E.164'));
      expect(() => PixKey.phone('+55119888a7777'), throwsFormat('E.164'));
    });
  });

  group('e-mail', () {
    test('normaliza para minúsculas', () {
      expect(PixKey.email('Fulano.Tal@Exemplo.COM').value,
          'fulano.tal@exemplo.com');
    });

    test('aceita exatamente 77 caracteres', () {
      final email = '${'a' * 65}@exemplo.com';
      expect(email, hasLength(77));
      expect(PixKey.email(email).value, email);
    });

    test('rejeita acima de 77 caracteres', () {
      expect(
        () => PixKey.email('${'a' * 66}@exemplo.com'),
        throwsFormat('máximo é 77'),
      );
    });

    test('rejeita formatos inválidos', () {
      for (final email in [
        '@exemplo.com',
        'fulano@',
        'fulano@-exemplo.com',
        'ful ano@exemplo.com',
        'fulano@@exemplo.com',
      ]) {
        expect(
          () => PixKey.email(email),
          throwsFormat('formato inválido'),
          reason: email,
        );
      }
    });
  });

  group('EVP', () {
    test('normaliza para minúsculas', () {
      expect(PixKey.evp(evp.toUpperCase()).value, evp);
    });

    test('rejeita UUID mal formado', () {
      expect(() => PixKey.evp(evp.replaceAll('-', '')), throwsFormat('UUID'));
      expect(() => PixKey.evp('${evp}0'), throwsFormat('UUID'));
      expect(
        () => PixKey.evp(evp.replaceFirst('1', 'g')),
        throwsFormat('UUID'),
      );
    });
  });

  group('tryParse, igualdade e toString', () {
    test('tryParse devolve null em vez de lançar', () {
      expect(PixKey.tryParse('inválida'), isNull);
      expect(PixKey.tryParse(cpf)?.type, PixKeyType.cpf);
    });

    test('chaves com mesmo tipo e valor são iguais', () {
      expect(PixKey.parse('123.456.789-09'), PixKey.cpf(cpf));
      expect(PixKey.parse(cpf).hashCode, PixKey.cpf(cpf).hashCode);
      expect(PixKey.parse(cpf), isNot(PixKey.parse(cnpj)));
    });

    test('toString devolve o valor normalizado', () {
      expect(PixKey.parse('+55 11 98888-7777').toString(), '+5511988887777');
    });
  });
}
