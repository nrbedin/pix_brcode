# pix_brcode

Gera, interpreta e valida payloads **Pix BR Code** (padrão EMV QRCPS) em Dart puro, sem dependências.

> Em desenvolvimento. A API ainda pode mudar antes da versão 1.0.

## Escopo

- **Gerar** payload estático (chave, valor opcional, nome, cidade, txid) e dinâmico (URL de cobrança).
- **Interpretar** uma string em um objeto tipado, com `PixParseException` indicando o campo inválido.
- **CRC16-CCITT** (polinômio `0x1021`, valor inicial `0xFFFF`) para gerar e validar.
- **Validar** tamanhos de campo, caracteres permitidos e formato da chave (e-mail, telefone, CPF/CNPJ, EVP).
- **Exemplos**: CLI (`dart run example/main.dart --key ... --amount 10.50`) e app Flutter mínimo com `qr_flutter`.

Todos os dados usados em testes e exemplos são fictícios.

## Uso

```dart
import 'package:pix_brcode/pix_brcode.dart';

void main() {
  // QR estático: a chave vai no próprio payload.
  final estatico = StaticPixPayload(
    key: PixKey.parse('123e4567-e12b-12d1-a456-426655440000'),
    merchantName: 'Fulano de Tal',
    merchantCity: 'Brasília', // acentos são removidos
    amount: 10.50, // opcional
    txid: 'PEDIDO123', // opcional
  );
  print(estatico.encode()); // string do "Pix Copia e Cola"

  // QR dinâmico: aponta para a URL de cobrança do PSP.
  final dinamico = DynamicPixPayload(
    url: 'https://pix.exemplo.com.br/qr/v2/9d36b84fc70b478fb95c12729b90ca25',
    merchantName: 'Fulano de Tal',
    merchantCity: 'Brasília',
  );
  print(dinamico.encode());
}
```

Campos inválidos lançam `ArgumentError` com o nome do parâmetro e o motivo.

### Ler um BR Code

```dart
try {
  final payload = PixPayload.parse(copiaECola);
  switch (payload) {
    case StaticPixPayload(:final key, :final amount):
      print('Chave ${key.type.name}: ${key.value}, valor: ${amount ?? 'livre'}');
    case DynamicPixPayload(:final url):
      print('Cobrança em https://$url');
  }
} on PixParseException catch (e) {
  print(e); // PixParseException (campo 26.01): chave Pix inválida: ... (posição 22)
}
```

O parser confere CRC16, versão, GUI `br.gov.bcb.pix`, moeda `986`, país `BR` e as mesmas regras do gerador. Campos desconhecidos são ignorados. Use `PixPayload.tryParse` para receber `null` em vez da exceção.

## Exemplo de linha de comando

```bash
# Gerar BR Code estático (nome e cidade têm valores fictícios por padrão)
dart run example/main.dart --key 123e4567-e12b-12d1-a456-426655440000 --amount 10.50

# Gerar BR Code dinâmico
dart run example/main.dart --url pix.exemplo.com.br/qr/v2/abc123 --name "Loja Exemplo" --city "Curitiba"

# Ler um BR Code
dart run example/main.dart --parse "00020126580014br.gov.bcb.pix0136..."
```

Use `--help` para ver todas as opções (`--txid`, `--description`, `--cep`, `--single-use`).

## Licença

MIT
