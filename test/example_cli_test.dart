import 'package:pix_brcode/pix_brcode.dart';
import 'package:test/test.dart';

import '../example/main.dart';

// Dados fictícios.
const evp = '123e4567-e12b-12d1-a456-426655440000';
const reference = '00020126580014br.gov.bcb.pix'
    '0136123e4567-e12b-12d1-a456-426655440000'
    '5204000053039865802BR5913Fulano de Tal6008BRASILIA'
    '62070503***63041D3D';

typedef Result = ({int code, String out, String err});

Result run(List<String> args) {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = runCli(args, out, err);
  return (code: code, out: out.toString(), err: err.toString());
}

void main() {
  group('ajuda e uso incorreto', () {
    test('sem argumentos ou com --help mostra a ajuda', () {
      for (final args in [
        <String>[],
        ['--help'],
        ['-h']
      ]) {
        final r = run(args);
        expect(r.code, 0, reason: '$args');
        expect(r.out, contains('Uso:'));
      }
    });

    test('opção desconhecida, argumento solto e valor faltando', () {
      for (final (args, message) in [
        (['--chave', evp], 'desconhecida --chave'),
        ([evp], 'inesperado'),
        (['--key'], 'precisa de um valor'),
        (['--help=sim'], 'não recebe valor'),
      ]) {
        final r = run(args);
        expect(r.code, exitUsage, reason: '$args');
        expect(r.err, contains(message));
        expect(r.err, contains('Uso:'));
      }
    });

    test('exige exatamente um modo', () {
      expect(run(['--amount', '10']).code, exitUsage);
      expect(
          run(['--key', evp, '--url', 'pix.exemplo.com/c/1']).code, exitUsage);
    });

    test('opções de estático não valem com --url', () {
      final r = run(['--url', 'pix.exemplo.com/c/1', '--txid', 'ABC']);
      expect(r.code, exitUsage);
      expect(r.err, contains('só valem com --key'));
    });
  });

  group('gerar', () {
    test('com só a chave reproduz o exemplo do manual', () {
      final r = run(['--key', evp]);
      expect(r.code, 0);
      expect(r.out.trim(), reference);
    });

    test('aceita --opção=valor e vírgula no valor', () {
      final r = run(['--key=$evp', '--amount=10,50', '--txid', 'PEDIDO1']);
      expect(r.code, 0);
      final payload = PixPayload.parse(r.out.trim()) as StaticPixPayload;
      expect(payload.amount, 10.5);
      expect(payload.txid, 'PEDIDO1');
    });

    test('repassa nome, cidade, descrição, CEP e uso único', () {
      final r = run([
        '--key', '+55 11 98888-7777', //
        '--name', 'Loja Exemplo',
        '--city', 'São Paulo',
        '--description', 'Pedido 7',
        '--cep', '01310-100',
        '--single-use',
      ]);
      expect(r.code, 0);
      final payload = PixPayload.parse(r.out.trim()) as StaticPixPayload;
      expect(payload.key.value, '+5511988887777');
      expect(payload.merchantName, 'Loja Exemplo');
      expect(payload.merchantCity, 'Sao Paulo');
      expect(payload.description, 'Pedido 7');
      expect(payload.postalCode, '01310100');
      expect(payload.singleUse, isTrue);
    });

    test('dinâmico', () {
      final r = run(['--url', 'https://pix.exemplo.com/c/1', '--amount', '5']);
      expect(r.code, 0);
      final payload = PixPayload.parse(r.out.trim()) as DynamicPixPayload;
      expect(payload.url, 'pix.exemplo.com/c/1');
      expect(payload.amount, 5);
    });

    test('erros de dados devolvem 65 com mensagem', () {
      for (final (args, message) in [
        (['--key', '12345678900'], 'Erro na chave Pix: CPF'),
        (['--key', evp, '--amount', 'dez'], 'valor inválido'),
        (['--key', evp, '--amount', '0'], '--amount'),
        (['--key', evp, '--name', 'a' * 26], '--name'),
        (['--key', evp, '--city', 'a' * 16], '--city'),
        (['--key', evp, '--cep', '123'], '--cep'),
        (['--url', 'http://pix.exemplo.com'], '--url'),
      ]) {
        final r = run(args);
        expect(r.code, exitData, reason: '$args');
        expect(r.err, contains(message), reason: '$args');
      }
    });
  });

  group('ler', () {
    test('mostra os campos do exemplo do manual', () {
      final r = run(['--parse', reference]);
      expect(r.code, 0);
      expect(r.out, contains('Tipo:       estático'));
      expect(r.out, contains('Chave:      $evp (aleatória)'));
      expect(r.out, contains('Recebedor:  Fulano de Tal'));
      expect(r.out, contains('Cidade:     BRASILIA'));
      expect(r.out, contains('Valor:      livre'));
      expect(r.out, isNot(contains('txid')));
    });

    test('mostra valor, txid, uso único e CEP', () {
      final payload = run([
        '--key', '123.456.789-09', //
        '--amount', '10.5',
        '--txid', 'ABC',
        '--single-use',
        '--cep', '01310100',
        '--description', 'Teste',
      ]).out.trim();
      final r = run(['--parse', payload]);
      expect(r.out, contains('estático (uso único)'));
      expect(r.out, contains('(CPF)'));
      expect(r.out, contains('R\$ 10,50'));
      expect(r.out, contains('txid:       ABC'));
      expect(r.out, contains('CEP:        01310100'));
      expect(r.out, contains('Descrição:  Teste'));
    });

    test('dinâmico mostra a URL com https', () {
      final payload = run(['--url', 'pix.exemplo.com/c/1']).out.trim();
      final r = run(['--parse', payload]);
      expect(r.out, contains('Tipo:       dinâmico'));
      expect(r.out, contains('URL:        https://pix.exemplo.com/c/1'));
    });

    test('rótulos dos tipos de chave', () {
      for (final (key, label) in [
        ('11.222.333/0001-81', 'CNPJ'),
        ('+5511988887777', 'telefone'),
        ('fulano@exemplo.com', 'e-mail'),
      ]) {
        final payload = run(['--key', key]).out.trim();
        expect(run(['--parse', payload]).out, contains('($label)'));
      }
    });

    test('payload inválido devolve 65 com o campo', () {
      final wrong = '${reference.substring(0, reference.length - 4)}0000';
      final r = run(['--parse', wrong]);
      expect(r.code, exitData);
      expect(r.err, contains('campo 63'));
    });
  });
}
