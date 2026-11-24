# Comandos do projeto. Rode `make` para ver a lista.
#
# Usa o Flutter (e o Dart que vem com ele) na versão fixada em .fvmrc, via
# FVM. No CI, onde o Flutter já vem instalado, use `make ... FVM=`.

FVM ?= fvm
FLUTTER := $(FVM) flutter
DART := $(FVM) dart

APP_DIR := example/flutter_app
DEVICE ?= chrome
PORT ?= 8080

.DEFAULT_GOAL := help
.PHONY: help setup deps format check-format analyze test test-app check cli \
	app-run app-release-web app-serve-web app-release-apk app-install-apk clean

help: ## Lista os comandos
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# --- Ambiente ---------------------------------------------------------------

setup: ## Instala o Flutter do .fvmrc e baixa as dependências
	$(FVM) install
	$(MAKE) deps

deps: ## Baixa as dependências do pacote e do app
	$(DART) pub get
	cd $(APP_DIR) && $(FLUTTER) pub get

# --- Qualidade --------------------------------------------------------------

format: ## Formata todo o código
	$(DART) format .

check-format: ## Falha se algum arquivo não estiver formatado
	$(DART) format --output=none --set-exit-if-changed .

analyze: ## Análise estática do pacote e do app
	$(DART) analyze --fatal-infos
	cd $(APP_DIR) && $(FLUTTER) analyze

test: ## Testes do pacote
	$(DART) test

test-app: ## Testes do app Flutter
	cd $(APP_DIR) && $(FLUTTER) test

check: check-format analyze test test-app ## Tudo o que o CI roda

# --- Exemplos ---------------------------------------------------------------

cli: ## Roda o CLI. Ex.: make cli ARGS="--key fulano@exemplo.com --amount 10.50"
	$(DART) run example/main.dart $(ARGS)

app-run: ## Roda o app em debug (DEVICE=chrome por padrão; veja `fvm flutter devices`)
	cd $(APP_DIR) && $(FLUTTER) run -d $(DEVICE)

app-release-web: ## Gera o release web em example/flutter_app/build/web
	cd $(APP_DIR) && $(FLUTTER) build web --release

app-serve-web: app-release-web ## Gera o release web e serve em http://localhost:8080 (mude com PORT=...)
	@echo "Abra http://localhost:$(PORT) (Ctrl+C para parar)"
	cd $(APP_DIR)/build/web && python3 -m http.server $(PORT)

app-release-apk: ## Gera o APK de release (assinado com a chave de debug, só para teste)
	cd $(APP_DIR) && $(FLUTTER) build apk --release
	@echo "APK: $(APP_DIR)/build/app/outputs/flutter-apk/app-release.apk"

app-install-apk: app-release-apk ## Gera e instala o APK de release no aparelho ou emulador conectado
	cd $(APP_DIR) && $(FLUTTER) install

clean: ## Apaga os artefatos de build
	rm -rf .dart_tool build coverage
	cd $(APP_DIR) && $(FLUTTER) clean
