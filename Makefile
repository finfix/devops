export SOPS_AGE_KEY_FILE=$(CURDIR)/k8s/secrets/key.txt
APP_VERSION ?= latest
# Таймаут на релиз в секундах (helmfile apply --timeout), по умолчанию 3 минуты
RELEASE_TIMEOUT ?= 180

deploy-coin-server:
	APP_VERSION=$(APP_VERSION) helmfile -f k8s/helmfile.yaml -e prod apply -l name=coin-server --timeout $(RELEASE_TIMEOUT) --diff-args="--suppress-secrets"

deploy-coin-server-dev:
	APP_VERSION=$(APP_VERSION) helmfile -f k8s/helmfile.yaml -e dev apply -l name=coin-server --timeout $(RELEASE_TIMEOUT) --diff-args="--suppress-secrets"
