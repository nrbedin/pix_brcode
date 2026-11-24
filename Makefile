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

# JDK usado só pelo Gradle do app Android. O Gradle 8.3 do template do
# Flutter 3.27 não roda com o JDK 25 que vem no Android Studio, então o
# daemon do Gradle roda com o JDK 17 (brew install openjdk@17). Não altera
# o Java do sistema nem a configuração global do Flutter.
ANDROID_JDK ?= /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
ANDROID_ENV := GRADLE_OPTS="-Dorg.gradle.java.home=$(ANDROID_JDK)"

.DEFAULT_GOAL := help
.PHONY: help setup deps codegen check-codegen format check-format analyze test \
	test-app check cli \
	app-run app-release-web app-serve-web check-android-jdk app-release-apk \
	app-install-apk clean

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

codegen: ## Gera o código do MobX (*.g.dart) do app
	cd $(APP_DIR) && $(DART) run build_runner build --delete-conflicting-outputs

check-codegen: codegen ## Falha se o *.g.dart commitado estiver desatualizado
	@git diff --exit-code -- '$(APP_DIR)/**/*.g.dart' || { \
		echo "Código gerado desatualizado: rode 'make codegen' e commite."; \
		exit 1; }

# --- Qualidade --------------------------------------------------------------

# Arquivos .dart do projeto, sem os gerados pelo build_runner.
DART_SOURCES = $(shell find . -name '*.dart' -not -name '*.g.dart' \
	-not -path '*/.dart_tool/*' -not -path './.fvm/*' -not -path '*/build/*')

format: ## Formata todo o código (menos o gerado)
	$(DART) format $(DART_SOURCES)

check-format: ## Falha se algum arquivo não estiver formatado
	$(DART) format --output=none --set-exit-if-changed $(DART_SOURCES)

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
	cd $(APP_DIR) && $(ANDROID_ENV) $(FLUTTER) run -d $(DEVICE)

app-release-web: ## Gera o release web em example/flutter_app/build/web
	cd $(APP_DIR) && $(FLUTTER) build web --release

app-serve-web: app-release-web ## Gera o release web e serve em http://localhost:8080 (mude com PORT=...)
	@echo "Abra http://localhost:$(PORT) (Ctrl+C para parar)"
	cd $(APP_DIR)/build/web && python3 -m http.server $(PORT)

check-android-jdk:
	@test -x "$(ANDROID_JDK)/bin/java" || { \
		echo "JDK 17 não encontrado em $(ANDROID_JDK)."; \
		echo "Instale com 'brew install openjdk@17' ou passe ANDROID_JDK=<caminho>."; \
		exit 1; }

app-release-apk: check-android-jdk ## Gera o APK de release (assinado com a chave de debug, só para teste)
	cd $(APP_DIR) && $(ANDROID_ENV) $(FLUTTER) build apk --release
	@echo "APK: $(APP_DIR)/build/app/outputs/flutter-apk/app-release.apk"

app-install-apk: app-release-apk ## Gera e instala o APK de release no aparelho ou emulador conectado
	cd $(APP_DIR) && $(ANDROID_ENV) $(FLUTTER) install

clean: ## Apaga os artefatos de build
	rm -rf .dart_tool build coverage
	cd $(APP_DIR) && $(FLUTTER) clean
