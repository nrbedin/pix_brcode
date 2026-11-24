# pix_checkout_demo

App Flutter que mostra **um pagamento Pix do lado do front**, na estrutura
**flutter_modular 5 + MobX**. Usa [`pix_brcode`](../..) para validar o BR Code,
[`qr_flutter`](https://pub.dev/packages/qr_flutter) para desenhar o QR e
[`share_plus`](https://pub.dev/packages/share_plus) para compartilhá-lo.

O backend é **simulado** (`FakePixDatasource`): responde em JSON com os nomes
de campo da API Pix do Bacen e, quando você toca em "Simular pagamento no
banco", passa pelas etapas do pagamento até a confirmação.

## Rodar

Da raiz do repositório:

```bash
make app-run           # debug no Chrome (DEVICE=<id> para outro aparelho)
make app-install-apk   # release no Android conectado
make test-app          # testes
make codegen           # depois de mudar um store MobX
```

## Fluxo

```
Valor → Gerando cobrança → QR (copiar, compartilhar, contagem) → Processando (etapas) → Comprovante
              └→ Erro (tentar de novo)        └→ Expirado (gerar novo QR)
```

Etapas do processamento, uma a cada ~1,2 s:

1. Pagador autorizou no app do banco
2. Liquidando no SPI (Banco Central)
3. Crédito confirmado pelo PSP
4. Backend recebeu a confirmação

Na vida real, o app de quem cobra só recebe a última. As outras aparecem para
mostrar o que acontece entre os bancos. Depois que o processamento começa, a
contagem para e não dá mais para cancelar.

## Compartilhar o QR

"Compartilhar QR Code" abre a folha de compartilhamento do sistema com um PNG
(QR com margem branca, valor e recebedor) e, no texto, o "copia e cola". Assim
quem recebe pelo WhatsApp, por exemplo, consegue pagar pelo próprio celular
sem precisar escanear. No navegador sem Web Share API, o PNG é baixado.

O PNG é desenhado fora da árvore de widgets (`QrPainter` num `Canvas`), então
sai do mesmo tamanho em qualquer tela. O `ShareService` isola o plugin, e os
testes usam um falso.

## Estrutura

```
lib/
  main.dart                      ModularApp(AppModule, AppWidget)
  app/
    app_module.dart              registra o backend (PixDatasource) e as rotas
    app_widget.dart              MaterialApp.router com o Modular
    core/formatters/             R$ 10,50, data e hora
    core/share/                  QrImageRenderer (PNG) e ShareService (share_plus)
    modules/checkout/
      checkout_module.dart       rota '/'
      checkout_binds.dart        repositório, store e controller
      data/
        datasources/             contrato do backend (JSON) e o fake
        models/                  fromJson no formato da API Pix → entidades
        repositories/            CheckoutRepositoryImpl: JSON e erros → domínio
      domain/
        entities/ enums/         PixCharge, ChargeEvent, PaymentReceipt, status, etapas
        exceptions/              CheckoutException
        repositories/            contrato CheckoutRepository
      presentation/
        controller/              CheckoutController: regras e transições
        mobx/                    CheckoutStore (@observable, @computed) e estados
        pages/ widgets/          tela com Observer + switch sobre o estado
```

- **Store × controller:** o `CheckoutStore` só guarda o estado observável; o
  `CheckoutController` decide as transições (timers, eventos do backend,
  validação do QR) e escreve no store.
- **Estados:** `sealed class CheckoutState`, então a página trata todos os
  casos num `switch` e o compilador avisa se faltar algum.

## O que o front faz com o `pix_brcode`

Antes de mostrar o QR, o controller:

1. interpreta o BR Code com `PixPayload.parse` (CRC, campos obrigatórios);
2. confere se o valor no QR é o valor pedido;
3. usa o nome e a cidade do recebedor que estão **no QR** para montar a tela.

Se algo falhar, a tela mostra o erro em vez de um QR que o banco recusaria.

## Por que o banco de verdade não paga este QR

O BR Code é **dinâmico**: o app do banco lê a URL que vem dentro dele
(`pix.exemplo.com.br/...`) e tenta buscar a cobrança no PSP. Como o endereço é
fictício, o banco mostra um erro. Com um backend real, essa URL é do PSP e
devolve a cobrança assinada.

## Trocar pelo backend real

Implemente `PixDatasource` com Dio, chamando o **seu** backend (nunca direto o
PSP, que exige certificado e credenciais), e registre-o no `AppModule` no
lugar do `FakePixDatasource`. Repositório, controller e tela não mudam.
