// Exemplo de linha de comando do pix_brcode.
//
// Gerar um BR Code estático:
//   dart run example/main.dart --key 123e4567-e12b-12d1-a456-426655440000 \
//     --amount 10.50
//
// Gerar um BR Code dinâmico:
//   dart run example/main.dart --url pix.exemplo.com.br/qr/v2/abc123
//
// Ler um BR Code:
//   dart run example/main.dart --parse "00020126580014br.gov.bcb.pix..."
//
// Todos os dados dos exemplos são fictícios.

import 'dart:io';

import 'package:pix_brcode/pix_brcode.dart';

/// Código de saída para uso incorreto da linha de comando.
const exitUsage = 64;

/// Código de saída para dados inválidos (chave, valor, payload...).
const exitData = 65;

const _defaultName = 'Fulano de Tal';
const _defaultCity = 'BRASILIA';

const _usage = '''
Uso: dart run example/main.dart [opções]

Gerar (estático):  --key <chave> [--amount 10.50] [--txid ID] [--description TEXTO] [--single-use]
Gerar (dinâmico):  --url <url da cobrança> [--amount 10.50]
Ler:               --parse "<payload>"

Opções comuns ao gerar:
  --name <nome>     nome do recebedor (padrão: $_defaultName)
  --city <cidade>   cidade do recebedor (padrão: $_defaultCity)
  --cep <cep>       CEP com 8 dígitos
  -h, --help        mostra esta ajuda
''';

const _valueOptions = {
  'key',
  'url',
  'amount',
  'name',
  'city',
  'txid',
  'description',
  'cep',
  'parse',
};
const _flagOptions = {'single-use', 'help'};

void main(List<String> args) {
  exitCode = runCli(args, stdout, stderr);
}

/// Executa o CLI e devolve o código de saída.
///
/// Fica separado de [main] para poder ser testado sem abrir um processo.
int runCli(List<String> args, StringSink out, StringSink err) {
  final Map<String, String> options;
  try {
    options = _parseArgs(args);
  } on FormatException catch (e) {
    err
      ..writeln('Erro: ${e.message}')
      ..writeln()
      ..write(_usage);
    return exitUsage;
  }

  if (options.containsKey('help') || options.isEmpty) {
    out.write(_usage);
    return 0;
  }

  final modes = ['key', 'url', 'parse'].where(options.containsKey).toList();
  if (modes.length != 1) {
    err
      ..writeln('Erro: use exatamente uma de --key, --url ou --parse.')
      ..writeln()
      ..write(_usage);
    return exitUsage;
  }

  return switch (modes.single) {
    'parse' => _parse(options['parse']!, out, err),
    _ => _generate(options, out, err),
  };
}

Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '-h') {
      options['help'] = '';
      continue;
    }
    if (!arg.startsWith('--')) {
      throw FormatException('argumento inesperado "$arg"');
    }

    var name = arg.substring(2);
    String? value;
    final equals = name.indexOf('=');
    if (equals >= 0) {
      value = name.substring(equals + 1);
      name = name.substring(0, equals);
    }

    if (_flagOptions.contains(name)) {
      if (value != null) {
        throw FormatException('--$name não recebe valor');
      }
      options[name] = '';
    } else if (_valueOptions.contains(name)) {
      if (value == null) {
        if (i + 1 >= args.length) {
          throw FormatException('--$name precisa de um valor');
        }
        value = args[++i];
      }
      options[name] = value;
    } else {
      throw FormatException('opção desconhecida --$name');
    }
  }
  return options;
}

int _generate(Map<String, String> options, StringSink out, StringSink err) {
  final double? amount;
  final amountText = options['amount'];
  if (amountText == null) {
    amount = null;
  } else {
    // Aceita vírgula como separador decimal, como é comum no Brasil.
    amount = double.tryParse(amountText.replaceAll(',', '.'));
    if (amount == null) {
      err.writeln('Erro: valor inválido "$amountText" (ex.: 10.50).');
      return exitData;
    }
  }

  final name = options['name'] ?? _defaultName;
  final city = options['city'] ?? _defaultCity;

  final PixPayload payload;
  try {
    final url = options['url'];
    if (url != null) {
      if (options.containsKey('txid') ||
          options.containsKey('description') ||
          options.containsKey('single-use')) {
        err.writeln(
          'Erro: --txid, --description e --single-use só valem com --key.',
        );
        return exitUsage;
      }
      payload = DynamicPixPayload(
        url: url,
        merchantName: name,
        merchantCity: city,
        amount: amount,
        postalCode: options['cep'],
      );
    } else {
      payload = StaticPixPayload(
        key: PixKey.parse(options['key']!),
        merchantName: name,
        merchantCity: city,
        amount: amount,
        txid: options['txid'],
        description: options['description'],
        postalCode: options['cep'],
        singleUse: options.containsKey('single-use'),
      );
    }
  } on FormatException catch (e) {
    err.writeln('Erro na chave Pix: ${e.message}');
    return exitData;
  } on ArgumentError catch (e) {
    err.writeln('Erro em --${_optionFor(e.name)}: ${e.message}');
    return exitData;
  }

  out.writeln(payload.encode());
  return 0;
}

int _parse(String input, StringSink out, StringSink err) {
  final PixPayload payload;
  try {
    payload = PixPayload.parse(input);
  } on PixParseException catch (e) {
    err.writeln(e);
    return exitData;
  }

  final amount = payload.amount;
  final lines = <(String, String?)>[
    ...switch (payload) {
      StaticPixPayload(
        :final key,
        :final txid,
        :final description,
        :final singleUse,
      ) =>
        [
          ('Tipo', 'estático${singleUse ? ' (uso único)' : ''}'),
          ('Chave', '${key.value} (${_keyTypeLabel(key.type)})'),
          ('Descrição', description),
          ('txid', txid),
        ],
      DynamicPixPayload(:final url) => [
          ('Tipo', 'dinâmico'),
          ('URL', 'https://$url'),
        ],
    },
    ('Recebedor', payload.merchantName),
    ('Cidade', payload.merchantCity),
    (
      'Valor',
      amount == null
          ? 'livre'
          : 'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}'
    ),
    ('CEP', payload.postalCode),
  ];

  for (final (label, value) in lines) {
    if (value != null) out.writeln('${'$label:'.padRight(11)} $value');
  }
  return 0;
}

String _keyTypeLabel(PixKeyType type) => switch (type) {
      PixKeyType.cpf => 'CPF',
      PixKeyType.cnpj => 'CNPJ',
      PixKeyType.phone => 'telefone',
      PixKeyType.email => 'e-mail',
      PixKeyType.evp => 'aleatória',
    };

String? _optionFor(String? parameter) => switch (parameter) {
      'merchantName' => 'name',
      'merchantCity' => 'city',
      'postalCode' => 'cep',
      _ => parameter,
    };
