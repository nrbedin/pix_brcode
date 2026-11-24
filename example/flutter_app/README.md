# pix_checkout_demo

App Flutter mínimo que mostra **um pagamento Pix do lado do front**, usando
[`pix_brcode`](../..) para validar o BR Code e
[`qr_flutter`](https://pub.dev/packages/qr_flutter) para desenhar o QR.

O backend é **simulado** (`FakePixGateway`): ele gera um BR Code dinâmico com
dados fictícios e só marca a cobrança como paga quando você toca em
"Simular pagamento no banco".

## Rodar

```bash
cd example/flutter_app
flutter pub get
flutter run -d chrome   # ou um emulador Android/iOS
flutter test
```

## Fluxo

```
Valor  →  Gerando cobrança  →  QR na tela (copia e cola + contagem)  →  Pago
                 │                          │
                 └──→ Erro (tentar de novo) └──→ Expirado (gerar novo QR)
```

| Arquivo | Papel |
|---|---|
| `lib/src/pix_gateway.dart` | Contrato com o backend: criar cobrança, acompanhar status, cancelar |
| `lib/src/fake_pix_gateway.dart` | Backend simulado, com latência, validade e falha opcional |
| `lib/src/checkout_controller.dart` | Máquina de estados (`sealed class CheckoutState`) |
| `lib/src/checkout_page.dart` | Tela, com um `switch` sobre o estado |

## O que o front faz com o `pix_brcode`

O front **não confia cegamente** no backend. Antes de mostrar o QR, ele:

1. interpreta o BR Code com `PixPayload.parse` (CRC, campos obrigatórios);
2. confere se o valor no QR é o valor pedido;
3. usa o nome e a cidade do recebedor que estão **no QR** para montar a tela.

Se algo falhar, a tela mostra o erro em vez de um QR que o banco do pagador
recusaria.

## Trocar pelo backend real

Implemente `PixGateway` com chamadas HTTP ao **seu** backend (nunca direto ao
PSP, que exige certificado e credenciais):

- `createCharge` → `POST` no backend, que cria a cobrança na API Pix do PSP e
  devolve o "copia e cola";
- `watchStatus` → WebSocket, Server-Sent Events ou polling no backend, que
  recebe o webhook de pagamento do PSP;
- `cancel` → avisa o backend que a tela foi abandonada.

O controller e a tela não mudam.
